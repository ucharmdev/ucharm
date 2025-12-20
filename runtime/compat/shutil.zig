const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn copyContents(src: std.fs.File, dst: std.fs.File) !void {
    var buf: [8192]u8 = undefined;
    while (true) {
        const n = try src.read(&buf);
        if (n == 0) break;
        try dst.writeAll(buf[0..n]);
    }
}

fn existsFn(ctx: *pk.Context) bool {
    const path = ctx.argStr(0) orelse return ctx.typeError("path must be a string");
    const ok = std.fs.cwd().statFile(path) catch null;
    return ctx.returnBool(ok != null);
}

fn copyFn(ctx: *pk.Context) bool {
    const src_path = ctx.argStr(0) orelse return ctx.typeError("src must be a string");
    const dst_path = ctx.argStr(1) orelse return ctx.typeError("dst must be a string");

    var src_file = std.fs.cwd().openFile(src_path, .{}) catch return c.py_exception(c.tp_OSError, "copy failed");
    defer src_file.close();
    var dst_file = std.fs.cwd().createFile(dst_path, .{ .truncate = true }) catch return c.py_exception(c.tp_OSError, "copy failed");
    defer dst_file.close();

    copyContents(src_file, dst_file) catch return c.py_exception(c.tp_OSError, "copy failed");
    return ctx.returnStr(dst_path);
}

fn moveFn(ctx: *pk.Context) bool {
    const src_path = ctx.argStr(0) orelse return ctx.typeError("src must be a string");
    const dst_path = ctx.argStr(1) orelse return ctx.typeError("dst must be a string");

    std.fs.cwd().rename(src_path, dst_path) catch {
        // Fallback: copy then delete.
        var src_file = std.fs.cwd().openFile(src_path, .{}) catch return c.py_exception(c.tp_OSError, "move failed");
        defer src_file.close();
        var dst_file = std.fs.cwd().createFile(dst_path, .{ .truncate = true }) catch return c.py_exception(c.tp_OSError, "move failed");
        defer dst_file.close();
        copyContents(src_file, dst_file) catch return c.py_exception(c.tp_OSError, "move failed");
        std.fs.cwd().deleteFile(src_path) catch return c.py_exception(c.tp_OSError, "move failed");
    };
    return ctx.returnStr(dst_path);
}

fn rmtreeFn(ctx: *pk.Context) bool {
    const path = ctx.argStr(0) orelse return ctx.typeError("path must be a string");
    std.fs.cwd().deleteTree(path) catch {
        return ctx.runtimeError("failed to remove directory");
    };
    return ctx.returnNone();
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("shutil");
    _ = builder
        .funcWrapped("copy", 2, 2, copyFn)
        .funcWrapped("move", 2, 2, moveFn)
        .funcWrapped("rmtree", 1, 1, rmtreeFn)
        .funcWrapped("exists", 1, 1, existsFn);
}
