const std = @import("std");
const builtin = @import("builtin");
const pk = @import("pk");
const c = pk.c;

const subprocess_stdout_key: [:0]const u8 = "stdout";
const subprocess_stderr_key: [:0]const u8 = "stderr";
const subprocess_returncode_key: [:0]const u8 = "returncode";

const PIPE: i32 = -1;
const DEVNULL: i32 = -2;

var tp_popen: c.py_Type = 0;

const PopenObj = struct {
    child: std.process.Child,
    started: bool,
    text_mode: bool,
};

const RunResult = struct {
    stdout: []u8,
    stderr: []u8,
    returncode: i64,
};

fn readAll(alloc: std.mem.Allocator, file: std.fs.File) []u8 {
    return file.readToEndAlloc(alloc, 1024 * 1024) catch &[_]u8{};
}

fn runChild(alloc: std.mem.Allocator, args: []const []const u8, capture: bool) !RunResult {
    var child = std.process.Child.init(args, alloc);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = if (capture) .Pipe else .Ignore;
    child.stderr_behavior = if (capture) .Pipe else .Ignore;

    try child.spawn();

    var stdout_bytes: []u8 = &[_]u8{};
    var stderr_bytes: []u8 = &[_]u8{};
    if (capture) {
        if (child.stdout) |file| stdout_bytes = readAll(alloc, file);
        if (child.stderr) |file| stderr_bytes = readAll(alloc, file);
    }

    const term = try child.wait();
    var returncode: i64 = -1;
    switch (term) {
        .Exited => |code| returncode = code,
        else => returncode = -1,
    }
    return .{ .stdout = stdout_bytes, .stderr = stderr_bytes, .returncode = returncode };
}

fn buildArgvFromList(alloc: std.mem.Allocator, list: c.py_Ref, out: *std.ArrayList([]const u8)) bool {
    if (!c.py_checktype(list, c.tp_list)) return false;
    const list_len = c.py_list_len(list);
    if (list_len <= 0) return c.py_exception(c.tp_TypeError, "args must be a non-empty list");
    var i: c_int = 0;
    while (i < list_len) : (i += 1) {
        const item = c.py_list_getitem(list, i);
        const cstr = c.py_tostr(item) orelse return c.py_exception(c.tp_TypeError, "args must be strings");
        out.append(alloc, std.mem.span(cstr)) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    }
    return true;
}

fn run(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1 or argc > 3) return c.py_exception(c.tp_TypeError, "run() takes args, capture_output=False, shell=False");

    const args_val = pk.argRef(argv, 0);
    var capture_output = false;
    if (argc >= 2) capture_output = c.py_tobool(pk.argRef(argv, 1));
    var shell = false;
    if (argc == 3) shell = c.py_tobool(pk.argRef(argv, 2));

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var argv_list: std.ArrayList([]const u8) = .empty;
    defer argv_list.deinit(alloc);

    if (shell) {
        const cmd_c = c.py_tostr(args_val) orelse return c.py_exception(c.tp_TypeError, "args must be a string when shell=True");
        argv_list.append(alloc, "sh") catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        argv_list.append(alloc, "-c") catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        argv_list.append(alloc, std.mem.span(cmd_c)) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    } else {
        if (!buildArgvFromList(alloc, args_val, &argv_list)) return false;
    }

    const result = runChild(alloc, argv_list.items, capture_output) catch return c.py_exception(c.tp_RuntimeError, "failed to run process");

    c.py_newdict(c.py_retval());
    const dict = c.py_retval();

    if (capture_output) {
        const out_buf = c.py_newbytes(c.py_r0(), @intCast(result.stdout.len));
        if (result.stdout.len > 0) {
            @memcpy(@as([*]u8, @ptrCast(out_buf))[0..result.stdout.len], result.stdout);
        }
        _ = c.py_dict_setitem_by_str(dict, subprocess_stdout_key, c.py_r0());

        const err_buf = c.py_newbytes(c.py_r1(), @intCast(result.stderr.len));
        if (result.stderr.len > 0) {
            @memcpy(@as([*]u8, @ptrCast(err_buf))[0..result.stderr.len], result.stderr);
        }
        _ = c.py_dict_setitem_by_str(dict, subprocess_stderr_key, c.py_r1());
    } else {
        c.py_newnone(c.py_r0());
        _ = c.py_dict_setitem_by_str(dict, subprocess_stdout_key, c.py_r0());
        c.py_newnone(c.py_r1());
        _ = c.py_dict_setitem_by_str(dict, subprocess_stderr_key, c.py_r1());
    }

    c.py_newint(c.py_r2(), result.returncode);
    _ = c.py_dict_setitem_by_str(dict, subprocess_returncode_key, c.py_r2());
    return true;
}

