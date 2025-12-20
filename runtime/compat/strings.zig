const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn bytesMulFn(ctx: *pk.Context) bool {
    var self = ctx.arg(0) orelse return ctx.typeError("self required");
    const n_i64 = ctx.argInt(1) orelse return ctx.typeError("expected int");

    if (n_i64 <= 0) {
        _ = c.py_newbytes(c.py_retval(), 0);
        return true;
    }

    var src_size: c_int = 0;
    const src_ptr = c.py_tobytes(self.ref(), &src_size);
    const src_len: usize = @intCast(src_size);
    if (src_len == 0) {
        _ = c.py_newbytes(c.py_retval(), 0);
        return true;
    }

    const n: usize = @intCast(n_i64);
    const total_len_u64: u64 = @as(u64, src_len) * @as(u64, n);
    if (total_len_u64 > @as(u64, @intCast(std.math.maxInt(c_int)))) {
        return ctx.valueError("bytes repetition too large");
    }
    const total_len: usize = @intCast(total_len_u64);

    const dst_ptr = c.py_newbytes(c.py_retval(), @intCast(total_len));
    const dst = @as([*]u8, @ptrCast(dst_ptr))[0..total_len];
    const src = @as([*]const u8, @ptrCast(src_ptr))[0..src_len];

    var off: usize = 0;
    while (off < total_len) : (off += src_len) {
        @memcpy(dst[off .. off + src_len], src);
    }
    return true;
}

fn rsplitFn(ctx: *pk.Context) bool {
    const text = ctx.argStr(0) orelse return ctx.typeError("expected string");
    const sep = ctx.argStr(1) orelse return ctx.typeError("separator must be a string");
    const maxsplit = ctx.argInt(2) orelse -1;

    c.py_newlist(c.py_retval());
    const out = c.py_retval();

    if (sep.len == 1 and maxsplit == 1) {
        if (std.mem.lastIndexOfScalar(u8, text, sep[0])) |pos| {
            const left = text[0..pos];
            const right = text[pos + 1 ..];
            const sv_left = c.c11_sv{ .data = left.ptr, .size = @intCast(left.len) };
            const sv_right = c.c11_sv{ .data = right.ptr, .size = @intCast(right.len) };
            c.py_newstrv(c.py_r0(), sv_left);
            c.py_list_append(out, c.py_r0());
            c.py_newstrv(c.py_r1(), sv_right);
            c.py_list_append(out, c.py_r1());
            return true;
        }
    }

    if (sep.len == 1) {
        var iter = std.mem.splitScalar(u8, text, sep[0]);
        while (iter.next()) |part| {
            const sv = c.c11_sv{ .data = part.ptr, .size = @intCast(part.len) };
            c.py_newstrv(c.py_r0(), sv);
            c.py_list_append(out, c.py_r0());
        }
        return true;
    }

    const sv = c.c11_sv{ .data = text.ptr, .size = @intCast(text.len) };
    c.py_newstrv(c.py_r0(), sv);
    c.py_list_append(out, c.py_r0());
    return true;
}

fn splitlinesFn(ctx: *pk.Context) bool {
    const text = ctx.argStr(0) orelse return ctx.typeError("expected string");

    c.py_newlist(c.py_retval());
    const out_list = c.py_retval();
    var iter = std.mem.splitScalar(u8, text, '\n');
    while (iter.next()) |line| {
        var trimmed = line;
        if (trimmed.len > 0 and trimmed[trimmed.len - 1] == '\r') {
            trimmed = trimmed[0 .. trimmed.len - 1];
        }
        const sv = c.c11_sv{ .data = trimmed.ptr, .size = @intCast(trimmed.len) };
        c.py_newstrv(c.py_r0(), sv);
        c.py_list_append(out_list, c.py_r0());
    }
    return true;
}

fn isupperFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("expected string");

    var has_cased = false;
    for (s) |ch| {
        if (ch >= 'a' and ch <= 'z') {
            return ctx.returnBool(false);
        }
        if (ch >= 'A' and ch <= 'Z') {
            has_cased = true;
        }
    }
    return ctx.returnBool(has_cased);
}

pub fn register() void {
    c.py_bindmethod(c.tp_str, "splitlines", pk.wrapFn(1, 1, splitlinesFn));
    c.py_bindmethod(c.tp_str, "rsplit", pk.wrapFn(2, 3, rsplitFn));
    c.py_bindmethod(c.tp_str, "isupper", pk.wrapFn(1, 1, isupperFn));
    c.py_bindmethod(c.tp_bytes, "__mul__", pk.wrapFn(2, 2, bytesMulFn));
    c.py_bindmethod(c.tp_bytes, "__rmul__", pk.wrapFn(2, 2, bytesMulFn));
}
