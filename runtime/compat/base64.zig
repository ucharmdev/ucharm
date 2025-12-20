const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn isBytes(val: *pk.Value) bool {
    return val.isType(c.tp_bytes);
}

fn urlsafeB64EncodeFn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("expected bytes");

    if (!isBytes(&arg)) {
        return ctx.typeError("expected bytes");
    }

    var size: c_int = 0;
    const data = c.py_tobytes(arg.ref(), &size);
    const input = data[0..@intCast(size)];

    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(input.len);

    var buffer: [4096]u8 = undefined;
    if (encoded_len > buffer.len) {
        return ctx.valueError("data too large");
    }

    _ = encoder.encode(buffer[0..encoded_len], input);

    // Replace + with - and / with _ for URL-safe encoding
    for (buffer[0..encoded_len]) |*ch| {
        if (ch.* == '+') ch.* = '-';
        if (ch.* == '/') ch.* = '_';
    }

    const out = c.py_newbytes(c.py_retval(), @intCast(encoded_len));
    @memcpy(out[0..encoded_len], buffer[0..encoded_len]);
    return true;
}

fn urlsafeB64DecodeFn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("expected bytes or string");

    var size: c_int = 0;
    var data: [*]const u8 = undefined;

    if (isBytes(&arg)) {
        data = c.py_tobytes(arg.ref(), &size);
    } else if (arg.isStr()) {
        const sv = c.py_tosv(arg.ref());
        data = sv.data;
        size = sv.size;
    } else {
        return ctx.typeError("expected bytes or string");
    }

    const input_len: usize = @intCast(size);
    if (input_len == 0) {
        _ = c.py_newbytes(c.py_retval(), 0);
        return true;
    }

    // Copy and replace - with + and _ with /
    var buffer: [4096]u8 = undefined;
    if (input_len > buffer.len) {
        return ctx.valueError("data too large");
    }

    for (0..input_len) |i| {
        const ch = data[i];
        if (ch == '-') {
            buffer[i] = '+';
        } else if (ch == '_') {
            buffer[i] = '/';
        } else {
            buffer[i] = ch;
        }
    }

    const decoder = std.base64.standard.Decoder;
    const decoded_len = decoder.calcSizeForSlice(buffer[0..input_len]) catch {
        return ctx.valueError("invalid base64");
    };

    var decode_buffer: [4096]u8 = undefined;
    if (decoded_len > decode_buffer.len) {
        return ctx.valueError("data too large");
    }

    decoder.decode(decode_buffer[0..decoded_len], buffer[0..input_len]) catch {
        return ctx.valueError("invalid base64");
    };

    const out = c.py_newbytes(c.py_retval(), @intCast(decoded_len));
    @memcpy(out[0..decoded_len], decode_buffer[0..decoded_len]);
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.extend("base64") orelse return;
    _ = builder
        .funcWrapped("urlsafe_b64encode", 1, 1, urlsafeB64EncodeFn)
        .funcWrapped("urlsafe_b64decode", 1, 1, urlsafeB64DecodeFn);
}
