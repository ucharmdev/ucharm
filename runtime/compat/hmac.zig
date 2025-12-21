/// hmac.zig - Minimal `hmac` module (keyed hashing)
///
/// Implements:
/// - new(key, msg=None, digestmod="sha256")
/// - compare_digest(a, b)
/// - HMAC.update(), HMAC.digest(), HMAC.hexdigest()
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

const Algo = enum(u8) { md5, sha1, sha256 };

const HmacState = union(Algo) {
    md5: std.crypto.auth.hmac.HmacMd5,
    sha1: std.crypto.auth.hmac.HmacSha1,
    sha256: std.crypto.auth.hmac.sha2.HmacSha256,
};

const HmacObj = struct {
    algo: Algo = .sha256,
    state: ?*HmacState = null,
};

var tp_hmac: c.py_Type = 0;

fn hmacDtor(ptr: ?*anyopaque) callconv(.c) void {
    const ud: *HmacObj = @ptrCast(@alignCast(ptr orelse return));
    if (ud.state) |st| {
        std.heap.c_allocator.destroy(st);
        ud.state = null;
    }
}

fn getBytesLike(v: c.py_Ref, out_size: *c_int) ?[]const u8 {
    if (c.py_istype(v, c.tp_bytes)) {
        const ptr = c.py_tobytes(v, out_size);
        return ptr[0..@intCast(out_size.*)];
    }
    if (c.py_isstr(v)) {
        const sv = c.py_tosv(v);
        out_size.* = sv.size;
        return @as([*]const u8, @ptrCast(sv.data))[0..@intCast(sv.size)];
    }
    return null;
}

fn parseAlgo(v: ?c.py_Ref) ?Algo {
    const dv = v orelse return .sha256;
    if (c.py_isstr(dv)) {
        const s = c.py_tostr(dv);
        const slice = s[0..std.mem.len(s)];
        if (std.mem.eql(u8, slice, "md5")) return .md5;
        if (std.mem.eql(u8, slice, "sha1")) return .sha1;
        if (std.mem.eql(u8, slice, "sha256")) return .sha256;
    }
    return null;
}

fn hmacNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_hmac, -1, @sizeOf(HmacObj));
    const ud: *HmacObj = @ptrCast(@alignCast(c.py_touserdata(c.py_retval())));
    ud.* = .{};
    return true;
}

fn hmacInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const ud: *HmacObj = @ptrCast(@alignCast(c.py_touserdata(self)));

    if (argc < 2) return c.py_exception(c.tp_TypeError, "HMAC(key, msg=None, digestmod='sha256')");

    var key_sz: c_int = 0;
    const key = getBytesLike(pk.argRef(argv, 1), &key_sz) orelse {
        return c.py_exception(c.tp_TypeError, "key must be bytes or str");
    };

    const algo = parseAlgo(if (argc >= 4) pk.argRef(argv, 3) else null) orelse {
        return c.py_exception(c.tp_ValueError, "unsupported digestmod");
    };

    if (ud.state) |st| {
        std.heap.c_allocator.destroy(st);
        ud.state = null;
    }

    const state_box = std.heap.c_allocator.create(HmacState) catch {
        return c.py_exception(c.tp_RuntimeError, "out of memory");
    };
    state_box.* = switch (algo) {
        .md5 => .{ .md5 = std.crypto.auth.hmac.HmacMd5.init(key) },
        .sha1 => .{ .sha1 = std.crypto.auth.hmac.HmacSha1.init(key) },
        .sha256 => .{ .sha256 = std.crypto.auth.hmac.sha2.HmacSha256.init(key) },
    };
    ud.algo = algo;
    ud.state = state_box;

    if (argc >= 3 and !c.py_isnone(pk.argRef(argv, 2))) {
        var msg_sz: c_int = 0;
        const msg = getBytesLike(pk.argRef(argv, 2), &msg_sz) orelse {
            return c.py_exception(c.tp_TypeError, "msg must be bytes or str");
        };
        const state_ptr = ud.state orelse return c.py_exception(c.tp_RuntimeError, "HMAC not initialized");
        switch (state_ptr.*) {
            inline else => |*st| st.update(msg),
        }
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn hmacUpdate(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "update(self, msg)");
    const self = pk.argRef(argv, 0);
    const ud: *HmacObj = @ptrCast(@alignCast(c.py_touserdata(self)));
    var msg_sz: c_int = 0;
    const msg = getBytesLike(pk.argRef(argv, 1), &msg_sz) orelse {
        return c.py_exception(c.tp_TypeError, "msg must be bytes or str");
    };
    const state_ptr = ud.state orelse return c.py_exception(c.tp_RuntimeError, "HMAC not initialized");
    switch (state_ptr.*) {
        inline else => |*st| st.update(msg),
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn hmacDigest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "digest(self)");
    const self = pk.argRef(argv, 0);
    const ud: *HmacObj = @ptrCast(@alignCast(c.py_touserdata(self)));

    const state_ptr = ud.state orelse return c.py_exception(c.tp_RuntimeError, "HMAC not initialized");
    switch (state_ptr.*) {
        .md5 => {
            var st = state_ptr.*.md5;
            var out: [std.crypto.auth.hmac.HmacMd5.mac_length]u8 = undefined;
            st.final(&out);
            const bytes = c.py_newbytes(c.py_retval(), out.len);
            @memcpy(bytes[0..out.len], &out);
            return true;
        },
        .sha1 => {
            var st = state_ptr.*.sha1;
            var out: [std.crypto.auth.hmac.HmacSha1.mac_length]u8 = undefined;
            st.final(&out);
            const bytes = c.py_newbytes(c.py_retval(), out.len);
            @memcpy(bytes[0..out.len], &out);
            return true;
        },
        .sha256 => {
            var st = state_ptr.*.sha256;
            var out: [std.crypto.auth.hmac.sha2.HmacSha256.mac_length]u8 = undefined;
            st.final(&out);
            const bytes = c.py_newbytes(c.py_retval(), out.len);
            @memcpy(bytes[0..out.len], &out);
            return true;
        },
    }
}

