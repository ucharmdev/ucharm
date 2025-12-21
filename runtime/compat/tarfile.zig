/// tarfile.zig - Minimal `tarfile` module
///
/// Implements a small subset of `tarfile`:
/// - tarfile.is_tarfile(path) -> bool (ustar magic check)
/// - tarfile.open(path, mode="r") -> TarFile (read-only)
///   - .getnames() -> list[str]
///   - .extractfile(name) -> io.BytesIO (bytes-like `.read()`)
///   - .close()
///
/// Notes:
/// - Only USTAR headers are supported.
/// - Read-only (`mode="r"`) only.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_tarfile: c.py_Type = 0;

fn readOctal(field: []const u8) ?u64 {
    var i: usize = 0;
    while (i < field.len and (field[i] == 0 or field[i] == ' ')) : (i += 1) {}
    var end: usize = i;
    while (end < field.len and field[end] >= '0' and field[end] <= '7') : (end += 1) {}
    if (end == i) return 0;
    return std.fmt.parseInt(u64, field[i..end], 8) catch null;
}

fn isUstarHeader(block: []const u8) bool {
    if (block.len < 512) return false;
    return std.mem.eql(u8, block[257..262], "ustar");
}

const TarEntry = struct {
    name_off: u32 = 0,
    name_len: u16 = 0,
    data_off: u32 = 0,
    size: u32 = 0,
    typeflag: u8 = 0,
};

const TarObj = struct {
    data: ?[]u8 = null,
    entries: ?[]TarEntry = null,
    closed: bool = false,
};

fn tarDtor(ud: ?*anyopaque) callconv(.c) void {
    if (ud == null) return;
    const st: *TarObj = @ptrCast(@alignCast(ud.?));
    if (st.data) |buf| std.heap.page_allocator.free(buf);
    if (st.entries) |es| std.heap.page_allocator.free(es);
    st.* = .{};
}

fn getTar(self: c.py_Ref) ?*TarObj {
    const p = c.py_touserdata(self) orelse return null;
    return @ptrCast(@alignCast(p));
}

fn parseTarAlloc(allocator: std.mem.Allocator, data: []const u8) ![]TarEntry {
    if (data.len < 512) return error.InvalidTar;
    if (!isUstarHeader(data[0..512])) return error.InvalidTar;

    var list = std.array_list.AlignedManaged(TarEntry, null).init(allocator);
    errdefer list.deinit();

    var pos: usize = 0;
    while (pos + 512 <= data.len) {
        const hdr = data[pos .. pos + 512];
        var all_zero = true;
        for (hdr) |b| {
            if (b != 0) {
                all_zero = false;
                break;
            }
        }
        if (all_zero) break;
        if (!isUstarHeader(hdr)) return error.InvalidTar;

        // name[0:100]
        var name_end: usize = 0;
        while (name_end < 100 and hdr[name_end] != 0) : (name_end += 1) {}
        const name_off: usize = pos;
        const size_val = readOctal(hdr[124..136]) orelse return error.InvalidTar;
        const typeflag: u8 = hdr[156];

        const file_data_off = pos + 512;
        const file_size: usize = @intCast(size_val);
        if (file_data_off + file_size > data.len) return error.InvalidTar;

        // Only store regular files (type '0' or NUL) and empty names ignored.
        if (name_end > 0 and (typeflag == 0 or typeflag == '0')) {
            try list.append(.{
                .name_off = @intCast(name_off),
                .name_len = @intCast(name_end),
                .data_off = @intCast(file_data_off),
                .size = @intCast(file_size),
                .typeflag = typeflag,
            });
        }

        const padded = (file_size + 511) & ~@as(usize, 511);
        pos = file_data_off + padded;
    }
    return list.toOwnedSlice();
}

