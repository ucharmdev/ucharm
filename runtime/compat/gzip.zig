/// gzip.zig - Minimal `gzip` module
///
/// Implements:
/// - gzip.compress(data[, compresslevel]) -> bytes
/// - gzip.decompress(data) -> bytes
///
/// Compression uses DEFLATE "stored" blocks (no compression) wrapped in a gzip
/// container. This keeps the implementation small while providing a compatible
/// wire format.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn gzipCompressAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out = std.array_list.AlignedManaged(u8, null).init(allocator);
    errdefer out.deinit();

    try out.appendSlice(std.compress.flate.Container.gzip.header());

    var crc = std.hash.Crc32.init();
    crc.update(input);

    if (input.len == 0) {
        // Single final empty stored block.
        try out.append(0x01);
        try out.appendSlice(&[_]u8{ 0x00, 0x00, 0xFF, 0xFF });
    } else {
        var offset: usize = 0;
        while (offset < input.len) {
            const remaining = input.len - offset;
            const chunk_len: usize = @min(remaining, 65535);
            const is_final = (offset + chunk_len) == input.len;

            try out.append(if (is_final) 0x01 else 0x00);
            var hdr: [4]u8 = undefined;
            std.mem.writeInt(u16, hdr[0..2], @intCast(chunk_len), .little);
            std.mem.writeInt(u16, hdr[2..4], ~@as(u16, @intCast(chunk_len)), .little);
            try out.appendSlice(&hdr);
            try out.appendSlice(input[offset .. offset + chunk_len]);
            offset += chunk_len;
        }
    }

    var footer: [8]u8 = undefined;
    std.mem.writeInt(u32, footer[0..4], crc.final(), .little);
    std.mem.writeInt(u32, footer[4..8], @truncate(input.len), .little);
    try out.appendSlice(&footer);

    return out.toOwnedSlice();
}

fn gzipDecompressAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var in_reader = std.Io.Reader.fixed(input);
    var window: [std.compress.flate.max_window_len]u8 = undefined;
    var decomp = std.compress.flate.Decompress.init(&in_reader, .gzip, window[0..]);

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

fn compressFn(ctx: *pk.Context) bool {
    var v = ctx.arg(0) orelse return ctx.typeError("expected bytes");
    if (!v.isType(c.tp_bytes)) return ctx.typeError("expected bytes");

    // Optional compresslevel (ignored for stored blocks).
    _ = ctx.arg(1);

    var n: c_int = 0;
    const ptr = c.py_tobytes(v.refConst(), &n);
    const input = @as([*]const u8, @ptrCast(ptr))[0..@intCast(n)];

    const out = gzipCompressAlloc(std.heap.page_allocator, input) catch return ctx.runtimeError("gzip.compress failed");
    defer std.heap.page_allocator.free(out);

    const py = c.py_newbytes(c.py_retval(), @intCast(out.len));
    @memcpy(@as([*]u8, @ptrCast(py))[0..out.len], out);
    return true;
}

fn decompressFn(ctx: *pk.Context) bool {
    var v = ctx.arg(0) orelse return ctx.typeError("expected bytes");
    if (!v.isType(c.tp_bytes)) return ctx.typeError("expected bytes");

    var n: c_int = 0;
    const ptr = c.py_tobytes(v.refConst(), &n);
    const input = @as([*]const u8, @ptrCast(ptr))[0..@intCast(n)];

    const out = gzipDecompressAlloc(std.heap.page_allocator, input) catch return ctx.valueError("gzip.decompress failed");
    defer std.heap.page_allocator.free(out);

    const py = c.py_newbytes(c.py_retval(), @intCast(out.len));
    @memcpy(@as([*]u8, @ptrCast(py))[0..out.len], out);
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("gzip");
    _ = builder
        .funcWrapped("compress", 1, 2, compressFn)
        .funcWrapped("decompress", 1, 1, decompressFn);
}
