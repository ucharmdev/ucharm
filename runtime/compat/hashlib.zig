const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_md5: c.py_Type = 0;
var tp_sha1: c.py_Type = 0;
var tp_sha256: c.py_Type = 0;
var tp_sha512: c.py_Type = 0;

fn HasherState(comptime Hasher: type) type {
    return struct {
        hasher: ?*Hasher = null,
    };
}

const Md5State = HasherState(std.crypto.hash.Md5);
const Sha1State = HasherState(std.crypto.hash.Sha1);
const Sha256State = HasherState(std.crypto.hash.sha2.Sha256);
const Sha512State = HasherState(std.crypto.hash.sha2.Sha512);

fn hasherDtor(comptime Hasher: type, ud: ?*anyopaque) void {
    if (ud == null) return;
    const state: *HasherState(Hasher) = @ptrCast(@alignCast(ud.?));
    if (state.hasher) |h| {
        std.heap.page_allocator.destroy(h);
        state.hasher = null;
    }
}

fn md5Dtor(ud: ?*anyopaque) callconv(.c) void {
    hasherDtor(std.crypto.hash.Md5, ud);
}
fn sha1Dtor(ud: ?*anyopaque) callconv(.c) void {
    hasherDtor(std.crypto.hash.Sha1, ud);
}
fn sha256Dtor(ud: ?*anyopaque) callconv(.c) void {
    hasherDtor(std.crypto.hash.sha2.Sha256, ud);
}
fn sha512Dtor(ud: ?*anyopaque) callconv(.c) void {
    hasherDtor(std.crypto.hash.sha2.Sha512, ud);
}

fn getBytesArg(val: c.py_Ref, out: *[]const u8) bool {
    if (c.py_isnone(val)) {
        out.* = &[_]u8{};
        return true;
    }
    var size: c_int = 0;
    const ptr = c.py_tobytes(val, &size);
    if (ptr == null) {
        return c.py_exception(c.tp_TypeError, "expected bytes");
    }
    out.* = @as([*]const u8, @ptrCast(ptr))[0..@intCast(size)];
    return true;
}

fn setAttrInt(obj: c.py_Ref, name: [:0]const u8, value: i64) void {
    c.py_newint(c.py_r0(), value);
    c.py_setdict(obj, c.py_name(name), c.py_r0());
}

fn digestToPyBytes(out_ref: c.py_OutRef, bytes: []const u8) void {
    const buf = c.py_newbytes(out_ref, @intCast(bytes.len));
    if (bytes.len > 0) {
        @memcpy(@as([*]u8, @ptrCast(buf))[0..bytes.len], bytes);
    }
}

fn hexdigestBytes(bytes: []const u8) []u8 {
    const out = std.heap.page_allocator.alloc(u8, bytes.len * 2) catch return &[_]u8{};
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        const b = bytes[i];
        out[i * 2] = "0123456789abcdef"[b >> 4];
        out[i * 2 + 1] = "0123456789abcdef"[b & 0x0f];
    }
    return out;
}

fn updateImpl(comptime Hasher: type, self: c.py_Ref, data_val: c.py_Ref) bool {
    const state: *HasherState(Hasher) = @ptrCast(@alignCast(c.py_touserdata(self)));
    const hasher = state.hasher orelse return c.py_exception(c.tp_RuntimeError, "uninitialized hash object");
    var data: []const u8 = undefined;
    if (!getBytesArg(data_val, &data)) return false;
    hasher.update(data);
    return true;
}

fn digestImpl(comptime Hasher: type, comptime DigestLen: usize, self: c.py_Ref) void {
    const state: *HasherState(Hasher) = @ptrCast(@alignCast(c.py_touserdata(self)));
    const hasher = state.hasher orelse {
        _ = c.py_exception(c.tp_RuntimeError, "uninitialized hash object");
        return;
    };
    var tmp = hasher.*;
    const digest = tmp.finalResult();
    digestToPyBytes(c.py_retval(), digest[0..DigestLen]);
}

fn hexdigestImpl(comptime Hasher: type, comptime DigestLen: usize, self: c.py_Ref) void {
    const state: *HasherState(Hasher) = @ptrCast(@alignCast(c.py_touserdata(self)));
    const hasher = state.hasher orelse {
        _ = c.py_exception(c.tp_RuntimeError, "uninitialized hash object");
        return;
    };
    var tmp = hasher.*;
    const digest = tmp.finalResult();
    const hex = hexdigestBytes(digest[0..DigestLen]);
    defer if (hex.len > 0) std.heap.page_allocator.free(hex);
    const out = c.py_newstrn(c.py_retval(), @intCast(hex.len));
    if (hex.len > 0) {
        @memcpy(@as([*]u8, @ptrCast(out))[0..hex.len], hex);
    }
}

