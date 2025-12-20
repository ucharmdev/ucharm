const pk = @import("pk");
const c = pk.c;
const std = @import("std");
const builtin = @import("builtin");

var tp_error: c.py_Type = 0;
var tp_struct: c.py_Type = 0;
var tp_bytearray: c.py_Type = 0;

const Endian = std.builtin.Endian;

const FormatCode = enum {
    b,
    B,
    h,
    H,
    i,
    I,
    l,
    L,
    q,
    Q,
    f,
    d,
    x,
};

const Item = struct {
    code: FormatCode,
    count: usize,
};

const ParsedFormat = struct {
    endian: Endian,
    items: []Item,
    value_count: usize,
    size: usize,
};

const ByteArrayState = struct {
    ptr: ?[*]u8 = null,
    len: usize = 0,
};

fn bytearrayDtor(ud: ?*anyopaque) callconv(.c) void {
    if (ud == null) return;
    const state: *ByteArrayState = @ptrCast(@alignCast(ud.?));
    if (state.ptr) |p| {
        std.heap.page_allocator.free(p[0..state.len]);
    }
}

fn bytearrayNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // __new__(cls, source=None)
    // source can be: int (size), bytes, bytearray, str, or iterable of ints
    if (argc > 2) return c.py_exception(c.tp_TypeError, "bytearray() takes at most 1 argument");
    _ = pk.argRef(argv, 0);
    const ud = c.py_newobject(c.py_retval(), tp_bytearray, -1, @sizeOf(ByteArrayState));
    const state: *ByteArrayState = @ptrCast(@alignCast(ud));
    state.* = .{};

    if (argc == 1) {
        // No argument - empty bytearray
        return true;
    }

    const arg = pk.argRef(argv, 1);

    // Case 1: Integer - create zero-filled bytearray of that size
    if (c.py_isint(arg)) {
        const n = c.py_toint(arg);
        if (n < 0) return c.py_exception(c.tp_ValueError, "negative count");
        const len: usize = @intCast(n);
        if (len > 0) {
            const mem = std.heap.page_allocator.alloc(u8, len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            @memset(mem, 0);
            state.ptr = mem.ptr;
            state.len = len;
        }
        return true;
    }

    // Case 2: bytes object - copy the bytes
    if (c.py_istype(arg, c.tp_bytes)) {
        var src_len: c_int = 0;
        const src_ptr = c.py_tobytes(arg, &src_len);
        const len: usize = @intCast(src_len);
        if (len > 0) {
            const mem = std.heap.page_allocator.alloc(u8, len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            @memcpy(mem, src_ptr[0..len]);
            state.ptr = mem.ptr;
            state.len = len;
        }
        return true;
    }

    // Case 3: bytearray object - copy its contents
    if (c.py_istype(arg, tp_bytearray)) {
        const src_state: *ByteArrayState = @ptrCast(@alignCast(c.py_touserdata(arg)));
        if (src_state.len > 0 and src_state.ptr != null) {
            const mem = std.heap.page_allocator.alloc(u8, src_state.len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            @memcpy(mem, src_state.ptr.?[0..src_state.len]);
            state.ptr = mem.ptr;
            state.len = src_state.len;
        }
        return true;
    }

    // Case 4: str object - encode as UTF-8 (simplified: just copy the bytes)
    if (c.py_isstr(arg)) {
        const src_sv = c.py_tosv(arg);
        const len: usize = @intCast(src_sv.size);
        if (len > 0) {
            const mem = std.heap.page_allocator.alloc(u8, len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            @memcpy(mem, @as([*]const u8, @ptrCast(src_sv.data))[0..len]);
            state.ptr = mem.ptr;
            state.len = len;
        }
        return true;
    }

    // Case 5: list of ints
    if (c.py_istype(arg, c.tp_list)) {
        const list_len = c.py_list_len(arg);
        if (list_len < 0) return c.py_exception(c.tp_RuntimeError, "invalid list");
        const len: usize = @intCast(list_len);
        if (len > 0) {
            const mem = std.heap.page_allocator.alloc(u8, len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            var i: c_int = 0;
            while (i < list_len) : (i += 1) {
                const item = c.py_list_getitem(arg, i);
                if (!c.py_isint(item)) {
                    std.heap.page_allocator.free(mem);
                    return c.py_exception(c.tp_TypeError, "an integer is required");
                }
                const val = c.py_toint(item);
                if (val < 0 or val > 255) {
                    std.heap.page_allocator.free(mem);
                    return c.py_exception(c.tp_ValueError, "byte must be in range(0, 256)");
                }
                mem[@intCast(i)] = @intCast(val);
            }
            state.ptr = mem.ptr;
            state.len = len;
        }
        return true;
    }

    return c.py_exception(c.tp_TypeError, "cannot convert object to bytearray");
}

fn bytearrayLen(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__len__ takes no arguments");
    const state: *ByteArrayState = @ptrCast(@alignCast(c.py_touserdata(pk.argRef(argv, 0))));
    c.py_newint(c.py_retval(), @intCast(state.len));
    return true;
}

fn bytearrayGetItem(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "__getitem__ takes 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *ByteArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const key = pk.argRef(argv, 1);

    if (c.py_isint(key)) {
        var idx: i64 = c.py_toint(key);
        if (idx < 0) idx += @intCast(state.len);
        if (idx < 0 or idx >= @as(i64, @intCast(state.len))) return c.py_exception(c.tp_IndexError, "index out of range");
        const b = state.ptr.?[@intCast(idx)];
        c.py_newint(c.py_retval(), @intCast(b));
        return true;
    }

    if (c.py_istype(key, c.tp_slice)) {
        const start_obj = c.py_getslot(key, 0);
        const stop_obj = c.py_getslot(key, 1);
        const step_obj = c.py_getslot(key, 2);
        var start: i64 = 0;
        var stop: i64 = @intCast(state.len);
        var step: i64 = 1;
        if (!c.py_isnone(start_obj)) start = c.py_toint(start_obj);
        if (!c.py_isnone(stop_obj)) stop = c.py_toint(stop_obj);
        if (!c.py_isnone(step_obj)) step = c.py_toint(step_obj);
        if (step != 1) return c.py_exception(c.tp_ValueError, "slice step not supported");
        if (start < 0) start += @intCast(state.len);
        if (stop < 0) stop += @intCast(state.len);
        if (start < 0) start = 0;
        if (stop < 0) stop = 0;
        if (start > @as(i64, @intCast(state.len))) start = @intCast(state.len);
        if (stop > @as(i64, @intCast(state.len))) stop = @intCast(state.len);
        if (stop < start) stop = start;
        const out_len: usize = @intCast(stop - start);
        const buf = c.py_newbytes(c.py_retval(), @intCast(out_len));
        if (out_len > 0) {
            const dst = @as([*]u8, @ptrCast(buf))[0..out_len];
            const src = state.ptr.?[@intCast(start)..@intCast(stop)];
            @memcpy(dst, src);
        }
        return true;
    }

    return c.py_exception(c.tp_TypeError, "invalid index type");
}

fn bytearraySetItem(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 3) return c.py_exception(c.tp_TypeError, "__setitem__ takes 2 arguments");
    const self = pk.argRef(argv, 0);
    const state: *ByteArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const key = pk.argRef(argv, 1);
    const val = pk.argRef(argv, 2);
    if (!c.py_isint(key)) return c.py_exception(c.tp_TypeError, "index must be int");
    var idx: i64 = c.py_toint(key);
    if (idx < 0) idx += @intCast(state.len);
    if (idx < 0 or idx >= @as(i64, @intCast(state.len))) return c.py_exception(c.tp_IndexError, "index out of range");
    const v = c.py_toint(val);
    if (v < 0 or v > 255) return c.py_exception(c.tp_ValueError, "byte must be in range(0, 256)");
    state.ptr.?[@intCast(idx)] = @intCast(v);
    c.py_newnone(c.py_retval());
    return true;
}

fn bytearrayEq(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "__eq__ takes 1 argument");
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    const self_state: *ByteArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    // Compare with another bytearray
    if (c.py_istype(other, tp_bytearray)) {
        const other_state: *ByteArrayState = @ptrCast(@alignCast(c.py_touserdata(other)));
        if (self_state.len != other_state.len) {
            c.py_newbool(c.py_retval(), false);
            return true;
        }
        if (self_state.len == 0) {
            c.py_newbool(c.py_retval(), true);
            return true;
        }
        const self_data = self_state.ptr.?[0..self_state.len];
        const other_data = other_state.ptr.?[0..other_state.len];
        c.py_newbool(c.py_retval(), std.mem.eql(u8, self_data, other_data));
        return true;
    }

    // Compare with bytes
    if (c.py_istype(other, c.tp_bytes)) {
        var other_len: c_int = 0;
        const other_ptr = c.py_tobytes(other, &other_len);
        if (self_state.len != @as(usize, @intCast(other_len))) {
            c.py_newbool(c.py_retval(), false);
            return true;
        }
        if (self_state.len == 0) {
            c.py_newbool(c.py_retval(), true);
            return true;
        }
        const self_data = self_state.ptr.?[0..self_state.len];
        const other_data = other_ptr[0..@intCast(other_len)];
        c.py_newbool(c.py_retval(), std.mem.eql(u8, self_data, other_data));
        return true;
    }

    // Not comparable - return NotImplemented
    c.py_newnotimplemented(c.py_retval());
    return true;
}

fn bytearrayRepr(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__repr__ takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *ByteArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    // Build repr like: bytearray(b'hello')
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();
    writer.writeAll("bytearray(b'") catch return c.py_exception(c.tp_RuntimeError, "repr too long");
    if (state.len > 0 and state.ptr != null) {
        for (state.ptr.?[0..state.len]) |byte| {
            if (byte >= 32 and byte < 127 and byte != '\'' and byte != '\\') {
                writer.writeByte(byte) catch return c.py_exception(c.tp_RuntimeError, "repr too long");
            } else {
                writer.print("\\x{x:0>2}", .{byte}) catch return c.py_exception(c.tp_RuntimeError, "repr too long");
            }
        }
    }
    writer.writeAll("')") catch return c.py_exception(c.tp_RuntimeError, "repr too long");
    const written = fbs.getWritten();
    const out = c.py_newstrn(c.py_retval(), @intCast(written.len));
    @memcpy(out[0..written.len], written);
    return true;
}

fn raiseStructError(msg: [:0]const u8) bool {
    if (tp_error != 0) return c.py_exception(tp_error, msg);
    return c.py_exception(c.tp_ValueError, msg);
}

fn codeSize(code: FormatCode) usize {
    return switch (code) {
        .b, .B, .x => 1,
        .h, .H => 2,
        .i, .I => 4,
        .l, .L => 8,
        .q, .Q => 8,
        .f => 4,
        .d => 8,
    };
}

fn parseEndianPrefix(fmt: []const u8, idx: *usize) Endian {
    const native: Endian = builtin.cpu.arch.endian();
    if (idx.* >= fmt.len) return native;
    return switch (fmt[idx.*]) {
        '<' => blk: {
            idx.* += 1;
            break :blk .little;
        },
        '>' => blk: {
            idx.* += 1;
            break :blk .big;
        },
        '!' => blk: {
            idx.* += 1;
            break :blk .big;
        },
        '@', '=' => blk: {
            idx.* += 1;
            break :blk native;
        },
        else => native,
    };
}

fn parseCode(ch: u8) ?FormatCode {
    return switch (ch) {
        'b' => .b,
        'B' => .B,
        'h' => .h,
        'H' => .H,
        'i' => .i,
        'I' => .I,
        'l' => .l,
        'L' => .L,
        'q' => .q,
        'Q' => .Q,
        'f' => .f,
        'd' => .d,
        'x' => .x,
        else => null,
    };
}

fn parseFormat(alloc: std.mem.Allocator, fmt: []const u8) !ParsedFormat {
    var idx: usize = 0;
    const endian = parseEndianPrefix(fmt, &idx);

    var items = std.ArrayList(Item).empty;
    errdefer items.deinit(alloc);

    var value_count: usize = 0;
    var total_size: usize = 0;

    while (idx < fmt.len) : (idx += 1) {
        var count: usize = 0;
        while (idx < fmt.len and std.ascii.isDigit(fmt[idx])) : (idx += 1) {
            count = count * 10 + (fmt[idx] - '0');
        }
        if (count == 0) count = 1;
        if (idx >= fmt.len) break;

        const code = parseCode(fmt[idx]) orelse return error.UnsupportedFormat;
        items.append(alloc, .{ .code = code, .count = count }) catch return error.OutOfMemory;
        const item_size = codeSize(code) * count;
        total_size += item_size;
        if (code != .x) value_count += count;
    }

    return .{
        .endian = endian,
        .items = try items.toOwnedSlice(alloc),
        .value_count = value_count,
        .size = total_size,
    };
}

fn packInt(comptime T: type, endian: Endian, out: []u8, value: T) void {
    std.mem.writeInt(T, out[0..@sizeOf(T)], value, endian);
}

fn unpackInt(comptime T: type, endian: Endian, inp: []const u8) T {
    return std.mem.readInt(T, inp[0..@sizeOf(T)], endian);
}

fn packOneValue(code: FormatCode, endian: Endian, out: []u8, value: c.py_Ref) bool {
    switch (code) {
        .x => return true,
        .b => {
            const v = c.py_toint(value);
            if (v < -128 or v > 127) return raiseStructError("byte format requires -128 <= number <= 127");
            out[0] = @bitCast(@as(i8, @intCast(v)));
            return true;
        },
        .B => {
            const v = c.py_toint(value);
            if (v < 0 or v > 255) return raiseStructError("ubyte format requires 0 <= number <= 255");
            out[0] = @intCast(v);
            return true;
        },
        .h => {
            const v = c.py_toint(value);
            if (v < std.math.minInt(i16) or v > std.math.maxInt(i16)) return raiseStructError("short format out of range");
            packInt(i16, endian, out, @intCast(v));
            return true;
        },
        .H => {
            const v = c.py_toint(value);
            if (v < 0 or v > std.math.maxInt(u16)) return raiseStructError("ushort format out of range");
            packInt(u16, endian, out, @intCast(v));
            return true;
        },
        .i => {
            const v = c.py_toint(value);
            if (v < std.math.minInt(i32) or v > std.math.maxInt(i32)) return raiseStructError("int format out of range");
            packInt(i32, endian, out, @intCast(v));
            return true;
        },
        .I => {
            const v = c.py_toint(value);
            if (v < 0 or v > std.math.maxInt(u32)) return raiseStructError("uint format out of range");
            packInt(u32, endian, out, @intCast(v));
            return true;
        },
        .l => {
            const v = c.py_toint(value);
            if (v < std.math.minInt(i64) or v > std.math.maxInt(i64)) return raiseStructError("long format out of range");
            packInt(i64, endian, out, @intCast(v));
            return true;
        },
        .L => {
            const v = c.py_toint(value);
            if (v < 0) return raiseStructError("ulong format out of range");
            packInt(u64, endian, out, @intCast(v));
            return true;
        },
        .q => {
            const v = c.py_toint(value);
            packInt(i64, endian, out, @intCast(v));
            return true;
        },
        .Q => {
            const v = c.py_toint(value);
            if (v < 0) return raiseStructError("ulonglong format out of range");
            packInt(u64, endian, out, @intCast(v));
            return true;
        },
        .f => {
            var f: f32 = 0;
            if (!c.py_castfloat32(value, &f)) return false;
            const bits: u32 = @bitCast(f);
            packInt(u32, endian, out, bits);
            return true;
        },
        .d => {
            var f: f64 = 0;
            if (!c.py_castfloat(value, &f)) return false;
            const bits: u64 = @bitCast(f);
            packInt(u64, endian, out, bits);
            return true;
        },
    }
}

fn unpackOneValue(code: FormatCode, endian: Endian, inp: []const u8) bool {
    switch (code) {
        .x => unreachable,
        .b => {
            const v: i8 = @bitCast(inp[0]);
            c.py_newint(c.py_retval(), v);
            return true;
        },
        .B => {
            c.py_newint(c.py_retval(), inp[0]);
            return true;
        },
        .h => {
            const v = unpackInt(i16, endian, inp);
            c.py_newint(c.py_retval(), v);
            return true;
        },
        .H => {
            const v = unpackInt(u16, endian, inp);
            c.py_newint(c.py_retval(), @intCast(v));
            return true;
        },
        .i => {
            const v = unpackInt(i32, endian, inp);
            c.py_newint(c.py_retval(), v);
            return true;
        },
        .I => {
            const v = unpackInt(u32, endian, inp);
            c.py_newint(c.py_retval(), @intCast(v));
            return true;
        },
        .l => {
            const v = unpackInt(i64, endian, inp);
            c.py_newint(c.py_retval(), v);
            return true;
        },
        .L => {
            const v = unpackInt(u64, endian, inp);
            c.py_newint(c.py_retval(), @intCast(v));
            return true;
        },
        .q => {
            const v = unpackInt(i64, endian, inp);
            c.py_newint(c.py_retval(), v);
            return true;
        },
        .Q => {
            const v = unpackInt(u64, endian, inp);
            c.py_newint(c.py_retval(), @intCast(v));
            return true;
        },
        .f => {
            const bits = unpackInt(u32, endian, inp);
            const f: f32 = @bitCast(bits);
            c.py_newfloat(c.py_retval(), f);
            return true;
        },
        .d => {
            const bits = unpackInt(u64, endian, inp);
            const f: f64 = @bitCast(bits);
            c.py_newfloat(c.py_retval(), f);
            return true;
        },
    }
}

fn pack(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "pack() missing format");
    const fmt_c = c.py_tostr(pk.argRef(argv, 0)) orelse return c.py_exception(c.tp_TypeError, "format must be a string");
    const fmt = std.mem.span(fmt_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch {
        return raiseStructError("unsupported format");
    };

    var values_tuple: ?c.py_Ref = null;
    var provided_values: usize = 0;
    if (argc == 2 and c.py_istuple(pk.argRef(argv, 1))) {
        values_tuple = pk.argRef(argv, 1);
        provided_values = @intCast(c.py_tuple_len(values_tuple.?));
    } else {
        provided_values = if (argc > 1) @intCast(argc - 1) else 0;
    }
    if (provided_values != parsed.value_count) {
        return raiseStructError("pack expected a different number of items");
    }

    const buf_ptr = c.py_newbytes(c.py_retval(), @intCast(parsed.size));
    const out = @as([*]u8, @ptrCast(buf_ptr))[0..parsed.size];

    var out_idx: usize = 0;
    var val_idx: usize = 0;
    for (parsed.items) |it| {
        var n: usize = 0;
        while (n < it.count) : (n += 1) {
            if (it.code == .x) {
                out[out_idx] = 0;
                out_idx += 1;
                continue;
            }
            const value_ref = if (values_tuple) |t| c.py_tuple_getitem(t, @intCast(val_idx)) else pk.argRef(argv, 1 + val_idx);
            val_idx += 1;
            const sz = codeSize(it.code);
            if (!packOneValue(it.code, parsed.endian, out[out_idx .. out_idx + sz], value_ref)) return false;
            out_idx += sz;
        }
    }
    return true;
}

fn unpack(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "unpack() takes exactly 2 arguments");
    const fmt_c = c.py_tostr(pk.argRef(argv, 0)) orelse return c.py_exception(c.tp_TypeError, "format must be a string");
    const fmt = std.mem.span(fmt_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch {
        return raiseStructError("unsupported format");
    };

    var size: c_int = 0;
    const data_ptr = c.py_tobytes(pk.argRef(argv, 1), &size);
    if (data_ptr == null) return c.py_exception(c.tp_TypeError, "data must be bytes");
    if (@as(usize, @intCast(size)) != parsed.size) return raiseStructError("unpack requires a buffer of the correct size");
    const data = @as([*]const u8, @ptrCast(data_ptr))[0..parsed.size];

    _ = c.py_newtuple(c.py_r0(), @intCast(parsed.value_count));
    const tup = c.py_r0();
    var tup_idx: c_int = 0;
    var in_idx: usize = 0;
    for (parsed.items) |it| {
        var n: usize = 0;
        while (n < it.count) : (n += 1) {
            const sz = codeSize(it.code);
            if (it.code == .x) {
                in_idx += sz;
                continue;
            }
            if (!unpackOneValue(it.code, parsed.endian, data[in_idx .. in_idx + sz])) return false;
            c.py_tuple_setitem(tup, tup_idx, c.py_retval());
            tup_idx += 1;
            in_idx += sz;
        }
    }
    pk.setRetval(tup);
    return true;
}

fn calcsize(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "calcsize() takes exactly 1 argument");
    const fmt_c = c.py_tostr(pk.argRef(argv, 0)) orelse return c.py_exception(c.tp_TypeError, "format must be a string");
    const fmt = std.mem.span(fmt_c);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch {
        return raiseStructError("unsupported format");
    };
    c.py_newint(c.py_retval(), @intCast(parsed.size));
    return true;
}

fn pack_into(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 3) return c.py_exception(c.tp_TypeError, "pack_into() requires format, buffer, offset");
    const fmt_c = c.py_tostr(pk.argRef(argv, 0)) orelse return c.py_exception(c.tp_TypeError, "format must be a string");
    const fmt = std.mem.span(fmt_c);
    const buffer = pk.argRef(argv, 1);
    const offset_val = c.py_toint(pk.argRef(argv, 2));
    if (offset_val < 0) return raiseStructError("offset must be >= 0");
    const offset: usize = @intCast(offset_val);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch {
        return raiseStructError("unsupported format");
    };

    var values_tuple: ?c.py_Ref = null;
    var provided_values: usize = 0;
    if (argc == 4 and c.py_istuple(pk.argRef(argv, 3))) {
        values_tuple = pk.argRef(argv, 3);
        provided_values = @intCast(c.py_tuple_len(values_tuple.?));
    } else {
        provided_values = if (argc > 3) @intCast(argc - 3) else 0;
    }
    if (provided_values != parsed.value_count) {
        return raiseStructError("pack_into expected a different number of items");
    }

    if (!c.py_len(buffer)) return false;
    const buf_len = @as(usize, @intCast(c.py_toint(c.py_retval())));
    if (offset + parsed.size > buf_len) return raiseStructError("buffer too small");

    const tmp = std.heap.page_allocator.alloc(u8, parsed.size) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    defer std.heap.page_allocator.free(tmp);
    @memset(tmp, 0);

    var out_idx: usize = 0;
    var val_idx: usize = 0;
    for (parsed.items) |it| {
        var n: usize = 0;
        while (n < it.count) : (n += 1) {
            const sz = codeSize(it.code);
            if (it.code == .x) {
                tmp[out_idx] = 0;
                out_idx += 1;
                continue;
            }
            const value_ref = if (values_tuple) |t| c.py_tuple_getitem(t, @intCast(val_idx)) else pk.argRef(argv, 3 + val_idx);
            val_idx += 1;
            if (!packOneValue(it.code, parsed.endian, tmp[out_idx .. out_idx + sz], value_ref)) return false;
            out_idx += sz;
        }
    }

    var i: usize = 0;
    while (i < tmp.len) : (i += 1) {
        c.py_newint(c.py_r0(), @intCast(tmp[i]));
        c.py_newint(c.py_r1(), @intCast(offset + i));
        if (!c.py_setitem(buffer, c.py_r1(), c.py_r0())) return false;
    }

    c.py_newnone(c.py_retval());
    return true;
}