fn isTarfileFn(ctx: *pk.Context) bool {
    var v = ctx.arg(0) orelse return ctx.typeError("expected path str");
    if (!v.isStr()) return ctx.typeError("expected path str");
    const path = v.toStr() orelse return ctx.typeError("expected path str");
    var file = std.fs.cwd().openFile(path, .{}) catch return ctx.returnBool(false);
    defer file.close();
    var buf: [512]u8 = undefined;
    const got = file.readAll(&buf) catch return ctx.returnBool(false);
    if (got < 512) return ctx.returnBool(false);
    return ctx.returnBool(isUstarHeader(buf[0..512]));
}

fn tarNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_tarfile, -1, @sizeOf(TarObj));
    return true;
}

fn tarInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2 or argc > 3) return c.py_exception(c.tp_TypeError, "TarFile(name, mode='r')");
    const self = pk.argRef(argv, 0);
    const st = getTar(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid TarFile");

    if (st.data) |buf| std.heap.page_allocator.free(buf);
    if (st.entries) |es| std.heap.page_allocator.free(es);
    st.* = .{};

    const name_arg = pk.argRef(argv, 1);
    if (!c.py_isstr(name_arg)) return c.py_exception(c.tp_TypeError, "name must be str");
    const path_z = c.py_tostr(name_arg);
    const path = path_z[0..std.mem.len(path_z)];

    var mode: []const u8 = "r";
    if (argc == 3) {
        const m_arg = pk.argRef(argv, 2);
        if (!c.py_isstr(m_arg)) return c.py_exception(c.tp_TypeError, "mode must be str");
        const m_z = c.py_tostr(m_arg);
        mode = m_z[0..std.mem.len(m_z)];
    }
    if (!std.mem.eql(u8, mode, "r")) return c.py_exception(c.tp_ValueError, "only mode='r' is supported");

    var file = std.fs.cwd().openFile(path, .{}) catch return c.py_exception(c.tp_OSError, "no such file: %s", path.ptr);
    defer file.close();

    const buf = file.readToEndAlloc(std.heap.page_allocator, 64 * 1024 * 1024) catch
        return c.py_exception(c.tp_RuntimeError, "failed to read tar file");
    st.data = buf;

    const entries = parseTarAlloc(std.heap.page_allocator, buf) catch {
        std.heap.page_allocator.free(buf);
        st.data = null;
        return c.py_exception(c.tp_ValueError, "invalid tar file");
    };
    st.entries = entries;

    c.py_newnone(c.py_retval());
    return true;
}

fn tarClose(ctx: *pk.Context) bool {
    const self = ctx.arg(0) orelse return ctx.typeError("expected TarFile");
    const st = getTar(self.refConst()) orelse return ctx.runtimeError("invalid TarFile");
    if (!st.closed) {
        if (st.data) |buf| std.heap.page_allocator.free(buf);
        if (st.entries) |es| std.heap.page_allocator.free(es);
        st.data = null;
        st.entries = null;
        st.closed = true;
    }
    return ctx.returnNone();
}

fn tarGetnames(ctx: *pk.Context) bool {
    const self = ctx.arg(0) orelse return ctx.typeError("expected TarFile");
    const st = getTar(self.refConst()) orelse return ctx.runtimeError("invalid TarFile");
    if (st.closed) return ctx.valueError("tarfile is closed");
    const data = st.data orelse return ctx.runtimeError("invalid TarFile");
    const entries = st.entries orelse return ctx.runtimeError("invalid TarFile");

    c.py_newlist(c.py_retval());
    const out = c.py_retval();
    for (entries) |e| {
        const off: usize = @intCast(e.name_off);
        const len: usize = @intCast(e.name_len);
        const name_bytes = data[off .. off + len];
        const s = c.py_newstrn(c.py_r0(), @intCast(name_bytes.len));
        @memcpy(s[0..name_bytes.len], name_bytes);
        c.py_list_append(out, c.py_r0());
    }
    return true;
}

