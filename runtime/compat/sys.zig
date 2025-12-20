const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var recursion_limit: i64 = 1000;
var tp_stdout: c.py_Type = 0;
var tp_stderr: c.py_Type = 0;

fn setIfMissing(module: c.py_Ref, name: [:0]const u8, val: c.py_Ref) void {
    const existing = c.py_getdict(module, c.py_name(name));
    if (existing == null) {
        c.py_setdict(module, c.py_name(name), val);
    }
}

fn exitFn(ctx: *pk.Context) bool {
    if (ctx.argCount() >= 1) {
        const arg = ctx.arg(0) orelse return ctx.returnNone();
        const tmp = c.py_pushtmp();
        tmp.* = arg.val;
        if (!c.py_tpcall(c.tp_SystemExit, 1, tmp)) {
            c.py_pop();
            return false;
        }
        c.py_pop();
    } else {
        if (!c.py_tpcall(c.tp_SystemExit, 0, null)) return false;
    }
    return c.py_raise(c.py_retval());
}

fn getRecursionLimitFn(ctx: *pk.Context) bool {
    return ctx.returnInt(recursion_limit);
}

fn setRecursionLimitFn(ctx: *pk.Context) bool {
    const limit = ctx.argInt(0) orelse return ctx.typeError("expected int");
    if (limit <= 0) {
        return ctx.valueError("limit must be positive");
    }
    recursion_limit = limit;
    return ctx.returnNone();
}

fn getSizeofFn(ctx: *pk.Context) bool {
    var obj = ctx.arg(0) orelse return ctx.typeError("expected object");
    var size: i64 = 1;
    if (obj.isStr()) {
        const sv = c.py_tosv(obj.ref());
        size = @intCast(sv.size);
        if (size == 0) size = 1;
    } else if (obj.isList()) {
        size = c.py_list_len(obj.ref()) + 1;
    } else if (obj.isDict()) {
        size = c.py_dict_len(obj.ref()) + 1;
    }
    return ctx.returnInt(size);
}

fn internFn(ctx: *pk.Context) bool {
    var s = ctx.arg(0) orelse return ctx.typeError("expected string");
    if (!s.isStr()) return ctx.typeError("expected string");

    const module = c.py_getmodule("sys") orelse c.py_newmodule("sys");

    var intern_dict = c.py_getdict(module, c.py_name("__intern__"));
    if (intern_dict == null) {
        c.py_newdict(c.py_r0());
        c.py_setdict(module, c.py_name("__intern__"), c.py_r0());
        intern_dict = c.py_getdict(module, c.py_name("__intern__"));
    }

    const dict = intern_dict.?;
    const found = c.py_dict_getitem(dict, s.ref());
    if (found > 0) {
        pk.setRetval(c.py_retval());
        return true;
    }

    _ = c.py_dict_setitem(dict, s.ref(), s.ref());
    return ctx.returnValue(s);
}

fn platformTag() [:0]const u8 {
    return switch (@import("builtin").target.os.tag) {
        .macos => "darwin",
        .linux => "linux",
        .windows => "win32",
        else => "unix",
    };
}

fn stdoutWriteFn(ctx: *pk.Context) bool {
    const text = ctx.argStr(1) orelse return ctx.typeError("write() argument must be str");
    const stdout = std.posix.STDOUT_FILENO;
    _ = std.posix.write(stdout, text) catch 0;
    return ctx.returnInt(@intCast(text.len));
}

fn stderrWriteFn(ctx: *pk.Context) bool {
    const text = ctx.argStr(1) orelse return ctx.typeError("write() argument must be str");
    const stderr = std.posix.STDERR_FILENO;
    _ = std.posix.write(stderr, text) catch 0;
    return ctx.returnInt(@intCast(text.len));
}

fn stdFlushFn(ctx: *pk.Context) bool {
    return ctx.returnNone();
}