fn md5Update(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "update() takes exactly 1 argument");
    if (!updateImpl(std.crypto.hash.Md5, pk.argRef(argv, 0), pk.argRef(argv, 1))) return false;
    c.py_newnone(c.py_retval());
    return true;
}

fn md5Digest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "digest() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *Md5State = @ptrCast(@alignCast(c.py_touserdata(self)));
    const hasher = state.hasher orelse return c.py_exception(c.tp_RuntimeError, "uninitialized hash object");
    var tmp = hasher.*;
    var out: [std.crypto.hash.Md5.digest_length]u8 = undefined;
    tmp.final(&out);
    digestToPyBytes(c.py_retval(), out[0..]);
    return true;
}

fn md5Hexdigest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "hexdigest() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *Md5State = @ptrCast(@alignCast(c.py_touserdata(self)));
    const hasher = state.hasher orelse return c.py_exception(c.tp_RuntimeError, "uninitialized hash object");
    var tmp = hasher.*;
    var out: [std.crypto.hash.Md5.digest_length]u8 = undefined;
    tmp.final(&out);
    const hex = hexdigestBytes(out[0..]);
    defer if (hex.len > 0) std.heap.page_allocator.free(hex);
    const buf = c.py_newstrn(c.py_retval(), @intCast(hex.len));
    if (hex.len > 0) @memcpy(@as([*]u8, @ptrCast(buf))[0..hex.len], hex);
    return true;
}

fn sha1Update(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "update() takes exactly 1 argument");
    if (!updateImpl(std.crypto.hash.Sha1, pk.argRef(argv, 0), pk.argRef(argv, 1))) return false;
    c.py_newnone(c.py_retval());
    return true;
}

fn sha1Digest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "digest() takes no arguments");
    digestImpl(std.crypto.hash.Sha1, 20, pk.argRef(argv, 0));
    return true;
}

fn sha1Hexdigest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "hexdigest() takes no arguments");
    hexdigestImpl(std.crypto.hash.Sha1, 20, pk.argRef(argv, 0));
    return true;
}

fn sha256Update(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "update() takes exactly 1 argument");
    if (!updateImpl(std.crypto.hash.sha2.Sha256, pk.argRef(argv, 0), pk.argRef(argv, 1))) return false;
    c.py_newnone(c.py_retval());
    return true;
}

fn sha256Digest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "digest() takes no arguments");
    digestImpl(std.crypto.hash.sha2.Sha256, 32, pk.argRef(argv, 0));
    return true;
}

fn sha256Hexdigest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "hexdigest() takes no arguments");
    hexdigestImpl(std.crypto.hash.sha2.Sha256, 32, pk.argRef(argv, 0));
    return true;
}

fn sha512Update(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "update() takes exactly 1 argument");
    if (!updateImpl(std.crypto.hash.sha2.Sha512, pk.argRef(argv, 0), pk.argRef(argv, 1))) return false;
    c.py_newnone(c.py_retval());
    return true;
}

fn sha512Digest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "digest() takes no arguments");
    digestImpl(std.crypto.hash.sha2.Sha512, 64, pk.argRef(argv, 0));
    return true;
}

fn sha512Hexdigest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "hexdigest() takes no arguments");
    hexdigestImpl(std.crypto.hash.sha2.Sha512, 64, pk.argRef(argv, 0));
    return true;
}

fn newHashObject(comptime Hasher: type, tp: c.py_Type, initial: []const u8) bool {
    const ud = c.py_newobject(c.py_retval(), tp, -1, @sizeOf(HasherState(Hasher)));
    const state: *HasherState(Hasher) = @ptrCast(@alignCast(ud));
    state.* = .{};
    const hasher = std.heap.page_allocator.create(Hasher) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    state.hasher = hasher;
    hasher.* = Hasher.init(.{});
    if (initial.len > 0) hasher.update(initial);
    return true;
}

fn md5Fn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc > 1) return c.py_exception(c.tp_TypeError, "md5() takes at most 1 argument");
    var data: []const u8 = &[_]u8{};
    if (argc == 1) {
        if (!getBytesArg(pk.argRef(argv, 0), &data)) return false;
    }
    if (!newHashObject(std.crypto.hash.Md5, tp_md5, data)) return false;
    setAttrInt(c.py_retval(), "digest_size", 16);
    setAttrInt(c.py_retval(), "block_size", 64);
    return true;
}

fn sha1Fn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc > 1) return c.py_exception(c.tp_TypeError, "sha1() takes at most 1 argument");
    var data: []const u8 = &[_]u8{};
    if (argc == 1) {
        if (!getBytesArg(pk.argRef(argv, 0), &data)) return false;
    }
    if (!newHashObject(std.crypto.hash.Sha1, tp_sha1, data)) return false;
    setAttrInt(c.py_retval(), "digest_size", 20);
    setAttrInt(c.py_retval(), "block_size", 64);
    return true;
}