fn unpack_from(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2 and argc != 3) return c.py_exception(c.tp_TypeError, "unpack_from() takes 2 or 3 arguments");
    const fmt_c = c.py_tostr(pk.argRef(argv, 0)) orelse return c.py_exception(c.tp_TypeError, "format must be a string");
    const fmt = std.mem.span(fmt_c);
    const data_obj = pk.argRef(argv, 1);
    var offset: usize = 0;
    if (argc == 3) {
        const off_val = c.py_toint(pk.argRef(argv, 2));
        if (off_val < 0) return raiseStructError("offset must be >= 0");
        offset = @intCast(off_val);
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch {
        return raiseStructError("unsupported format");
    };

    var size: c_int = 0;
    const data_ptr = c.py_tobytes(data_obj, &size);
    if (data_ptr == null) return c.py_exception(c.tp_TypeError, "data must be bytes");
    const data_len: usize = @intCast(size);
    if (offset + parsed.size > data_len) return raiseStructError("buffer too small");
    const data = @as([*]const u8, @ptrCast(data_ptr))[offset .. offset + parsed.size];

    _ = c.py_newtuple(c.py_r0(), @intCast(parsed.value_count));
    const tup = c.py_r0();
    var tup_idx: c_int = 0;
    var in_idx: usize = 0;
    for (parsed.items) |it| {
        var n: usize = 0;
        while (n < it.count) : (n += 1) {
            const sz = codeSize(it.code);
            if (it.code == .x) {
                in_idx += sz;
                continue;
            }
            if (!unpackOneValue(it.code, parsed.endian, data[in_idx .. in_idx + sz])) return false;
            c.py_tuple_setitem(tup, tup_idx, c.py_retval());
            tup_idx += 1;
            in_idx += sz;
        }
    }
    pk.setRetval(tup);
    return true;
}