fn hmacHexDigest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "hexdigest(self)");
    if (!hmacDigest(1, argv)) return false;
    var n: c_int = 0;
    const data = getBytesLike(c.py_retval(), &n) orelse return c.py_exception(c.tp_RuntimeError, "internal error");
    if (data.len > 4096) return c.py_exception(c.tp_ValueError, "digest too large");
    const out_str = c.py_newstrn(c.py_retval(), @intCast(data.len * 2));
    const hex = "0123456789abcdef";
    for (data, 0..) |b, i| {
        out_str[i * 2] = hex[b >> 4];
        out_str[i * 2 + 1] = hex[b & 0x0f];
    }
    return true;
}

fn compareDigestFn(ctx: *pk.Context) bool {
    const a = ctx.arg(0) orelse return ctx.typeError("expected a");
    const b = ctx.arg(1) orelse return ctx.typeError("expected b");
    var asz: c_int = 0;
    var bsz: c_int = 0;
    const aa = getBytesLike(a.refConst(), &asz) orelse return ctx.typeError("a must be bytes or str");
    const bb = getBytesLike(b.refConst(), &bsz) orelse return ctx.typeError("b must be bytes or str");

    const max_len = @max(aa.len, bb.len);
    var diff: u8 = 0;
    var i: usize = 0;
    while (i < max_len) : (i += 1) {
        const xa: u8 = if (i < aa.len) aa[i] else 0;
        const xb: u8 = if (i < bb.len) bb[i] else 0;
        diff |= xa ^ xb;
    }
    return ctx.returnBool(diff == 0 and aa.len == bb.len);
}

fn newFn(ctx: *pk.Context) bool {
    // new(key, msg=None, digestmod="sha256")
    const key = ctx.arg(0) orelse return ctx.typeError("expected key");
    const msg = ctx.arg(1);
    const digestmod = ctx.arg(2);

    _ = c.py_newobject(c.py_retval(), tp_hmac, -1, @sizeOf(HmacObj));
    const obj_tv: c.py_TValue = c.py_retval().*;

    var argv: [4]c.py_TValue = undefined;
    argv[0] = obj_tv;
    argv[1] = key.refConst().*;
    argv[2] = if (msg) |m| m.refConst().* else c.py_None().*;
    if (digestmod) |dm| {
        argv[3] = dm.refConst().*;
    } else {
        var dm_tv: c.py_TValue = undefined;
        c.py_newstr(&dm_tv, "sha256");
        argv[3] = dm_tv;
    }
    if (!hmacInit(4, @ptrCast(&argv))) return false;

    c.py_retval().* = obj_tv;
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("hmac");

    var type_builder = pk.TypeBuilder.new("HMAC", c.tp_object, builder.module, hmacDtor);
    tp_hmac = type_builder
        .magic("__new__", hmacNew)
        .magic("__init__", hmacInit)
        .method("update", hmacUpdate)
        .method("digest", hmacDigest)
        .method("hexdigest", hmacHexDigest)
        .build();

    _ = builder
        .funcWrapped("new", 1, 3, newFn)
        .funcWrapped("compare_digest", 2, 2, compareDigestFn);
}