pub fn register() void {
    const module = c.py_getmodule("sys") orelse c.py_newmodule("sys");

    c.py_newstr(c.py_r0(), "PocketPy");
    setIfMissing(module, "version", c.py_r0());

    _ = c.py_newtuple(c.py_r1(), 3);
    c.py_newint(c.py_r2(), 3);
    c.py_tuple_setitem(c.py_r1(), 0, c.py_r2());
    c.py_newint(c.py_r2(), 11);
    c.py_tuple_setitem(c.py_r1(), 1, c.py_r2());
    c.py_newint(c.py_r2(), 0);
    c.py_tuple_setitem(c.py_r1(), 2, c.py_r2());
    setIfMissing(module, "version_info", c.py_r1());

    c.py_newstr(c.py_r0(), platformTag());
    setIfMissing(module, "platform", c.py_r0());

    c.py_newlist(c.py_r0());
    setIfMissing(module, "path", c.py_r0());

    // Create sys.modules dict and add sys to it
    const modules_ptr = c.py_getdict(module, c.py_name("modules"));
    if (modules_ptr == null) {
        c.py_newdict(c.py_r0());
        c.py_setdict(module, c.py_name("modules"), c.py_r0());
    }
    // Get the modules dict (could be newly created or existing)
    const modules_dict = c.py_getdict(module, c.py_name("modules")).?;
    // Add sys module to sys.modules - use r0 for the key string
    c.py_newstr(c.py_r0(), "sys");
    _ = c.py_dict_setitem(modules_dict, c.py_r0(), module);

    // Create stdin (None for now - input not supported)
    c.py_newnone(c.py_r0());
    setIfMissing(module, "stdin", c.py_r0());

    // Create stdout type with write method
    tp_stdout = c.py_newtype("_StdOut", c.tp_object, module, null);
    c.py_bindmethod(tp_stdout, "write", pk.wrapFn(2, 2, stdoutWriteFn));
    c.py_bindmethod(tp_stdout, "flush", pk.wrapFn(1, 1, stdFlushFn));
    _ = c.py_newobject(c.py_r0(), tp_stdout, -1, 0);
    setIfMissing(module, "stdout", c.py_r0());

    // Create stderr type with write method
    tp_stderr = c.py_newtype("_StdErr", c.tp_object, module, null);
    c.py_bindmethod(tp_stderr, "write", pk.wrapFn(2, 2, stderrWriteFn));
    c.py_bindmethod(tp_stderr, "flush", pk.wrapFn(1, 1, stdFlushFn));
    _ = c.py_newobject(c.py_r0(), tp_stderr, -1, 0);
    setIfMissing(module, "stderr", c.py_r0());

    c.py_newint(c.py_r0(), @intCast(std.math.maxInt(isize)));
    setIfMissing(module, "maxsize", c.py_r0());

    const byteorder: [:0]const u8 = if (@import("builtin").target.cpu.arch.endian() == .little) "little" else "big";
    c.py_newstr(c.py_r0(), byteorder);
    setIfMissing(module, "byteorder", c.py_r0());

    _ = c.py_newobject(c.py_r0(), c.tp_object, -1, 0);
    c.py_newstr(c.py_r1(), "pocketpy");
    c.py_setdict(c.py_r0(), c.py_name("name"), c.py_r1());
    setIfMissing(module, "implementation", c.py_r0());

    c.py_newstr(c.py_r0(), "");
    setIfMissing(module, "executable", c.py_r0());

    _ = c.py_newobject(c.py_r0(), c.tp_object, -1, 0);
    setIfMissing(module, "flags", c.py_r0());

    var builder = pk.ModuleBuilder{ .module = module };
    _ = builder
        .funcWrapped("exit", 0, 1, exitFn)
        .funcWrapped("getrecursionlimit", 0, 0, getRecursionLimitFn)
        .funcWrapped("setrecursionlimit", 1, 1, setRecursionLimitFn)
        .funcWrapped("getsizeof", 1, 1, getSizeofFn)
        .funcWrapped("intern", 1, 1, internFn);
}
