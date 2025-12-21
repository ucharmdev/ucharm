/// zipfile.zig - Minimal `zipfile` module
///
/// Implements a small subset of `zipfile`:
/// - zipfile.is_zipfile(path_or_bytes) -> bool (magic check only)
/// - zipfile.ZipFile(path, mode="r")
///   - .namelist() -> list[str]
///   - .read(name) -> bytes
///   - .close()
///
/// Notes:
/// - Read-only (`mode="r"`) only.
/// - Supports stored (0) and deflated (8) members.
/// - ZIP64 and data-descriptor-only entries are not supported.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_zipfile: c.py_Type = 0;

fn isZipMagicBytes(data: []const u8) bool {
    return data.len >= 4 and data[0] == 'P' and data[1] == 'K' and data[2] == 0x03 and data[3] == 0x04;
}

fn readLe(comptime T: type, data: []const u8, off: usize) ?T {
    const n = @sizeOf(T);
    if (off + n > data.len) return null;
    const slice = data[off .. off + n];
    const ptr: *const [@sizeOf(T)]u8 = @ptrCast(slice.ptr);
    return std.mem.readInt(T, ptr, .little);
}

const ZipEntry = struct {
    name_off: u32 = 0,
    name_len: u16 = 0,
    method: u16 = 0,
    comp_size: u32 = 0,
    uncomp_size: u32 = 0,
    local_off: u32 = 0,
};

const ZipObj = struct {
    data: ?[]u8 = null,
    entries: ?[]ZipEntry = null,
    closed: bool = false,
};

fn zipDtor(ud: ?*anyopaque) callconv(.c) void {
    if (ud == null) return;
    const st: *ZipObj = @ptrCast(@alignCast(ud.?));
    if (st.data) |buf| std.heap.page_allocator.free(buf);
    if (st.entries) |es| std.heap.page_allocator.free(es);
    st.* = .{};
}

fn getZip(self: c.py_Ref) ?*ZipObj {
    const p = c.py_touserdata(self) orelse return null;
    return @ptrCast(@alignCast(p));
}

fn parseZipAlloc(allocator: std.mem.Allocator, data: []const u8) ![]ZipEntry {
    // Find End Of Central Directory (EOCD) record.
    const eocd_sig = [_]u8{ 0x50, 0x4B, 0x05, 0x06 };
    const min_scan: usize = if (data.len > 22 + 65535) data.len - (22 + 65535) else 0;
    var i: usize = if (data.len >= 22) data.len - 22 else 0;
    var eocd_off: ?usize = null;
    while (true) {
        if (i + 4 <= data.len and std.mem.eql(u8, data[i .. i + 4], &eocd_sig)) {
            eocd_off = i;
            break;
        }
        if (i == min_scan) break;
        i -= 1;
    }
    if (eocd_off == null) return error.InvalidZip;
    const off = eocd_off.?;

    const total_entries = readLe(u16, data, off + 10) orelse return error.InvalidZip;
    const cd_size = readLe(u32, data, off + 12) orelse return error.InvalidZip;
    const cd_off = readLe(u32, data, off + 16) orelse return error.InvalidZip;

    if (@as(u64, cd_off) + @as(u64, cd_size) > data.len) return error.InvalidZip;

    var entries = try allocator.alloc(ZipEntry, total_entries);
    errdefer allocator.free(entries);

    var pos: usize = @intCast(cd_off);
    var idx: usize = 0;
    while (idx < total_entries) : (idx += 1) {
        if (pos + 46 > data.len) return error.InvalidZip;
        const sig = readLe(u32, data, pos) orelse return error.InvalidZip;
        if (sig != 0x02014B50) return error.InvalidZip;

        const method = readLe(u16, data, pos + 10) orelse return error.InvalidZip;
        const comp_size = readLe(u32, data, pos + 20) orelse return error.InvalidZip;
        const uncomp_size = readLe(u32, data, pos + 24) orelse return error.InvalidZip;
        const name_len = readLe(u16, data, pos + 28) orelse return error.InvalidZip;
        const extra_len = readLe(u16, data, pos + 30) orelse return error.InvalidZip;
        const comment_len = readLe(u16, data, pos + 32) orelse return error.InvalidZip;
        const local_off = readLe(u32, data, pos + 42) orelse return error.InvalidZip;

        const name_off: usize = pos + 46;
        if (name_off + name_len > data.len) return error.InvalidZip;

        entries[idx] = .{
            .name_off = @intCast(name_off),
            .name_len = name_len,
            .method = method,
            .comp_size = comp_size,
            .uncomp_size = uncomp_size,
            .local_off = local_off,
        };

        pos = name_off + name_len + extra_len + comment_len;
    }
    return entries;
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

fn zipfileNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_zipfile, -1, @sizeOf(ZipObj));
    return true;
}

fn zipfileInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2 or argc > 3) return c.py_exception(c.tp_TypeError, "ZipFile(file, mode='r')");
    const self = pk.argRef(argv, 0);
    const st = getZip(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid ZipFile");

    // Reset (in case __init__ called twice).
    if (st.data) |buf| std.heap.page_allocator.free(buf);
    if (st.entries) |es| std.heap.page_allocator.free(es);
    st.* = .{};

    const file_arg = pk.argRef(argv, 1);
    if (!c.py_isstr(file_arg)) return c.py_exception(c.tp_TypeError, "file must be str");
    const path_z = c.py_tostr(file_arg);
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
        return c.py_exception(c.tp_RuntimeError, "failed to read zip file");
    st.data = buf;

    const entries = parseZipAlloc(std.heap.page_allocator, buf) catch {
        std.heap.page_allocator.free(buf);
        st.data = null;
        return c.py_exception(c.tp_ValueError, "invalid zip file");
    };
    st.entries = entries;

    c.py_newnone(c.py_retval());
    return true;
}