fn struct_new(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // __new__(cls, fmt)
    if (argc != 2) return c.py_exception(c.tp_TypeError, "Struct() requires a format string");
    _ = pk.argRef(argv, 0);
    _ = c.py_newobject(c.py_retval(), tp_struct, -1, 0);
    const self = c.py_retval();
    const fmt_c = c.py_tostr(pk.argRef(argv, 1)) orelse return c.py_exception(c.tp_TypeError, "format must be a string");
    const fmt = std.mem.span(fmt_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch {
        return raiseStructError("unsupported format");
    };

    c.py_newstr(c.py_r0(), fmt_c);
    c.py_setdict(self, c.py_name("format"), c.py_r0());
    c.py_newint(c.py_r0(), @intCast(parsed.size));
    c.py_setdict(self, c.py_name("size"), c.py_r0());
    return true;
}

fn struct_pack(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "pack() missing arguments");
    const self = pk.argRef(argv, 0);
    const fmt_val = c.py_getdict(self, c.py_name("format")) orelse return c.py_exception(c.tp_RuntimeError, "format missing");
    const fmt_c = c.py_tostr(fmt_val.?) orelse return c.py_exception(c.tp_RuntimeError, "format missing");

    const fmt = std.mem.span(fmt_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch return raiseStructError("unsupported format");
    var values_tuple: ?c.py_Ref = null;
    var provided_values: usize = 0;
    if (argc == 2 and c.py_istuple(pk.argRef(argv, 1))) {
        values_tuple = pk.argRef(argv, 1);
        provided_values = @intCast(c.py_tuple_len(values_tuple.?));
    } else {
        provided_values = if (argc > 1) @intCast(argc - 1) else 0;
    }
    if (provided_values != parsed.value_count) return raiseStructError("pack expected a different number of items");

    const buf_ptr = c.py_newbytes(c.py_retval(), @intCast(parsed.size));
    const out = @as([*]u8, @ptrCast(buf_ptr))[0..parsed.size];
    var out_idx: usize = 0;
    var val_idx: usize = 0;
    for (parsed.items) |it| {
        var n: usize = 0;
        while (n < it.count) : (n += 1) {
            if (it.code == .x) {
                out[out_idx] = 0;
                out_idx += 1;
                continue;
            }
            const value_ref = if (values_tuple) |t| c.py_tuple_getitem(t, @intCast(val_idx)) else pk.argRef(argv, 1 + val_idx);
            val_idx += 1;
            const sz = codeSize(it.code);
            if (!packOneValue(it.code, parsed.endian, out[out_idx .. out_idx + sz], value_ref)) return false;
            out_idx += sz;
        }
    }
    return true;
}

fn struct_unpack(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "unpack() takes exactly 1 argument");
    const self = pk.argRef(argv, 0);
    const fmt_val = c.py_getdict(self, c.py_name("format")) orelse return c.py_exception(c.tp_RuntimeError, "format missing");
    const fmt_c = c.py_tostr(fmt_val.?) orelse return c.py_exception(c.tp_RuntimeError, "format missing");
    const fmt = std.mem.span(fmt_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch return raiseStructError("unsupported format");

    var size: c_int = 0;
    const data_ptr = c.py_tobytes(pk.argRef(argv, 1), &size);
    if (data_ptr == null) return c.py_exception(c.tp_TypeError, "data must be bytes");
    if (@as(usize, @intCast(size)) != parsed.size) return raiseStructError("unpack requires a buffer of the correct size");
    const data = @as([*]const u8, @ptrCast(data_ptr))[0..parsed.size];

    _ = c.py_newtuple(c.py_r0(), @intCast(parsed.value_count));
    const tup = c.py_r0();
    var tup_idx: c_int = 0;
    var in_idx: usize = 0;
    for (parsed.items) |it| {
        var n: usize = 0;
        while (n < it.count) : (n += 1) {
            const sz = codeSize(it.code);
            if (it.code == .x) {
                in_idx += sz;
                continue;
            }
            if (!unpackOneValue(it.code, parsed.endian, data[in_idx .. in_idx + sz])) return false;
            c.py_tuple_setitem(tup, tup_idx, c.py_retval());
            tup_idx += 1;
            in_idx += sz;
        }
    }
    pk.setRetval(tup);
    return true;
}

fn struct_pack_into(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 3) return c.py_exception(c.tp_TypeError, "pack_into() requires buffer, offset, values");
    const self = pk.argRef(argv, 0);
    const fmt_val = c.py_getdict(self, c.py_name("format")) orelse return c.py_exception(c.tp_RuntimeError, "format missing");
    const fmt_c = c.py_tostr(fmt_val.?) orelse return c.py_exception(c.tp_RuntimeError, "format missing");
    const fmt = std.mem.span(fmt_c);

    // Build a temporary call to module-level pack_into by reusing its implementation.
    // Here: buffer is argv[1], offset argv[2], values argv[3..]
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch return raiseStructError("unsupported format");

    const buffer = pk.argRef(argv, 1);
    const offset_val = c.py_toint(pk.argRef(argv, 2));
    if (offset_val < 0) return raiseStructError("offset must be >= 0");
    const offset: usize = @intCast(offset_val);

    var values_tuple: ?c.py_Ref = null;
    var provided_values: usize = 0;
    if (argc == 4 and c.py_istuple(pk.argRef(argv, 3))) {
        values_tuple = pk.argRef(argv, 3);
        provided_values = @intCast(c.py_tuple_len(values_tuple.?));
    } else {
        provided_values = if (argc > 3) @intCast(argc - 3) else 0;
    }
    if (provided_values != parsed.value_count) return raiseStructError("pack_into expected a different number of items");

    if (!c.py_len(buffer)) return false;
    const buf_len = @as(usize, @intCast(c.py_toint(c.py_retval())));
    if (offset + parsed.size > buf_len) return raiseStructError("buffer too small");

    const tmp = std.heap.page_allocator.alloc(u8, parsed.size) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    defer std.heap.page_allocator.free(tmp);
    @memset(tmp, 0);

    var out_idx: usize = 0;
    var val_idx: usize = 0;
    for (parsed.items) |it| {
        var n: usize = 0;
        while (n < it.count) : (n += 1) {
            const sz = codeSize(it.code);
            if (it.code == .x) {
                tmp[out_idx] = 0;
                out_idx += 1;
                continue;
            }
            const value_ref = if (values_tuple) |t| c.py_tuple_getitem(t, @intCast(val_idx)) else pk.argRef(argv, 3 + val_idx);
            val_idx += 1;
            if (!packOneValue(it.code, parsed.endian, tmp[out_idx .. out_idx + sz], value_ref)) return false;
            out_idx += sz;
        }
    }

    var i: usize = 0;
    while (i < tmp.len) : (i += 1) {
        c.py_newint(c.py_r0(), @intCast(tmp[i]));
        c.py_newint(c.py_r1(), @intCast(offset + i));
        if (!c.py_setitem(buffer, c.py_r1(), c.py_r0())) return false;
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn struct_unpack_from(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2 and argc != 3) return c.py_exception(c.tp_TypeError, "unpack_from() takes 1 or 2 arguments");
    const self = pk.argRef(argv, 0);
    const fmt_val = c.py_getdict(self, c.py_name("format")) orelse return c.py_exception(c.tp_RuntimeError, "format missing");
    const fmt_c = c.py_tostr(fmt_val.?) orelse return c.py_exception(c.tp_RuntimeError, "format missing");
    const fmt = std.mem.span(fmt_c);
    const data_obj = pk.argRef(argv, 1);
    var offset: usize = 0;
    if (argc == 3) {
        const off_val = c.py_toint(pk.argRef(argv, 2));
        if (off_val < 0) return raiseStructError("offset must be >= 0");
        offset = @intCast(off_val);
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseFormat(arena.allocator(), fmt) catch return raiseStructError("unsupported format");

    var size: c_int = 0;
    const data_ptr = c.py_tobytes(data_obj, &size);
    if (data_ptr == null) return c.py_exception(c.tp_TypeError, "data must be bytes");
    const data_len: usize = @intCast(size);
    if (offset + parsed.size > data_len) return raiseStructError("buffer too small");
    const data = @as([*]const u8, @ptrCast(data_ptr))[offset .. offset + parsed.size];

    _ = c.py_newtuple(c.py_r0(), @intCast(parsed.value_count));
    const tup = c.py_r0();
    var tup_idx: c_int = 0;
    var in_idx: usize = 0;
    for (parsed.items) |it| {
        var n: usize = 0;
        while (n < it.count) : (n += 1) {
            const sz = codeSize(it.code);
            if (it.code == .x) {
                in_idx += sz;
                continue;
            }
            if (!unpackOneValue(it.code, parsed.endian, data[in_idx .. in_idx + sz])) return false;
            c.py_tuple_setitem(tup, tup_idx, c.py_retval());
            tup_idx += 1;
            in_idx += sz;
        }
    }
    pk.setRetval(tup);
    return true;
}

pub fn register() void {
    const name: [:0]const u8 = "struct";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);

    // Provide a minimal `bytearray` builtin (used by struct.pack_into tests).
    if (tp_bytearray == 0) {
        const builtins = c.py_getmodule("builtins") orelse c.py_newmodule("builtins");
        tp_bytearray = c.py_newtype("bytearray", c.tp_object, builtins, bytearrayDtor);
        c.py_bind(c.py_tpobject(tp_bytearray), "__new__(cls, source=None)", bytearrayNew);
        c.py_bind(c.py_tpobject(tp_bytearray), "__len__(self)", bytearrayLen);
        c.py_bind(c.py_tpobject(tp_bytearray), "__getitem__(self, key)", bytearrayGetItem);
        c.py_bind(c.py_tpobject(tp_bytearray), "__setitem__(self, key, value)", bytearraySetItem);
        c.py_bind(c.py_tpobject(tp_bytearray), "__eq__(self, other)", bytearrayEq);
        c.py_bind(c.py_tpobject(tp_bytearray), "__repr__(self)", bytearrayRepr);
        c.py_setdict(builtins, c.py_name("bytearray"), c.py_tpobject(tp_bytearray));
    }

    tp_error = c.py_newtype("error", c.tp_Exception, module, null);
    c.py_setdict(module, c.py_name("error"), c.py_tpobject(tp_error));

    tp_struct = c.py_newtype("Struct", c.tp_object, module, null);
    c.py_bind(c.py_tpobject(tp_struct), "__new__(cls, fmt)", struct_new);
    c.py_bindmethod(tp_struct, "pack", struct_pack);
    c.py_bindmethod(tp_struct, "unpack", struct_unpack);
    c.py_bindmethod(tp_struct, "pack_into", struct_pack_into);
    c.py_bindmethod(tp_struct, "unpack_from", struct_unpack_from);
    c.py_setdict(module, c.py_name("Struct"), c.py_tpobject(tp_struct));

    c.py_bind(module, "pack(fmt, *values)", pack);
    c.py_bind(module, "unpack(fmt, data)", unpack);
    c.py_bind(module, "calcsize(fmt)", calcsize);
    c.py_bind(module, "pack_into(fmt, buffer, offset, *values)", pack_into);
    c.py_bind(module, "unpack_from(fmt, data, offset=0)", unpack_from);
}