fn sha256Fn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc > 1) return c.py_exception(c.tp_TypeError, "sha256() takes at most 1 argument");
    var data: []const u8 = &[_]u8{};
    if (argc == 1) {
        if (!getBytesArg(pk.argRef(argv, 0), &data)) return false;
    }
    if (!newHashObject(std.crypto.hash.sha2.Sha256, tp_sha256, data)) return false;
    setAttrInt(c.py_retval(), "digest_size", 32);
    setAttrInt(c.py_retval(), "block_size", 64);
    return true;
}

fn sha512Fn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc > 1) return c.py_exception(c.tp_TypeError, "sha512() takes at most 1 argument");
    var data: []const u8 = &[_]u8{};
    if (argc == 1) {
        if (!getBytesArg(pk.argRef(argv, 0), &data)) return false;
    }
    if (!newHashObject(std.crypto.hash.sha2.Sha512, tp_sha512, data)) return false;
    setAttrInt(c.py_retval(), "digest_size", 64);
    setAttrInt(c.py_retval(), "block_size", 128);
    return true;
}

fn newFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "new() takes 1 or 2 arguments");
    const name_c = c.py_tostr(pk.argRef(argv, 0)) orelse return c.py_exception(c.tp_TypeError, "name must be a string");
    const name = std.mem.span(name_c);
    var data: []const u8 = &[_]u8{};
    if (argc == 2) {
        if (!getBytesArg(pk.argRef(argv, 1), &data)) return false;
    }

    // Construct directly to avoid needing to reshuffle argv.
    if (std.ascii.eqlIgnoreCase(name, "md5")) {
        if (!newHashObject(std.crypto.hash.Md5, tp_md5, data)) return false;
        setAttrInt(c.py_retval(), "digest_size", 16);
        setAttrInt(c.py_retval(), "block_size", 64);
        return true;
    }
    if (std.ascii.eqlIgnoreCase(name, "sha1")) {
        if (!newHashObject(std.crypto.hash.Sha1, tp_sha1, data)) return false;
        setAttrInt(c.py_retval(), "digest_size", 20);
        setAttrInt(c.py_retval(), "block_size", 64);
        return true;
    }
    if (std.ascii.eqlIgnoreCase(name, "sha256")) {
        if (!newHashObject(std.crypto.hash.sha2.Sha256, tp_sha256, data)) return false;
        setAttrInt(c.py_retval(), "digest_size", 32);
        setAttrInt(c.py_retval(), "block_size", 64);
        return true;
    }
    if (std.ascii.eqlIgnoreCase(name, "sha512")) {
        if (!newHashObject(std.crypto.hash.sha2.Sha512, tp_sha512, data)) return false;
        setAttrInt(c.py_retval(), "digest_size", 64);
        setAttrInt(c.py_retval(), "block_size", 128);
        return true;
    }
    return c.py_exception(c.tp_ValueError, "unsupported hash type");
}

pub fn register() void {
    const name: [:0]const u8 = "hashlib";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);

    tp_md5 = c.py_newtype("MD5", c.tp_object, module, md5Dtor);
    c.py_bindmethod(tp_md5, "update", md5Update);
    c.py_bindmethod(tp_md5, "digest", md5Digest);
    c.py_bindmethod(tp_md5, "hexdigest", md5Hexdigest);

    tp_sha1 = c.py_newtype("SHA1", c.tp_object, module, sha1Dtor);
    c.py_bindmethod(tp_sha1, "update", sha1Update);
    c.py_bindmethod(tp_sha1, "digest", sha1Digest);
    c.py_bindmethod(tp_sha1, "hexdigest", sha1Hexdigest);

    tp_sha256 = c.py_newtype("SHA256", c.tp_object, module, sha256Dtor);
    c.py_bindmethod(tp_sha256, "update", sha256Update);
    c.py_bindmethod(tp_sha256, "digest", sha256Digest);
    c.py_bindmethod(tp_sha256, "hexdigest", sha256Hexdigest);

    tp_sha512 = c.py_newtype("SHA512", c.tp_object, module, sha512Dtor);
    c.py_bindmethod(tp_sha512, "update", sha512Update);
    c.py_bindmethod(tp_sha512, "digest", sha512Digest);
    c.py_bindmethod(tp_sha512, "hexdigest", sha512Hexdigest);

    c.py_bind(module, "md5(data=None)", md5Fn);
    c.py_bind(module, "sha1(data=None)", sha1Fn);
    c.py_bind(module, "sha256(data=None)", sha256Fn);
    c.py_bind(module, "sha512(data=None)", sha512Fn);
    c.py_bind(module, "new(name, data=None)", newFn);
}