fn callFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "call() takes args");
    // call(args) is run(args).returncode
    if (!run(1, argv)) return false;
    const dict = c.py_retval();
    const rc = c.py_dict_getitem_by_str(dict, subprocess_returncode_key);
    if (rc <= 0) return c.py_exception(c.tp_RuntimeError, "returncode missing");
    pk.setRetval(c.py_retval());
    return true;
}

fn check_outputFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "check_output() takes args");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var argv_list: std.ArrayList([]const u8) = .empty;
    defer argv_list.deinit(alloc);
    if (!buildArgvFromList(alloc, pk.argRef(argv, 0), &argv_list)) return false;

    const result = runChild(alloc, argv_list.items, true) catch return c.py_exception(c.tp_RuntimeError, "failed to run process");
    // Return a string to avoid relying on bytes.decode(encoding) support in PocketPy.
    const out_buf = c.py_newstrn(c.py_retval(), @intCast(result.stdout.len));
    if (result.stdout.len > 0) {
        @memcpy(@as([*]u8, @ptrCast(out_buf))[0..result.stdout.len], result.stdout);
    }
    return true;
}

fn getstatusoutputFn(ctx: *pk.Context) bool {
    // getstatusoutput(cmd) -> (status, output)
    // Runs command via shell and returns (exit_status, combined_output)
    const cmd = ctx.argStr(0) orelse return ctx.typeError("cmd must be a string");

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const argv_list = [_][]const u8{ "sh", "-c", cmd };
    const result = runChild(alloc, &argv_list, true) catch {
        // Return (-1, "") on error
        _ = c.py_newtuple(c.py_retval(), 2);
        c.py_newint(c.py_r0(), -1);
        c.py_tuple_setitem(c.py_retval(), 0, c.py_r0());
        c.py_newstr(c.py_r1(), "");
        c.py_tuple_setitem(c.py_retval(), 1, c.py_r1());
        return true;
    };

    // Combine stdout and stderr, strip trailing newline
    var output_len = result.stdout.len;
    if (output_len > 0 and result.stdout[output_len - 1] == '\n') {
        output_len -= 1;
    }

    _ = c.py_newtuple(c.py_retval(), 2);
    c.py_newint(c.py_r0(), result.returncode);
    c.py_tuple_setitem(c.py_retval(), 0, c.py_r0());

    if (output_len > 0) {
        const out_buf = c.py_newstrn(c.py_r1(), @intCast(output_len));
        @memcpy(@as([*]u8, @ptrCast(out_buf))[0..output_len], result.stdout[0..output_len]);
    } else {
        c.py_newstr(c.py_r1(), "");
    }
    c.py_tuple_setitem(c.py_retval(), 1, c.py_r1());

    return true;
}

fn getoutputFn(ctx: *pk.Context) bool {
    // getoutput(cmd) -> output (just the output, ignoring status)
    const cmd = ctx.argStr(0) orelse return ctx.typeError("cmd must be a string");

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const argv_list = [_][]const u8{ "sh", "-c", cmd };
    const result = runChild(alloc, &argv_list, true) catch {
        return ctx.returnStr("");
    };

    // Strip trailing newline
    var output_len = result.stdout.len;
    if (output_len > 0 and result.stdout[output_len - 1] == '\n') {
        output_len -= 1;
    }

    if (output_len > 0) {
        const out_buf = c.py_newstrn(c.py_retval(), @intCast(output_len));
        @memcpy(@as([*]u8, @ptrCast(out_buf))[0..output_len], result.stdout[0..output_len]);
        return true;
    }
    return ctx.returnStr("");
}

fn popenNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    _ = c.py_newobject(c.py_retval(), tp_popen, -1, @sizeOf(PopenObj));
    return true;
}

fn getPopen(self: c.py_Ref) ?*PopenObj {
    if (!c.py_istype(self, tp_popen)) return null;
    return @ptrCast(@alignCast(c.py_touserdata(self)));
}

