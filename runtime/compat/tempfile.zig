const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn getTempDir(alloc: std.mem.Allocator) ![]u8 {
    const tmp = std.process.getEnvVarOwned(alloc, "TMPDIR") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return try alloc.dupe(u8, "/tmp"),
        else => return err,
    };
    if (tmp.len == 0) {
        alloc.free(tmp);
        return try alloc.dupe(u8, "/tmp");
    }
    // Trim trailing slashes (except root).
    var s = tmp;
    while (s.len > 1 and s[s.len - 1] == '/') : (s = s[0 .. s.len - 1]) {}
    if (s.len != tmp.len) {
        const trimmed = try alloc.dupe(u8, s);
        alloc.free(tmp);
        return trimmed;
    }
    return tmp;
}

fn gettempdirFn(ctx: *pk.Context) bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const dir = getTempDir(arena.allocator()) catch return c.py_exception(c.tp_OSError, "gettempdir failed");
    return ctx.returnStr(dir);
}

fn mktempFn(ctx: *pk.Context) bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const dir = getTempDir(alloc) catch return c.py_exception(c.tp_OSError, "mktemp failed");
    const stamp: i64 = @intCast(std.time.milliTimestamp());
    var attempt: usize = 0;
    while (attempt < 10000) : (attempt += 1) {
        const path = std.fmt.allocPrint(alloc, "{s}/tmp{d}-{d}", .{ dir, stamp, attempt }) catch return ctx.runtimeError("out of memory");
        const exists = std.fs.cwd().statFile(path) catch null;
        if (exists == null) {
            return ctx.returnStr(path);
        }
    }
    return ctx.runtimeError("mktemp failed");
}

fn mkstempFn(ctx: *pk.Context) bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const dir = getTempDir(alloc) catch return c.py_exception(c.tp_OSError, "mkstemp failed");
    const stamp: i64 = @intCast(std.time.milliTimestamp());
    var attempt: usize = 0;
    while (attempt < 10000) : (attempt += 1) {
        const path = std.fmt.allocPrint(alloc, "{s}/tmp{d}-{d}", .{ dir, stamp, attempt }) catch return ctx.runtimeError("out of memory");
        var file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return c.py_exception(c.tp_OSError, "mkstemp failed"),
        };
        file.close();
        return ctx.returnStr(path);
    }
    return ctx.runtimeError("mkstemp failed");
}

fn mkdtempFn(ctx: *pk.Context) bool {
    var prefix: []const u8 = "tmp";
    if (ctx.argCount() >= 1) {
        var arg = ctx.arg(0);
        if (arg != null and !arg.?.isNone()) {
            prefix = arg.?.toStr() orelse return ctx.typeError("prefix must be a string");
        }
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const stamp: i64 = @intCast(std.time.milliTimestamp());
    var attempt: usize = 0;
    while (attempt < 1000) : (attempt += 1) {
        const name = std.fmt.allocPrint(arena_alloc, "{s}{d}-{d}", .{ prefix, stamp, attempt }) catch {
            return ctx.runtimeError("out of memory");
        };
        const res = std.fs.cwd().makeDir(name);
        if (res) |_| {
            return ctx.returnStr(name);
        } else |err| {
            if (err != error.PathAlreadyExists) {
                return ctx.runtimeError("failed to create temp dir");
            }
        }
    }

    return ctx.runtimeError("failed to create temp dir");
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("tempfile");
    _ = builder
        .funcWrapped("gettempdir", 0, 0, gettempdirFn)
        .funcWrapped("mktemp", 0, 0, mktempFn)
        .funcWrapped("mkstemp", 0, 0, mkstempFn)
        .funcWrapped("mkdtemp", 0, 1, mkdtempFn);
}
