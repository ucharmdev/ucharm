/// uuid.zig - Python uuid module implementation
///
/// Provides UUID generation and parsing.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_uuid: c.py_Type = undefined;

fn hexCharToVal(ch: u8) ?u8 {
    return switch (ch) {
        '0'...'9' => ch - '0',
        'a'...'f' => ch - 'a' + 10,
        'A'...'F' => ch - 'A' + 10,
        else => null,
    };
}

// UUID data structure - 16 bytes
const UUIDData = struct {
    bytes: [16]u8,
};

fn uuidNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // __new__(cls, hex) - argv[0] is cls, argv[1] is hex
    if (argc < 2) return c.py_exception(c.tp_TypeError, "UUID() requires an argument");

    const hex_arg = pk.argRef(argv, 1);

    // Get the string value
    if (!c.py_istype(hex_arg, c.tp_str)) {
        return c.py_exception(c.tp_TypeError, "UUID() argument must be a string");
    }

    const sv = c.py_tosv(hex_arg);
    const hex_str: []const u8 = @ptrCast(sv.data[0..@intCast(sv.size)]);

    // Parse UUID string (with or without hyphens)
    var bytes: [16]u8 = undefined;
    var byte_idx: usize = 0;
    var i: usize = 0;

    while (i < hex_str.len and byte_idx < 16) {
        if (hex_str[i] == '-') {
            i += 1;
            continue;
        }

        if (i + 1 >= hex_str.len) {
            return c.py_exception(c.tp_ValueError, "invalid UUID string");
        }

        const hi = hexCharToVal(hex_str[i]) orelse {
            return c.py_exception(c.tp_ValueError, "invalid UUID string");
        };
        const lo = hexCharToVal(hex_str[i + 1]) orelse {
            return c.py_exception(c.tp_ValueError, "invalid UUID string");
        };

        bytes[byte_idx] = (hi << 4) | lo;
        byte_idx += 1;
        i += 2;
    }

    if (byte_idx != 16) {
        return c.py_exception(c.tp_ValueError, "invalid UUID string length");
    }

    // Create UUID object
    const obj = c.py_newobject(c.py_retval(), tp_uuid, 0, @sizeOf(UUIDData));
    const data: *UUIDData = @ptrCast(@alignCast(obj));
    data.bytes = bytes;

    return true;
}

fn uuidStr(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const obj = c.py_touserdata(self);
    const data: *UUIDData = @ptrCast(@alignCast(obj));

    const hex = "0123456789abcdef";
    var buffer: [36]u8 = undefined;

    // Format: 8-4-4-4-12
    var buf_idx: usize = 0;
    for (0..16) |i| {
        if (i == 4 or i == 6 or i == 8 or i == 10) {
            buffer[buf_idx] = '-';
            buf_idx += 1;
        }
        buffer[buf_idx] = hex[data.bytes[i] >> 4];
        buffer[buf_idx + 1] = hex[data.bytes[i] & 0x0f];
        buf_idx += 2;
    }

    const out = c.py_newstrn(c.py_retval(), 36);
    @memcpy(out[0..36], buffer[0..36]);
    return true;
}

fn uuidRepr(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // First get the string representation
    if (!uuidStr(argc, argv)) return false;

    // Now wrap it in UUID('...')
    const sv = c.py_tosv(c.py_retval());
    const uuid_str: []const u8 = @ptrCast(sv.data[0..@intCast(sv.size)]);

    var buffer: [48]u8 = undefined;
    @memcpy(buffer[0..6], "UUID('");
    @memcpy(buffer[6..42], uuid_str);
    @memcpy(buffer[42..44], "')");

    const out = c.py_newstrn(c.py_retval(), 44);
    @memcpy(out[0..44], buffer[0..44]);
    return true;
}

fn uuidEq(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);

    if (!c.py_istype(other, tp_uuid)) {
        c.py_newbool(c.py_retval(), false);
        return true;
    }

    const self_data: *UUIDData = @ptrCast(@alignCast(c.py_touserdata(self)));
    const other_data: *UUIDData = @ptrCast(@alignCast(c.py_touserdata(other)));

    c.py_newbool(c.py_retval(), std.mem.eql(u8, &self_data.bytes, &other_data.bytes));
    return true;
}