fn popenInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2 or argc > 6) return c.py_exception(c.tp_TypeError, "Popen(args, stdout=None, stderr=None, shell=False, text=False)");
    const self = pk.argRef(argv, 0);
    const args_val = pk.argRef(argv, 1);

    const stdout_val = if (argc >= 3) pk.argRef(argv, 2) else c.py_None();
    const stderr_val = if (argc >= 4) pk.argRef(argv, 3) else c.py_None();
    const shell = if (argc >= 5) c.py_tobool(pk.argRef(argv, 4)) else false;
    const text_mode = if (argc >= 6) c.py_tobool(pk.argRef(argv, 5)) else false;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var argv_list: std.ArrayList([]const u8) = .empty;
    defer argv_list.deinit(alloc);

    if (shell) {
        const cmd_c = c.py_tostr(args_val) orelse return c.py_exception(c.tp_TypeError, "args must be a string when shell=True");
        argv_list.append(alloc, "sh") catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        argv_list.append(alloc, "-c") catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        argv_list.append(alloc, std.mem.span(cmd_c)) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    } else {
        if (!buildArgvFromList(alloc, args_val, &argv_list)) return false;
    }

    const ud = getPopen(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid Popen");
    ud.started = false;
    ud.text_mode = text_mode;
    ud.child = std.process.Child.init(argv_list.items, std.heap.c_allocator);
    ud.child.stdin_behavior = .Ignore;

    const stdout_pipe = c.py_isint(stdout_val) and @as(i32, @intCast(c.py_toint(stdout_val))) == PIPE;
    const stderr_pipe = c.py_isint(stderr_val) and @as(i32, @intCast(c.py_toint(stderr_val))) == PIPE;

    ud.child.stdout_behavior = if (stdout_pipe) .Pipe else .Ignore;
    ud.child.stderr_behavior = if (stderr_pipe) .Pipe else .Ignore;

    ud.child.spawn() catch return c.py_exception(c.tp_RuntimeError, "failed to spawn process");
    ud.started = true;
    // The argv memory is arena-owned; clear the slice to avoid dangling references.
    ud.child.argv = &.{};

    c.py_newint(c.py_r0(), @intCast(ud.child.id));
    c.py_setdict(self, c.py_name("pid"), c.py_r0());
    c.py_newnone(c.py_r0());
    c.py_setdict(self, c.py_name("returncode"), c.py_r0());

    // stdout/stderr are exposed via methods; keep fields for compat.
    c.py_newnone(c.py_r0());
    c.py_setdict(self, c.py_name("stdout"), c.py_r0());
    c.py_newnone(c.py_r0());
    c.py_setdict(self, c.py_name("stderr"), c.py_r0());

    c.py_newnone(c.py_retval());
    return true;
}

