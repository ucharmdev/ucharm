/// binascii.zig - Python binascii module implementation
///
/// Provides hex and base64 encoding/decoding functions.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn raiseError(msg: [:0]const u8) bool {
    return c.py_exception(c.tp_ValueError, msg);
}

// hexlify / b2a_hex: Convert binary data to hex string
fn hexlifyFn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("hexlify requires bytes");

    if (!arg.isType(c.tp_bytes)) {
        return ctx.typeError("a bytes-like object is required");
    }

    var size: c_int = 0;
    const data = c.py_tobytes(arg.ref(), &size);
    const len: usize = @intCast(size);

    // Each byte becomes 2 hex chars
    const out_len = len * 2;
    const out = c.py_newbytes(c.py_retval(), @intCast(out_len));

    const hex_chars = "0123456789abcdef";
    for (0..len) |i| {
        const b = data[i];
        out[i * 2] = hex_chars[b >> 4];
        out[i * 2 + 1] = hex_chars[b & 0x0f];
    }

    return true;
}

// unhexlify / a2b_hex: Convert hex string to binary data
fn unhexlifyFn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("unhexlify requires bytes or string");

    var size: c_int = 0;
    var data: [*]const u8 = undefined;

    if (arg.isType(c.tp_bytes)) {
        data = c.py_tobytes(arg.ref(), &size);
    } else if (arg.isStr()) {
        const sv = c.py_tosv(arg.ref());
        data = @ptrCast(sv.data);
        size = sv.size;
    } else {
        return ctx.typeError("a bytes-like object is required");
    }

    const len: usize = @intCast(size);

    // Must have even length
    if (len % 2 != 0) {
        return raiseError("Odd-length string");
    }

    const out_len = len / 2;
    const out = c.py_newbytes(c.py_retval(), @intCast(out_len));

    for (0..out_len) |i| {
        const hi = hexCharToVal(data[i * 2]) orelse return raiseError("Non-hexadecimal digit found");
        const lo = hexCharToVal(data[i * 2 + 1]) orelse return raiseError("Non-hexadecimal digit found");
        out[i] = (hi << 4) | lo;
    }

    return true;
}

fn hexCharToVal(ch: u8) ?u8 {
    return switch (ch) {
        '0'...'9' => ch - '0',
        'a'...'f' => ch - 'a' + 10,
        'A'...'F' => ch - 'A' + 10,
        else => null,
    };
}

// b2a_base64: Convert binary data to base64
fn b2aBase64Fn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("b2a_base64 requires bytes");

    if (!arg.isType(c.tp_bytes)) {
        return ctx.typeError("a bytes-like object is required");
    }

    var size: c_int = 0;
    const data = c.py_tobytes(arg.ref(), &size);
    const input: []const u8 = data[0..@intCast(size)];

    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(input.len);

    // Add 1 for newline
    var buffer: [8192]u8 = undefined;
    if (encoded_len + 1 > buffer.len) {
        return ctx.valueError("data too large");
    }

    _ = encoder.encode(buffer[0..encoded_len], input);
    buffer[encoded_len] = '\n';

    const out = c.py_newbytes(c.py_retval(), @intCast(encoded_len + 1));
    @memcpy(out[0 .. encoded_len + 1], buffer[0 .. encoded_len + 1]);

    return true;
}

// a2b_base64: Convert base64 to binary data
fn a2bBase64Fn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("a2b_base64 requires bytes or string");

    var size: c_int = 0;
    var data: [*]const u8 = undefined;

    if (arg.isType(c.tp_bytes)) {
        data = c.py_tobytes(arg.ref(), &size);
    } else if (arg.isStr()) {
        const sv = c.py_tosv(arg.ref());
        data = @ptrCast(sv.data);
        size = sv.size;
    } else {
        return ctx.typeError("a bytes-like object is required");
    }

    var len: usize = @intCast(size);

    // Strip trailing whitespace/newlines
    while (len > 0 and (data[len - 1] == '\n' or data[len - 1] == '\r' or data[len - 1] == ' ' or data[len - 1] == '\t')) {
        len -= 1;
    }

    if (len == 0) {
        _ = c.py_newbytes(c.py_retval(), 0);
        return true;
    }

    const decoder = std.base64.standard.Decoder;
    const decoded_len = decoder.calcSizeForSlice(data[0..len]) catch {
        return raiseError("Invalid base64-encoded string");
    };

    var buffer: [8192]u8 = undefined;
    if (decoded_len > buffer.len) {
        return ctx.valueError("data too large");
    }

    decoder.decode(buffer[0..decoded_len], data[0..len]) catch {
        return raiseError("Invalid base64-encoded string");
    };

    const out = c.py_newbytes(c.py_retval(), @intCast(decoded_len));
    @memcpy(out[0..decoded_len], buffer[0..decoded_len]);

    return true;
}

// crc32: Compute CRC-32 checksum
fn crc32Fn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "crc32 requires bytes");

    const data_arg = pk.argRef(argv, 0);
    if (!c.py_istype(data_arg, c.tp_bytes)) {
        return c.py_exception(c.tp_TypeError, "a bytes-like object is required");
    }

    var size: c_int = 0;
    const data = c.py_tobytes(data_arg, &size);
    const input: []const u8 = data[0..@intCast(size)];

    // Use Zig's CRC32
    const crc = std.hash.Crc32.hash(input);

    // Return as unsigned int
    c.py_newint(c.py_retval(), @as(i64, crc));
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("binascii");
    const module = builder.getModule();

    // Expose ValueError as Error for compatibility
    c.py_setdict(module, c.py_name("Error"), c.py_tpobject(c.tp_ValueError));
    c.py_setdict(module, c.py_name("Incomplete"), c.py_tpobject(c.tp_ValueError));

    _ = builder
        .funcWrapped("hexlify", 1, 1, hexlifyFn)
        .funcWrapped("unhexlify", 1, 1, unhexlifyFn)
        .funcWrapped("b2a_hex", 1, 1, hexlifyFn)
        .funcWrapped("a2b_hex", 1, 1, unhexlifyFn)
        .funcWrapped("b2a_base64", 1, 1, b2aBase64Fn)
        .funcWrapped("a2b_base64", 1, 1, a2bBase64Fn);

    c.py_bind(module, "crc32(data, value=0)", crc32Fn);
}