fn tarExtractfile(ctx: *pk.Context) bool {
    const self = ctx.arg(0) orelse return ctx.typeError("expected TarFile");
    var name_v = ctx.arg(1) orelse return ctx.typeError("expected name");
    if (!name_v.isStr()) return ctx.typeError("name must be str");
    const name = name_v.toStr() orelse return ctx.typeError("name must be str");

    const st = getTar(self.refConst()) orelse return ctx.runtimeError("invalid TarFile");
    if (st.closed) return ctx.valueError("tarfile is closed");
    const data = st.data orelse return ctx.runtimeError("invalid TarFile");
    const entries = st.entries orelse return ctx.runtimeError("invalid TarFile");

    var found: ?TarEntry = null;
    for (entries) |e| {
        const off: usize = @intCast(e.name_off);
        const len: usize = @intCast(e.name_len);
        const nm = data[off .. off + len];
        if (std.mem.eql(u8, nm, name)) {
            found = e;
            break;
        }
    }
    if (found == null) return c.py_exception(c.tp_KeyError, "no such member");
    const e = found.?;
    const off: usize = @intCast(e.data_off);
    const len: usize = @intCast(e.size);
    const bytes = data[off .. off + len];

    // Build a bytes object for content.
    const pyb = c.py_newbytes(c.py_r0(), @intCast(bytes.len));
    if (bytes.len > 0) @memcpy(@as([*]u8, @ptrCast(pyb))[0..bytes.len], bytes);

    // Return io.BytesIO(content)
    if (c.py_import("io") <= 0) {
        c.py_clearexc(null);
        pk.setRetval(c.py_r0());
        return true;
    }
    const io_mod = c.py_getmodule("io") orelse {
        pk.setRetval(c.py_r0());
        return true;
    };
    if (!c.py_getattr(io_mod, c.py_name("BytesIO"))) {
        c.py_clearexc(null);
        pk.setRetval(c.py_r0());
        return true;
    }
    var ctor: c.py_TValue = c.py_retval().*;
    var args: [1]c.py_TValue = .{c.py_r0().*};
    if (!c.py_call(&ctor, 1, @ptrCast(&args))) return false;
    // ctor returned in retval.
    return true;
}

fn tarEnter(ctx: *pk.Context) bool {
    const self = ctx.arg(0) orelse return ctx.typeError("expected TarFile");
    return ctx.returnValue(self);
}

fn tarExit(ctx: *pk.Context) bool {
    _ = tarClose(ctx);
    return ctx.returnBool(false);
}

fn openFn(ctx: *pk.Context) bool {
    var name_v = ctx.arg(0) orelse return ctx.typeError("expected name");
    if (!name_v.isStr()) return ctx.typeError("name must be str");
    const mode = ctx.argStr(1) orelse "r";

    if (!std.mem.eql(u8, mode, "r")) return ctx.valueError("only mode='r' is supported");

    var args: [1]c.py_TValue = .{name_v.refConst().*};
    if (!c.py_call(c.py_tpobject(tp_tarfile), 1, @ptrCast(&args))) return false;
    // TarFile.__init__ ran.
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("tarfile");

    var tar_builder = pk.TypeBuilder.new("TarFile", c.tp_object, builder.module, tarDtor);
    tp_tarfile = tar_builder
        .magic("__new__", tarNew)
        .magic("__init__", tarInit)
        .methodWrapped("close", 1, 1, tarClose)
        .methodWrapped("getnames", 1, 1, tarGetnames)
        .methodWrapped("extractfile", 2, 2, tarExtractfile)
        .magicWrapped("__enter__", 1, 1, tarEnter)
        .magicWrapped("__exit__", 1, 4, tarExit)
        .build();
    c.py_setdict(builder.module, c.py_name("TarFile"), c.py_tpobject(tp_tarfile));

    _ = builder
        .funcWrapped("open", 1, 2, openFn)
        .funcWrapped("is_tarfile", 1, 1, isTarfileFn);
}