fn popenCommunicate(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    const self = pk.argRef(argv, 0);
    const ud = getPopen(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid Popen");
    if (!ud.started) return c.py_exception(c.tp_RuntimeError, "process not started");

    var out_bytes: []u8 = &[_]u8{};
    var err_bytes: []u8 = &[_]u8{};

    if (ud.child.stdout) |file| out_bytes = readAll(std.heap.c_allocator, file);
    if (ud.child.stderr) |file| err_bytes = readAll(std.heap.c_allocator, file);

    const term = ud.child.wait() catch return c.py_exception(c.tp_RuntimeError, "wait failed");
    var returncode: i64 = -1;
    switch (term) {
        .Exited => |code| returncode = code,
        else => returncode = -1,
    }

    // Store returncode on object
    c.py_newint(c.py_r0(), returncode);
    c.py_setdict(self, c.py_name("returncode"), c.py_r0());

    _ = c.py_newtuple(c.py_retval(), 2);

    if (ud.text_mode) {
        const out_str = c.py_newstrn(c.py_r0(), @intCast(out_bytes.len));
        if (out_bytes.len > 0) @memcpy(@as([*]u8, @ptrCast(out_str))[0..out_bytes.len], out_bytes);
        c.py_tuple_setitem(c.py_retval(), 0, c.py_r0());

        const err_str = c.py_newstrn(c.py_r1(), @intCast(err_bytes.len));
        if (err_bytes.len > 0) @memcpy(@as([*]u8, @ptrCast(err_str))[0..err_bytes.len], err_bytes);
        c.py_tuple_setitem(c.py_retval(), 1, c.py_r1());
    } else {
        const out_buf = c.py_newbytes(c.py_r0(), @intCast(out_bytes.len));
        if (out_bytes.len > 0) @memcpy(@as([*]u8, @ptrCast(out_buf))[0..out_bytes.len], out_bytes);
        c.py_tuple_setitem(c.py_retval(), 0, c.py_r0());

        const err_buf = c.py_newbytes(c.py_r1(), @intCast(err_bytes.len));
        if (err_bytes.len > 0) @memcpy(@as([*]u8, @ptrCast(err_buf))[0..err_bytes.len], err_bytes);
        c.py_tuple_setitem(c.py_retval(), 1, c.py_r1());
    }

    if (out_bytes.len > 0) std.heap.c_allocator.free(out_bytes);
    if (err_bytes.len > 0) std.heap.c_allocator.free(err_bytes);
    return true;
}

fn popenWait(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    const self = pk.argRef(argv, 0);
    const ud = getPopen(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid Popen");
    if (!ud.started) return c.py_exception(c.tp_RuntimeError, "process not started");

    const term = ud.child.wait() catch return c.py_exception(c.tp_RuntimeError, "wait failed");
    var returncode: i64 = -1;
    switch (term) {
        .Exited => |code| returncode = code,
        else => returncode = -1,
    }
    c.py_newint(c.py_retval(), returncode);
    c.py_setdict(self, c.py_name("returncode"), c.py_retval());
    return true;
}

fn popenTerminate(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "terminate(self)");
    const self = pk.argRef(argv, 0);
    const ud = getPopen(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid Popen");
    if (!ud.started) return c.py_exception(c.tp_RuntimeError, "process not started");
    if (builtin.os.tag != .windows and builtin.os.tag != .wasi) {
        _ = std.posix.kill(ud.child.id, std.posix.SIG.TERM) catch {};
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn popenKill(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "kill(self)");
    const self = pk.argRef(argv, 0);
    const ud = getPopen(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid Popen");
    if (!ud.started) return c.py_exception(c.tp_RuntimeError, "process not started");
    if (builtin.os.tag != .windows and builtin.os.tag != .wasi) {
        _ = std.posix.kill(ud.child.id, std.posix.SIG.KILL) catch {};
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn popenReadline(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "readline(self)");
    const self = pk.argRef(argv, 0);
    const ud = getPopen(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid Popen");
    if (!ud.started) return c.py_exception(c.tp_RuntimeError, "process not started");
    const file = ud.child.stdout orelse return c.py_exception(c.tp_RuntimeError, "stdout is not piped");

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(std.heap.c_allocator);

    var tmp: [1]u8 = undefined;
    while (buf.items.len < 8192) {
        const n = file.read(&tmp) catch break;
        if (n == 0) break;
        buf.append(std.heap.c_allocator, tmp[0]) catch break;
        if (tmp[0] == '\n') break;
    }

    if (ud.text_mode) {
        const out_str = c.py_newstrn(c.py_retval(), @intCast(buf.items.len));
        if (buf.items.len > 0) @memcpy(@as([*]u8, @ptrCast(out_str))[0..buf.items.len], buf.items);
        return true;
    }
    const outb = c.py_newbytes(c.py_retval(), @intCast(buf.items.len));
    if (buf.items.len > 0) @memcpy(outb[0..buf.items.len], buf.items);
    return true;
}

pub fn register() void {
    const name: [:0]const u8 = "subprocess";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);

    // Constants
    c.py_newint(c.py_r0(), PIPE);
    c.py_setdict(module, c.py_name("PIPE"), c.py_r0());
    c.py_newint(c.py_r0(), DEVNULL);
    c.py_setdict(module, c.py_name("DEVNULL"), c.py_r0());

    // Popen
    tp_popen = c.py_newtype("Popen", c.tp_object, module, null);
    c.py_bind(c.py_tpobject(tp_popen), "__new__(cls, args, stdout=None, stderr=None, shell=False, text=False)", popenNew);
    c.py_bind(c.py_tpobject(tp_popen), "__init__(self, args, stdout=None, stderr=None, shell=False, text=False)", popenInit);
    c.py_bindmethod(tp_popen, "communicate", popenCommunicate);
    c.py_bindmethod(tp_popen, "wait", popenWait);
    c.py_bindmethod(tp_popen, "terminate", popenTerminate);
    c.py_bindmethod(tp_popen, "kill", popenKill);
    c.py_bindmethod(tp_popen, "readline", popenReadline);
    c.py_setdict(module, c.py_name("Popen"), c.py_tpobject(tp_popen));

    c.py_bind(module, "run(args, capture_output=False, shell=False)", run);
    c.py_bind(module, "call(args)", callFn);
    c.py_bind(module, "check_output(args)", check_outputFn);

    // Legacy functions (from commands module, commonly used)
    var builder = pk.ModuleBuilder{ .module = module };
    _ = builder
        .funcSigWrapped("getstatusoutput(cmd)", 1, 1, getstatusoutputFn)
        .funcSigWrapped("getoutput(cmd)", 1, 1, getoutputFn);
}