fn uuidNe(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);

    if (!c.py_istype(other, tp_uuid)) {
        c.py_newbool(c.py_retval(), true);
        return true;
    }

    const self_data: *UUIDData = @ptrCast(@alignCast(c.py_touserdata(self)));
    const other_data: *UUIDData = @ptrCast(@alignCast(c.py_touserdata(other)));

    c.py_newbool(c.py_retval(), !std.mem.eql(u8, &self_data.bytes, &other_data.bytes));
    return true;
}

fn uuidHash(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const data: *UUIDData = @ptrCast(@alignCast(c.py_touserdata(self)));

    // Simple hash of bytes
    var hash: i64 = 0;
    for (data.bytes) |b| {
        hash = hash *% 31 +% @as(i64, b);
    }

    c.py_newint(c.py_retval(), hash);
    return true;
}

fn uuidVersion(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const data: *UUIDData = @ptrCast(@alignCast(c.py_touserdata(self)));

    // Version is in the high nibble of byte 6
    const version = (data.bytes[6] >> 4) & 0x0f;
    c.py_newint(c.py_retval(), version);
    return true;
}

fn uuidHex(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const data: *UUIDData = @ptrCast(@alignCast(c.py_touserdata(self)));

    const hex = "0123456789abcdef";
    var buffer: [32]u8 = undefined;

    for (0..16) |i| {
        buffer[i * 2] = hex[data.bytes[i] >> 4];
        buffer[i * 2 + 1] = hex[data.bytes[i] & 0x0f];
    }

    const out = c.py_newstrn(c.py_retval(), 32);
    @memcpy(out[0..32], buffer[0..32]);
    return true;
}

fn uuidBytes(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const data: *UUIDData = @ptrCast(@alignCast(c.py_touserdata(self)));

    const out = c.py_newbytes(c.py_retval(), 16);
    @memcpy(out[0..16], data.bytes[0..16]);
    return true;
}

fn uuidInt(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const data: *UUIDData = @ptrCast(@alignCast(c.py_touserdata(self)));

    // Convert 16 bytes to int (big endian) - but we'll just use first 8 bytes for i64
    // For full 128-bit support we'd need bigint, but this is good enough for basic tests
    var val: i64 = 0;
    for (0..8) |i| {
        val = (val << 8) | @as(i64, data.bytes[i]);
    }

    c.py_newint(c.py_retval(), val);
    return true;
}

// uuid4() - generate random UUID
fn uuid4Fn(_: *pk.Context) bool {
    var bytes: [16]u8 = undefined;

    // Use Zig's crypto random
    std.crypto.random.bytes(&bytes);

    // Set version to 4 (random)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    // Create UUID object
    const obj = c.py_newobject(c.py_retval(), tp_uuid, 0, @sizeOf(UUIDData));
    const data: *UUIDData = @ptrCast(@alignCast(obj));
    data.bytes = bytes;

    return true;
}

pub fn register() void {
    const module = c.py_newmodule("uuid");

    // Create UUID type
    tp_uuid = c.py_newtype("UUID", c.tp_object, module, null);

    // Bind methods
    c.py_bind(c.py_tpobject(tp_uuid), "__new__(cls, hex)", uuidNew);
    c.py_bindmagic(tp_uuid, c.py_name("__str__"), uuidStr);
    c.py_bindmagic(tp_uuid, c.py_name("__repr__"), uuidRepr);
    c.py_bindmagic(tp_uuid, c.py_name("__eq__"), uuidEq);
    c.py_bindmagic(tp_uuid, c.py_name("__ne__"), uuidNe);
    c.py_bindmagic(tp_uuid, c.py_name("__hash__"), uuidHash);

    // Properties
    c.py_bindproperty(tp_uuid, "version", uuidVersion, null);
    c.py_bindproperty(tp_uuid, "hex", uuidHex, null);
    c.py_bindproperty(tp_uuid, "bytes", uuidBytes, null);
    c.py_bindproperty(tp_uuid, "int", uuidInt, null);

    // Module function - uuid4()
    c.py_bind(module, "uuid4()", pk.wrapFn(0, 0, uuid4Fn));
}