fn zipfileClose(ctx: *pk.Context) bool {
    const self = ctx.arg(0) orelse return ctx.typeError("expected ZipFile");
    const st = getZip(self.refConst()) orelse return ctx.runtimeError("invalid ZipFile");
    if (!st.closed) {
        if (st.data) |buf| std.heap.page_allocator.free(buf);
        if (st.entries) |es| std.heap.page_allocator.free(es);
        st.data = null;
        st.entries = null;
        st.closed = true;
    }
    return ctx.returnNone();
}

fn zipfileEnter(ctx: *pk.Context) bool {
    const self = ctx.arg(0) orelse return ctx.typeError("expected ZipFile");
    return ctx.returnValue(self);
}

fn zipfileExit(ctx: *pk.Context) bool {
    // PocketPy may call __exit__ with only `self`.
    _ = zipfileClose(ctx);
    return ctx.returnBool(false);
}

fn zipfileNamelist(ctx: *pk.Context) bool {
    const self = ctx.arg(0) orelse return ctx.typeError("expected ZipFile");
    const st = getZip(self.refConst()) orelse return ctx.runtimeError("invalid ZipFile");
    if (st.closed) return ctx.valueError("zipfile is closed");
    const data = st.data orelse return ctx.runtimeError("invalid ZipFile");
    const entries = st.entries orelse return ctx.runtimeError("invalid ZipFile");

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

fn inflateRawAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var in_reader = std.Io.Reader.fixed(input);
    var window: [std.compress.flate.max_window_len]u8 = undefined;
    var decomp = std.compress.flate.Decompress.init(&in_reader, .raw, window[0..]);

    var out = std.array_list.AlignedManaged(u8, null).init(allocator);
    errdefer out.deinit();

    var buf: [4096]u8 = undefined;
    while (true) {
        const n = decomp.reader.readSliceShort(&buf) catch return error.ReadFailed;
        if (n == 0) break;
        try out.appendSlice(buf[0..n]);
    }
    return out.toOwnedSlice();
}

fn zipfileRead(ctx: *pk.Context) bool {
    const self = ctx.arg(0) orelse return ctx.typeError("expected ZipFile");
    var name_v = ctx.arg(1) orelse return ctx.typeError("expected name");
    if (!name_v.isStr()) return ctx.typeError("name must be str");
    const name = name_v.toStr() orelse return ctx.typeError("name must be str");

    const st = getZip(self.refConst()) orelse return ctx.runtimeError("invalid ZipFile");
    if (st.closed) return ctx.valueError("zipfile is closed");
    const data = st.data orelse return ctx.runtimeError("invalid ZipFile");
    const entries = st.entries orelse return ctx.runtimeError("invalid ZipFile");

    var found: ?ZipEntry = null;
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

    const local_off: usize = @intCast(e.local_off);
    if (local_off + 30 > data.len) return ctx.valueError("invalid zip entry");
    const sig = readLe(u32, data, local_off) orelse return ctx.valueError("invalid zip entry");
    if (sig != 0x04034B50) return ctx.valueError("invalid zip entry");
    const name_len = readLe(u16, data, local_off + 26) orelse return ctx.valueError("invalid zip entry");
    const extra_len = readLe(u16, data, local_off + 28) orelse return ctx.valueError("invalid zip entry");
    const data_off = local_off + 30 + name_len + extra_len;
    const comp_size: usize = @intCast(e.comp_size);
    if (data_off + comp_size > data.len) return ctx.valueError("invalid zip entry");
    const comp = data[data_off .. data_off + comp_size];

    if (e.method == 0) {
        const outb = c.py_newbytes(c.py_retval(), @intCast(comp.len));
        if (comp.len > 0) @memcpy(@as([*]u8, @ptrCast(outb))[0..comp.len], comp);
        return true;
    }
    if (e.method == 8) {
        const out = inflateRawAlloc(std.heap.page_allocator, comp) catch return ctx.valueError("deflate failed");
        defer std.heap.page_allocator.free(out);
        const outb = c.py_newbytes(c.py_retval(), @intCast(out.len));
        if (out.len > 0) @memcpy(@as([*]u8, @ptrCast(outb))[0..out.len], out);
        return true;
    }
    return ctx.valueError("unsupported compression method");
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("zipfile");
    var zip_builder = pk.TypeBuilder.new("ZipFile", c.tp_object, builder.module, zipDtor);
    tp_zipfile = zip_builder
        .magic("__new__", zipfileNew)
        .magic("__init__", zipfileInit)
        .methodWrapped("close", 1, 1, zipfileClose)
        .methodWrapped("namelist", 1, 1, zipfileNamelist)
        .methodWrapped("read", 2, 2, zipfileRead)
        .magicWrapped("__enter__", 1, 1, zipfileEnter)
        .magicWrapped("__exit__", 1, 4, zipfileExit)
        .build();
    c.py_setdict(builder.module, c.py_name("ZipFile"), c.py_tpobject(tp_zipfile));

    _ = builder.funcWrapped("is_zipfile", 1, 1, isZipfileFn);

    c.py_newint(c.py_r0(), 0);
    c.py_setdict(builder.module, c.py_name("ZIP_STORED"), c.py_r0());
    c.py_newint(c.py_r0(), 8);
    c.py_setdict(builder.module, c.py_name("ZIP_DEFLATED"), c.py_r0());
}
