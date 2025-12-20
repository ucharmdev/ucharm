/// secrets.zig - Minimal `secrets` module for CLI use cases
///
/// Implements a small subset of CPython's `secrets`:
/// - token_bytes(n=32)
/// - token_hex(n=32)
/// - token_urlsafe(n=32)
/// - randbelow(n)
/// - choice(seq)
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn tokenBytesFn(ctx: *pk.Context) bool {
    const n = ctx.argInt(0) orelse 32;
    if (n < 0) return ctx.valueError("n must be >= 0");
    const out = c.py_newbytes(c.py_retval(), @intCast(n));
    if (n > 0) std.crypto.random.bytes(out[0..@intCast(n)]);
    return true;
}

fn tokenHexFn(ctx: *pk.Context) bool {
    const n = ctx.argInt(0) orelse 32;
    if (n < 0) return ctx.valueError("n must be >= 0");
    const byte_len: usize = @intCast(n);
    if (byte_len > 4096) return ctx.valueError("n too large");
    const hex_len = byte_len * 2;

    var tmp: [4096]u8 = undefined;
    if (byte_len > 0) std.crypto.random.bytes(tmp[0..byte_len]);

    const out_str = c.py_newstrn(c.py_retval(), @intCast(hex_len));
    const hex = "0123456789abcdef";
    for (tmp[0..byte_len], 0..) |b, i| {
        out_str[i * 2] = hex[b >> 4];
        out_str[i * 2 + 1] = hex[b & 0x0f];
    }
    return true;
}

fn tokenUrlsafeFn(ctx: *pk.Context) bool {
    const n = ctx.argInt(0) orelse 32;
    if (n < 0) return ctx.valueError("n must be >= 0");
    const byte_len: usize = @intCast(n);
    if (byte_len > 4096) return ctx.valueError("n too large");

    var tmp: [4096]u8 = undefined;
    if (byte_len > 0) std.crypto.random.bytes(tmp[0..byte_len]);

    // URL-safe base64 without '=' padding.
    const encoder = std.base64.url_safe_no_pad.Encoder;
    const enc_len = encoder.calcSize(byte_len);
    const out = c.py_newstrn(c.py_retval(), @intCast(enc_len));
    _ = encoder.encode(out[0..enc_len], tmp[0..byte_len]);
    return true;
}

fn randbelowFn(ctx: *pk.Context) bool {
    const n = ctx.argInt(0) orelse return ctx.typeError("expected int");
    if (n <= 0) return ctx.valueError("n must be > 0");
    const bound: u64 = @intCast(n);
    const x = std.crypto.random.intRangeLessThan(u64, 0, bound);
    c.py_newint(c.py_retval(), @intCast(x));
    return true;
}

fn choiceFn(ctx: *pk.Context) bool {
    const seq = ctx.arg(0) orelse return ctx.typeError("expected sequence");
    if (!c.py_len(seq.refConst())) return false;
    const n = c.py_toint(c.py_retval());
    if (n <= 0) return ctx.indexError("cannot choose from an empty sequence");
    const idx = std.crypto.random.intRangeLessThan(i64, 0, n);
    c.py_newint(c.py_r0(), idx);
    if (!c.py_getitem(seq.refConst(), c.py_r0())) return false;
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("secrets");
    _ = builder
        .funcWrapped("token_bytes", 0, 1, tokenBytesFn)
        .funcWrapped("token_hex", 0, 1, tokenHexFn)
        .funcWrapped("token_urlsafe", 0, 1, tokenUrlsafeFn)
        .funcWrapped("randbelow", 1, 1, randbelowFn)
        .funcWrapped("choice", 1, 1, choiceFn);
}
