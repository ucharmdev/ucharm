/// zipfile.zig - Minimal `zipfile` module stub
///
/// Provides import-compatibility and a small helper:
/// - is_zipfile(path_or_file) -> bool (magic check only)
///
/// Full ZipFile support is not implemented yet.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn isZipMagicBytes(data: []const u8) bool {
    return data.len >= 4 and data[0] == 'P' and data[1] == 'K' and data[2] == 0x03 and data[3] == 0x04;
}

fn isZipfileFn(ctx: *pk.Context) bool {
    var v = ctx.arg(0) orelse return ctx.typeError("expected bytes or str");
    if (v.isType(c.tp_bytes)) {
        var n: c_int = 0;
        const ptr = c.py_tobytes(v.refConst(), &n);
        return ctx.returnBool(isZipMagicBytes(ptr[0..@intCast(n)]));
    }
    if (v.isStr()) {
        // Best-effort: open and read first 4 bytes.
        const path = v.toStr() orelse return ctx.typeError("expected str");
        var file = std.fs.cwd().openFile(path, .{}) catch return ctx.returnBool(false);
        defer file.close();
        var buf: [4]u8 = undefined;
        const got = file.readAll(&buf) catch return ctx.returnBool(false);
        return ctx.returnBool(got == 4 and isZipMagicBytes(buf[0..]));
    }
    return ctx.typeError("expected bytes or str");
}

fn zipFileNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    return c.py_exception(c.tp_NotImplementedError, "zipfile.ZipFile is not implemented yet");
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("zipfile");
    const tp = c.py_newtype("ZipFile", c.tp_object, builder.module, null);
    c.py_newnativefunc(c.py_r0(), zipFileNew);
    c.py_setdict(c.py_tpobject(tp), c.py_name("__new__"), c.py_r0());

    _ = builder.funcWrapped("is_zipfile", 1, 1, isZipfileFn);
}
