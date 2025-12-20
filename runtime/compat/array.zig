/// array.zig - Python array module implementation
///
/// Provides efficient arrays of basic value types.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_array: c.py_Type = 0;

const TypeCode = enum(u8) {
    b = 'b', // signed char (1 byte)
    B = 'B', // unsigned char (1 byte)
    h = 'h', // signed short (2 bytes)
    H = 'H', // unsigned short (2 bytes)
    i = 'i', // signed int (4 bytes)
    I = 'I', // unsigned int (4 bytes)
    l = 'l', // signed long (4 bytes on most systems, we use 8)
    L = 'L', // unsigned long (4 bytes on most systems, we use 8)
    q = 'q', // signed long long (8 bytes)
    Q = 'Q', // unsigned long long (8 bytes)
    f = 'f', // float (4 bytes)
    d = 'd', // double (8 bytes)
};

fn typeCodeFromChar(ch: u8) ?TypeCode {
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
        else => null,
    };
}

fn itemSize(tc: TypeCode) usize {
    return switch (tc) {
        .b, .B => 1,
        .h, .H => 2,
        .i, .I => 4,
        .l, .L, .q, .Q, .d => 8,
        .f => 4,
    };
}

const ArrayState = struct {
    typecode: TypeCode,
    ptr: ?[*]u8 = null,
    len: usize = 0,
    cap: usize = 0,

    fn itemsize(self: *const ArrayState) usize {
        return itemSize(self.typecode);
    }

    fn ensureCap(self: *ArrayState, new_len: usize) !void {
        if (new_len <= self.cap) return;
        const new_cap = @max(new_len, self.cap * 2, 8);
        const size = new_cap * self.itemsize();
        if (self.ptr) |p| {
            const old_size = self.cap * self.itemsize();
            const new_mem = std.heap.page_allocator.realloc(p[0..old_size], size) catch return error.OutOfMemory;
            self.ptr = new_mem.ptr;
            self.cap = new_cap;
        } else {
            const mem = std.heap.page_allocator.alloc(u8, size) catch return error.OutOfMemory;
            self.ptr = mem.ptr;
            self.cap = new_cap;
        }
    }

    fn getInt(self: *const ArrayState, idx: usize) i64 {
        const isize_val = self.itemsize();
        const offset = idx * isize_val;
        const data = self.ptr.?[offset .. offset + isize_val];
        return switch (self.typecode) {
            .b => @as(i64, @as(*const i8, @ptrCast(@alignCast(data.ptr))).*),
            .B => @as(i64, data[0]),
            .h => @as(i64, std.mem.readInt(i16, data[0..2], .little)),
            .H => @as(i64, std.mem.readInt(u16, data[0..2], .little)),
            .i => @as(i64, std.mem.readInt(i32, data[0..4], .little)),
            .I => @as(i64, std.mem.readInt(u32, data[0..4], .little)),
            .l, .q => std.mem.readInt(i64, data[0..8], .little),
            .L, .Q => @bitCast(std.mem.readInt(u64, data[0..8], .little)),
            .f, .d => 0, // Not an int type
        };
    }

    fn getFloat(self: *const ArrayState, idx: usize) f64 {
        const isize_val = self.itemsize();
        const offset = idx * isize_val;
        const data = self.ptr.?[offset .. offset + isize_val];
        return switch (self.typecode) {
            .f => @as(f64, @as(*const f32, @ptrCast(@alignCast(data.ptr))).*),
            .d => @as(*const f64, @ptrCast(@alignCast(data.ptr))).*,
            else => 0, // Not a float type
        };
    }

    fn setInt(self: *ArrayState, idx: usize, val: i64) void {
        const isize_val = self.itemsize();
        const offset = idx * isize_val;
        const data = self.ptr.?[offset .. offset + isize_val];
        switch (self.typecode) {
            .b => @as(*i8, @ptrCast(@alignCast(data.ptr))).* = @truncate(val),
            .B => data[0] = @truncate(@as(u64, @bitCast(val))),
            .h => std.mem.writeInt(i16, data[0..2], @truncate(val), .little),
            .H => std.mem.writeInt(u16, data[0..2], @truncate(@as(u64, @bitCast(val))), .little),
            .i => std.mem.writeInt(i32, data[0..4], @truncate(val), .little),
            .I => std.mem.writeInt(u32, data[0..4], @truncate(@as(u64, @bitCast(val))), .little),
            .l, .q => std.mem.writeInt(i64, data[0..8], val, .little),
            .L, .Q => std.mem.writeInt(u64, data[0..8], @bitCast(val), .little),
            .f, .d => {},
        }
    }

    fn setFloat(self: *ArrayState, idx: usize, val: f64) void {
        const isize_val = self.itemsize();
        const offset = idx * isize_val;
        const data = self.ptr.?[offset .. offset + isize_val];
        switch (self.typecode) {
            .f => @as(*f32, @ptrCast(@alignCast(data.ptr))).* = @floatCast(val),
            .d => @as(*f64, @ptrCast(@alignCast(data.ptr))).* = val,
            else => {},
        }
    }

    fn isFloatType(self: *const ArrayState) bool {
        return self.typecode == .f or self.typecode == .d;
    }
};

fn arrayDtor(ud: ?*anyopaque) callconv(.c) void {
    if (ud == null) return;
    const state: *ArrayState = @ptrCast(@alignCast(ud.?));
    if (state.ptr) |p| {
        const size = state.cap * state.itemsize();
        std.heap.page_allocator.free(p[0..size]);
    }
}

fn arrayNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // array(typecode, initializer=None)
    if (argc < 2 or argc > 3) return c.py_exception(c.tp_TypeError, "array() takes 1 or 2 arguments");

    const typecode_arg = pk.argRef(argv, 1);
    if (!c.py_isstr(typecode_arg)) return c.py_exception(c.tp_TypeError, "typecode must be a string");

    const sv = c.py_tosv(typecode_arg);
    if (sv.size != 1) return c.py_exception(c.tp_ValueError, "typecode must be a single character");

    const tc_char = @as([*]const u8, @ptrCast(sv.data))[0];
    const tc = typeCodeFromChar(tc_char) orelse return c.py_exception(c.tp_ValueError, "bad typecode");

    const ud = c.py_newobject(c.py_retval(), tp_array, -1, @sizeOf(ArrayState));
    const state: *ArrayState = @ptrCast(@alignCast(ud));
    state.* = .{ .typecode = tc };

    // Handle initializer if provided
    if (argc == 3) {
        const init_arg = pk.argRef(argv, 2);

        // None means no initializer
        if (c.py_isnone(init_arg)) {
            return true;
        }

        // Handle list/tuple initializer
        if (c.py_istype(init_arg, c.tp_list)) {
            const list_len = c.py_list_len(init_arg);
            if (list_len < 0) return c.py_exception(c.tp_RuntimeError, "invalid list");
            const len: usize = @intCast(list_len);

            state.ensureCap(len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

            var i: c_int = 0;
            while (i < list_len) : (i += 1) {
                const item = c.py_list_getitem(init_arg, i);
                if (state.isFloatType()) {
                    if (c.py_isfloat(item)) {
                        state.setFloat(@intCast(i), c.py_tofloat(item));
                    } else if (c.py_isint(item)) {
                        state.setFloat(@intCast(i), @floatFromInt(c.py_toint(item)));
                    } else {
                        return c.py_exception(c.tp_TypeError, "must be a real number");
                    }
                } else {
                    if (!c.py_isint(item)) return c.py_exception(c.tp_TypeError, "an integer is required");
                    state.setInt(@intCast(i), c.py_toint(item));
                }
            }
            state.len = len;
            return true;
        }

        if (c.py_istype(init_arg, c.tp_tuple)) {
            const tuple_len = c.py_tuple_len(init_arg);
            if (tuple_len < 0) return c.py_exception(c.tp_RuntimeError, "invalid tuple");
            const len: usize = @intCast(tuple_len);

            state.ensureCap(len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

            var i: c_int = 0;
            while (i < tuple_len) : (i += 1) {
                const item = c.py_tuple_getitem(init_arg, i);
                if (state.isFloatType()) {
                    if (c.py_isfloat(item)) {
                        state.setFloat(@intCast(i), c.py_tofloat(item));
                    } else if (c.py_isint(item)) {
                        state.setFloat(@intCast(i), @floatFromInt(c.py_toint(item)));
                    } else {
                        return c.py_exception(c.tp_TypeError, "must be a real number");
                    }
                } else {
                    if (!c.py_isint(item)) return c.py_exception(c.tp_TypeError, "an integer is required");
                    state.setInt(@intCast(i), c.py_toint(item));
                }
            }
            state.len = len;
            return true;
        }

        // Handle bytes initializer for byte arrays
        if (c.py_istype(init_arg, c.tp_bytes) and (tc == .b or tc == .B)) {
            var bytes_len: c_int = 0;
            const bytes_ptr = c.py_tobytes(init_arg, &bytes_len);
            const len: usize = @intCast(bytes_len);

            state.ensureCap(len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            if (len > 0) {
                @memcpy(state.ptr.?[0..len], bytes_ptr[0..len]);
            }
            state.len = len;
            return true;
        }

        return c.py_exception(c.tp_TypeError, "cannot convert to array");
    }

    return true;
}

fn arrayLen(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__len__ takes no arguments");
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(pk.argRef(argv, 0))));
    c.py_newint(c.py_retval(), @intCast(state.len));
    return true;
}

fn arrayGetItem(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "__getitem__ takes 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const key = pk.argRef(argv, 1);

    // Handle integer index
    if (c.py_isint(key)) {
        var idx: i64 = c.py_toint(key);
        if (idx < 0) idx += @intCast(state.len);
        if (idx < 0 or idx >= @as(i64, @intCast(state.len))) return c.py_exception(c.tp_IndexError, "array index out of range");

        if (state.isFloatType()) {
            c.py_newfloat(c.py_retval(), state.getFloat(@intCast(idx)));
        } else {
            c.py_newint(c.py_retval(), state.getInt(@intCast(idx)));
        }
        return true;
    }

    // Handle slice
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

        // Normalize negative indices
        if (start < 0) start += @intCast(state.len);
        if (stop < 0) stop += @intCast(state.len);
        if (start < 0) start = 0;
        if (stop < 0) stop = 0;
        if (start > @as(i64, @intCast(state.len))) start = @intCast(state.len);
        if (stop > @as(i64, @intCast(state.len))) stop = @intCast(state.len);
        if (stop < start) stop = start;

        const slice_start: usize = @intCast(start);
        const slice_stop: usize = @intCast(stop);
        const slice_len = slice_stop - slice_start;

        // Create a new array with the slice
        const ud = c.py_newobject(c.py_retval(), tp_array, -1, @sizeOf(ArrayState));
        const new_state: *ArrayState = @ptrCast(@alignCast(ud));
        new_state.* = .{ .typecode = state.typecode };

        if (slice_len > 0) {
            new_state.ensureCap(slice_len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            const item_size = state.itemsize();
            const src_offset = slice_start * item_size;
            const copy_size = slice_len * item_size;
            @memcpy(new_state.ptr.?[0..copy_size], state.ptr.?[src_offset .. src_offset + copy_size]);
            new_state.len = slice_len;
        }
        return true;
    }

    return c.py_exception(c.tp_TypeError, "array indices must be integers");
}

fn arraySetItem(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 3) return c.py_exception(c.tp_TypeError, "__setitem__ takes 2 arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const key = pk.argRef(argv, 1);
    const val = pk.argRef(argv, 2);

    if (!c.py_isint(key)) return c.py_exception(c.tp_TypeError, "array indices must be integers");

    var idx: i64 = c.py_toint(key);
    if (idx < 0) idx += @intCast(state.len);
    if (idx < 0 or idx >= @as(i64, @intCast(state.len))) return c.py_exception(c.tp_IndexError, "array index out of range");

    if (state.isFloatType()) {
        if (c.py_isfloat(val)) {
            state.setFloat(@intCast(idx), c.py_tofloat(val));
        } else if (c.py_isint(val)) {
            state.setFloat(@intCast(idx), @floatFromInt(c.py_toint(val)));
        } else {
            return c.py_exception(c.tp_TypeError, "must be a real number");
        }
    } else {
        if (!c.py_isint(val)) return c.py_exception(c.tp_TypeError, "an integer is required");
        state.setInt(@intCast(idx), c.py_toint(val));
    }

    c.py_newnone(c.py_retval());
    return true;
}

fn arrayAppend(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "append() takes 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const val = pk.argRef(argv, 1);

    state.ensureCap(state.len + 1) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

    if (state.isFloatType()) {
        if (c.py_isfloat(val)) {
            state.setFloat(state.len, c.py_tofloat(val));
        } else if (c.py_isint(val)) {
            state.setFloat(state.len, @floatFromInt(c.py_toint(val)));
        } else {
            return c.py_exception(c.tp_TypeError, "must be a real number");
        }
    } else {
        if (!c.py_isint(val)) return c.py_exception(c.tp_TypeError, "an integer is required");
        state.setInt(state.len, c.py_toint(val));
    }
    state.len += 1;

    c.py_newnone(c.py_retval());
    return true;
}

fn arrayExtend(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "extend() takes 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const iterable = pk.argRef(argv, 1);

    // Handle list
    if (c.py_istype(iterable, c.tp_list)) {
        const list_len = c.py_list_len(iterable);
        if (list_len < 0) return c.py_exception(c.tp_RuntimeError, "invalid list");

        state.ensureCap(state.len + @as(usize, @intCast(list_len))) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

        var i: c_int = 0;
        while (i < list_len) : (i += 1) {
            const item = c.py_list_getitem(iterable, i);
            if (state.isFloatType()) {
                if (c.py_isfloat(item)) {
                    state.setFloat(state.len, c.py_tofloat(item));
                } else if (c.py_isint(item)) {
                    state.setFloat(state.len, @floatFromInt(c.py_toint(item)));
                } else {
                    return c.py_exception(c.tp_TypeError, "must be a real number");
                }
            } else {
                if (!c.py_isint(item)) return c.py_exception(c.tp_TypeError, "an integer is required");
                state.setInt(state.len, c.py_toint(item));
            }
            state.len += 1;
        }
        c.py_newnone(c.py_retval());
        return true;
    }

    // Handle tuple
    if (c.py_istype(iterable, c.tp_tuple)) {
        const tuple_len = c.py_tuple_len(iterable);
        if (tuple_len < 0) return c.py_exception(c.tp_RuntimeError, "invalid tuple");

        state.ensureCap(state.len + @as(usize, @intCast(tuple_len))) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

        var i: c_int = 0;
        while (i < tuple_len) : (i += 1) {
            const item = c.py_tuple_getitem(iterable, i);
            if (state.isFloatType()) {
                if (c.py_isfloat(item)) {
                    state.setFloat(state.len, c.py_tofloat(item));
                } else if (c.py_isint(item)) {
                    state.setFloat(state.len, @floatFromInt(c.py_toint(item)));
                } else {
                    return c.py_exception(c.tp_TypeError, "must be a real number");
                }
            } else {
                if (!c.py_isint(item)) return c.py_exception(c.tp_TypeError, "an integer is required");
                state.setInt(state.len, c.py_toint(item));
            }
            state.len += 1;
        }
        c.py_newnone(c.py_retval());
        return true;
    }

    // Handle another array
    if (c.py_istype(iterable, tp_array)) {
        const other: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(iterable)));
        if (other.typecode != state.typecode) return c.py_exception(c.tp_TypeError, "can only extend with array of same type");

        state.ensureCap(state.len + other.len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

        const item_size = state.itemsize();
        const src_offset: usize = 0;
        const dst_offset = state.len * item_size;
        const copy_size = other.len * item_size;

        if (copy_size > 0) {
            @memcpy(state.ptr.?[dst_offset .. dst_offset + copy_size], other.ptr.?[src_offset .. src_offset + copy_size]);
        }
        state.len += other.len;
        c.py_newnone(c.py_retval());
        return true;
    }

    return c.py_exception(c.tp_TypeError, "extend() argument must be iterable");
}

fn arrayPop(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc > 2) return c.py_exception(c.tp_TypeError, "pop() takes at most 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    if (state.len == 0) return c.py_exception(c.tp_IndexError, "pop from empty array");

    var idx: i64 = -1;
    if (argc == 2) {
        const idx_arg = pk.argRef(argv, 1);
        if (!c.py_isint(idx_arg)) return c.py_exception(c.tp_TypeError, "index must be an integer");
        idx = c.py_toint(idx_arg);
    }

    if (idx < 0) idx += @intCast(state.len);
    if (idx < 0 or idx >= @as(i64, @intCast(state.len))) return c.py_exception(c.tp_IndexError, "pop index out of range");

    const uidx: usize = @intCast(idx);

    // Get the value before removing
    if (state.isFloatType()) {
        c.py_newfloat(c.py_retval(), state.getFloat(uidx));
    } else {
        c.py_newint(c.py_retval(), state.getInt(uidx));
    }

    // Shift elements after idx
    if (uidx < state.len - 1) {
        const item_size = state.itemsize();
        const src_offset = (uidx + 1) * item_size;
        const dst_offset = uidx * item_size;
        const move_size = (state.len - uidx - 1) * item_size;
        std.mem.copyForwards(u8, state.ptr.?[dst_offset .. dst_offset + move_size], state.ptr.?[src_offset .. src_offset + move_size]);
    }
    state.len -= 1;

    return true;
}

fn arrayInsert(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 3) return c.py_exception(c.tp_TypeError, "insert() takes 2 arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const idx_arg = pk.argRef(argv, 1);
    const val = pk.argRef(argv, 2);

    if (!c.py_isint(idx_arg)) return c.py_exception(c.tp_TypeError, "index must be an integer");
    var idx: i64 = c.py_toint(idx_arg);

    if (idx < 0) idx += @intCast(state.len);
    if (idx < 0) idx = 0;
    if (idx > @as(i64, @intCast(state.len))) idx = @intCast(state.len);

    const uidx: usize = @intCast(idx);

    state.ensureCap(state.len + 1) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

    // Shift elements after idx
    if (uidx < state.len) {
        const item_size = state.itemsize();
        const src_offset = uidx * item_size;
        const dst_offset = (uidx + 1) * item_size;
        const move_size = (state.len - uidx) * item_size;
        std.mem.copyBackwards(u8, state.ptr.?[dst_offset .. dst_offset + move_size], state.ptr.?[src_offset .. src_offset + move_size]);
    }

    // Set the new value
    if (state.isFloatType()) {
        if (c.py_isfloat(val)) {
            state.setFloat(uidx, c.py_tofloat(val));
        } else if (c.py_isint(val)) {
            state.setFloat(uidx, @floatFromInt(c.py_toint(val)));
        } else {
            return c.py_exception(c.tp_TypeError, "must be a real number");
        }
    } else {
        if (!c.py_isint(val)) return c.py_exception(c.tp_TypeError, "an integer is required");
        state.setInt(uidx, c.py_toint(val));
    }
    state.len += 1;

    c.py_newnone(c.py_retval());
    return true;
}

fn arrayRemove(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "remove() takes 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const val = pk.argRef(argv, 1);

    // Find the value
    var found_idx: ?usize = null;
    if (state.isFloatType()) {
        if (!c.py_isfloat(val) and !c.py_isint(val)) return c.py_exception(c.tp_ValueError, "array.remove(x): x not in array");
        const target = if (c.py_isfloat(val)) c.py_tofloat(val) else @as(f64, @floatFromInt(c.py_toint(val)));
        for (0..state.len) |i| {
            if (state.getFloat(i) == target) {
                found_idx = i;
                break;
            }
        }
    } else {
        if (!c.py_isint(val)) return c.py_exception(c.tp_ValueError, "array.remove(x): x not in array");
        const target = c.py_toint(val);
        for (0..state.len) |i| {
            if (state.getInt(i) == target) {
                found_idx = i;
                break;
            }
        }
    }

    if (found_idx == null) return c.py_exception(c.tp_ValueError, "array.remove(x): x not in array");

    const uidx = found_idx.?;

    // Shift elements after idx
    if (uidx < state.len - 1) {
        const item_size = state.itemsize();
        const src_offset = (uidx + 1) * item_size;
        const dst_offset = uidx * item_size;
        const move_size = (state.len - uidx - 1) * item_size;
        std.mem.copyForwards(u8, state.ptr.?[dst_offset .. dst_offset + move_size], state.ptr.?[src_offset .. src_offset + move_size]);
    }
    state.len -= 1;

    c.py_newnone(c.py_retval());
    return true;
}

fn arrayIndex(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2 or argc > 4) return c.py_exception(c.tp_TypeError, "index() takes 1 to 3 arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const val = pk.argRef(argv, 1);

    var start: usize = 0;
    var stop: usize = state.len;

    if (argc >= 3) {
        const start_arg = pk.argRef(argv, 2);
        if (!c.py_isnone(start_arg)) {
            if (!c.py_isint(start_arg)) return c.py_exception(c.tp_TypeError, "slice indices must be integers");
            var s: i64 = c.py_toint(start_arg);
            if (s < 0) s += @intCast(state.len);
            if (s < 0) s = 0;
            if (s > @as(i64, @intCast(state.len))) s = @intCast(state.len);
            start = @intCast(s);
        }
    }

    if (argc >= 4) {
        const stop_arg = pk.argRef(argv, 3);
        if (!c.py_isnone(stop_arg)) {
            if (!c.py_isint(stop_arg)) return c.py_exception(c.tp_TypeError, "slice indices must be integers");
            var s: i64 = c.py_toint(stop_arg);
            if (s < 0) s += @intCast(state.len);
            if (s < 0) s = 0;
            if (s > @as(i64, @intCast(state.len))) s = @intCast(state.len);
            stop = @intCast(s);
        }
    }

    // Find the value
    if (state.isFloatType()) {
        if (!c.py_isfloat(val) and !c.py_isint(val)) return c.py_exception(c.tp_ValueError, "array.index(x): x not in array");
        const target = if (c.py_isfloat(val)) c.py_tofloat(val) else @as(f64, @floatFromInt(c.py_toint(val)));
        for (start..stop) |i| {
            if (state.getFloat(i) == target) {
                c.py_newint(c.py_retval(), @intCast(i));
                return true;
            }
        }
    } else {
        if (!c.py_isint(val)) return c.py_exception(c.tp_ValueError, "array.index(x): x not in array");
        const target = c.py_toint(val);
        for (start..stop) |i| {
            if (state.getInt(i) == target) {
                c.py_newint(c.py_retval(), @intCast(i));
                return true;
            }
        }
    }

    return c.py_exception(c.tp_ValueError, "array.index(x): x not in array");
}

fn arrayCount(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "count() takes 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const val = pk.argRef(argv, 1);

    var count: i64 = 0;

    if (state.isFloatType()) {
        if (c.py_isfloat(val) or c.py_isint(val)) {
            const target = if (c.py_isfloat(val)) c.py_tofloat(val) else @as(f64, @floatFromInt(c.py_toint(val)));
            for (0..state.len) |i| {
                if (state.getFloat(i) == target) count += 1;
            }
        }
    } else {
        if (c.py_isint(val)) {
            const target = c.py_toint(val);
            for (0..state.len) |i| {
                if (state.getInt(i) == target) count += 1;
            }
        }
    }

    c.py_newint(c.py_retval(), count);
    return true;
}

fn arrayReverse(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "reverse() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    if (state.len <= 1) {
        c.py_newnone(c.py_retval());
        return true;
    }

    const item_size = state.itemsize();
    var temp: [8]u8 = undefined;

    var i: usize = 0;
    var j: usize = state.len - 1;
    while (i < j) {
        const i_offset = i * item_size;
        const j_offset = j * item_size;

        @memcpy(temp[0..item_size], state.ptr.?[i_offset .. i_offset + item_size]);
        @memcpy(state.ptr.?[i_offset .. i_offset + item_size], state.ptr.?[j_offset .. j_offset + item_size]);
        @memcpy(state.ptr.?[j_offset .. j_offset + item_size], temp[0..item_size]);

        i += 1;
        j -= 1;
    }

    c.py_newnone(c.py_retval());
    return true;
}

fn arrayTolist(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "tolist() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    c.py_newlist(c.py_retval());

    for (0..state.len) |i| {
        var item: c.py_TValue = undefined;
        if (state.isFloatType()) {
            c.py_newfloat(&item, state.getFloat(i));
        } else {
            c.py_newint(&item, state.getInt(i));
        }
        c.py_list_append(c.py_retval(), &item);
    }

    return true;
}

fn arrayTobytes(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "tobytes() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    const byte_len = state.len * state.itemsize();
    const out = c.py_newbytes(c.py_retval(), @intCast(byte_len));
    if (byte_len > 0) {
        @memcpy(out[0..byte_len], state.ptr.?[0..byte_len]);
    }

    return true;
}

fn arrayFrombytes(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "frombytes() takes 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const bytes_arg = pk.argRef(argv, 1);

    if (!c.py_istype(bytes_arg, c.tp_bytes)) return c.py_exception(c.tp_TypeError, "a bytes-like object is required");

    var bytes_len: c_int = 0;
    const bytes_ptr = c.py_tobytes(bytes_arg, &bytes_len);
    const len: usize = @intCast(bytes_len);

    const item_size = state.itemsize();
    if (len % item_size != 0) return c.py_exception(c.tp_ValueError, "bytes length not a multiple of item size");

    const count = len / item_size;
    state.ensureCap(state.len + count) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

    const dst_offset = state.len * item_size;
    @memcpy(state.ptr.?[dst_offset .. dst_offset + len], bytes_ptr[0..len]);
    state.len += count;

    c.py_newnone(c.py_retval());
    return true;
}

fn arrayTypecode(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "typecode takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    const out = c.py_newstrn(c.py_retval(), 1);
    out[0] = @intFromEnum(state.typecode);

    return true;
}

fn arrayItemsize(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "itemsize takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    c.py_newint(c.py_retval(), @intCast(state.itemsize()));
    return true;
}

fn arrayRepr(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__repr__ takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    writer.print("array('{c}'", .{@intFromEnum(state.typecode)}) catch return c.py_exception(c.tp_RuntimeError, "repr too long");

    if (state.len > 0) {
        writer.writeAll(", [") catch return c.py_exception(c.tp_RuntimeError, "repr too long");
        for (0..state.len) |i| {
            if (i > 0) writer.writeAll(", ") catch return c.py_exception(c.tp_RuntimeError, "repr too long");
            if (state.isFloatType()) {
                writer.print("{d}", .{state.getFloat(i)}) catch return c.py_exception(c.tp_RuntimeError, "repr too long");
            } else {
                writer.print("{d}", .{state.getInt(i)}) catch return c.py_exception(c.tp_RuntimeError, "repr too long");
            }
        }
        writer.writeAll("]") catch return c.py_exception(c.tp_RuntimeError, "repr too long");
    }

    writer.writeAll(")") catch return c.py_exception(c.tp_RuntimeError, "repr too long");

    const written = fbs.getWritten();
    const out = c.py_newstrn(c.py_retval(), @intCast(written.len));
    @memcpy(out[0..written.len], written);
    return true;
}

fn arrayEq(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "__eq__ takes 1 argument");
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    const self_state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    if (!c.py_istype(other, tp_array)) {
        c.py_newnotimplemented(c.py_retval());
        return true;
    }

    const other_state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(other)));

    if (self_state.typecode != other_state.typecode or self_state.len != other_state.len) {
        c.py_newbool(c.py_retval(), false);
        return true;
    }

    if (self_state.len == 0) {
        c.py_newbool(c.py_retval(), true);
        return true;
    }

    const byte_len = self_state.len * self_state.itemsize();
    const equal = std.mem.eql(u8, self_state.ptr.?[0..byte_len], other_state.ptr.?[0..byte_len]);
    c.py_newbool(c.py_retval(), equal);
    return true;
}

fn arrayAdd(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "__add__ takes 1 argument");
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    const self_state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    if (!c.py_istype(other, tp_array)) {
        return c.py_exception(c.tp_TypeError, "can only concatenate array to array");
    }

    const other_state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(other)));
    if (self_state.typecode != other_state.typecode) {
        return c.py_exception(c.tp_TypeError, "bad argument type for built-in operation");
    }

    // Create new array
    const ud = c.py_newobject(c.py_retval(), tp_array, -1, @sizeOf(ArrayState));
    const new_state: *ArrayState = @ptrCast(@alignCast(ud));
    new_state.* = .{ .typecode = self_state.typecode };

    const new_len = self_state.len + other_state.len;
    if (new_len > 0) {
        new_state.ensureCap(new_len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        const item_size = self_state.itemsize();

        // Copy self
        if (self_state.len > 0) {
            const copy_size = self_state.len * item_size;
            @memcpy(new_state.ptr.?[0..copy_size], self_state.ptr.?[0..copy_size]);
        }

        // Copy other
        if (other_state.len > 0) {
            const offset = self_state.len * item_size;
            const copy_size = other_state.len * item_size;
            @memcpy(new_state.ptr.?[offset .. offset + copy_size], other_state.ptr.?[0..copy_size]);
        }

        new_state.len = new_len;
    }

    return true;
}

fn arrayMul(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "__mul__ takes 1 argument");
    const self = pk.argRef(argv, 0);
    const n_arg = pk.argRef(argv, 1);
    const self_state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    if (!c.py_isint(n_arg)) {
        return c.py_exception(c.tp_TypeError, "can't multiply sequence by non-int");
    }

    const n = c.py_toint(n_arg);
    if (n <= 0) {
        // Empty array
        const ud = c.py_newobject(c.py_retval(), tp_array, -1, @sizeOf(ArrayState));
        const new_state: *ArrayState = @ptrCast(@alignCast(ud));
        new_state.* = .{ .typecode = self_state.typecode };
        return true;
    }

    const repeat: usize = @intCast(n);
    const new_len = self_state.len * repeat;

    // Create new array
    const ud = c.py_newobject(c.py_retval(), tp_array, -1, @sizeOf(ArrayState));
    const new_state: *ArrayState = @ptrCast(@alignCast(ud));
    new_state.* = .{ .typecode = self_state.typecode };

    if (new_len > 0 and self_state.len > 0) {
        new_state.ensureCap(new_len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        const item_size = self_state.itemsize();
        const copy_size = self_state.len * item_size;

        for (0..repeat) |i| {
            const offset = i * copy_size;
            @memcpy(new_state.ptr.?[offset .. offset + copy_size], self_state.ptr.?[0..copy_size]);
        }

        new_state.len = new_len;
    }

    return true;
}

fn arrayContains(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "__contains__ takes 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));
    const val = pk.argRef(argv, 1);

    if (state.isFloatType()) {
        if (c.py_isfloat(val) or c.py_isint(val)) {
            const target = if (c.py_isfloat(val)) c.py_tofloat(val) else @as(f64, @floatFromInt(c.py_toint(val)));
            for (0..state.len) |i| {
                if (state.getFloat(i) == target) {
                    c.py_newbool(c.py_retval(), true);
                    return true;
                }
            }
        }
    } else {
        if (c.py_isint(val)) {
            const target = c.py_toint(val);
            for (0..state.len) |i| {
                if (state.getInt(i) == target) {
                    c.py_newbool(c.py_retval(), true);
                    return true;
                }
            }
        }
    }

    c.py_newbool(c.py_retval(), false);
    return true;
}

fn arrayIter(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__iter__ takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *ArrayState = @ptrCast(@alignCast(c.py_touserdata(self)));

    // Build a list in r0
    c.py_newlist(c.py_r0());
    for (0..state.len) |i| {
        var item: c.py_TValue = undefined;
        if (state.isFloatType()) {
            c.py_newfloat(&item, state.getFloat(i));
        } else {
            c.py_newint(&item, state.getInt(i));
        }
        c.py_list_append(c.py_r0(), &item);
    }

    // Call iter() on the list - result goes to retval
    return c.py_iter(c.py_r0());
}

pub fn register() void {
    const module = c.py_newmodule("array");

    tp_array = c.py_newtype("array", c.tp_object, module, arrayDtor);
    c.py_bind(c.py_tpobject(tp_array), "__new__(cls, typecode, initializer=None)", arrayNew);
    c.py_bind(c.py_tpobject(tp_array), "__len__(self)", arrayLen);
    c.py_bind(c.py_tpobject(tp_array), "__getitem__(self, key)", arrayGetItem);
    c.py_bind(c.py_tpobject(tp_array), "__setitem__(self, key, value)", arraySetItem);
    c.py_bind(c.py_tpobject(tp_array), "__repr__(self)", arrayRepr);
    c.py_bind(c.py_tpobject(tp_array), "__eq__(self, other)", arrayEq);
    c.py_bind(c.py_tpobject(tp_array), "__add__(self, other)", arrayAdd);
    c.py_bind(c.py_tpobject(tp_array), "__mul__(self, n)", arrayMul);
    c.py_bind(c.py_tpobject(tp_array), "__rmul__(self, n)", arrayMul);
    c.py_bind(c.py_tpobject(tp_array), "__contains__(self, x)", arrayContains);
    c.py_bind(c.py_tpobject(tp_array), "__iter__(self)", arrayIter);
    c.py_bind(c.py_tpobject(tp_array), "append(self, x)", arrayAppend);
    c.py_bind(c.py_tpobject(tp_array), "extend(self, iterable)", arrayExtend);
    c.py_bind(c.py_tpobject(tp_array), "pop(self, i=-1)", arrayPop);
    c.py_bind(c.py_tpobject(tp_array), "insert(self, i, x)", arrayInsert);
    c.py_bind(c.py_tpobject(tp_array), "remove(self, x)", arrayRemove);
    c.py_bind(c.py_tpobject(tp_array), "index(self, x, start=0, stop=None)", arrayIndex);
    c.py_bind(c.py_tpobject(tp_array), "count(self, x)", arrayCount);
    c.py_bind(c.py_tpobject(tp_array), "reverse(self)", arrayReverse);
    c.py_bind(c.py_tpobject(tp_array), "tolist(self)", arrayTolist);
    c.py_bind(c.py_tpobject(tp_array), "tobytes(self)", arrayTobytes);
    c.py_bind(c.py_tpobject(tp_array), "frombytes(self, s)", arrayFrombytes);

    // Properties as methods (PocketPy doesn't have property descriptors easily)
    c.py_bindproperty(tp_array, "typecode", arrayTypecode, null);
    c.py_bindproperty(tp_array, "itemsize", arrayItemsize, null);

    c.py_setdict(module, c.py_name("array"), c.py_tpobject(tp_array));

    // Type code string constants
    var typecodes: c.py_TValue = undefined;
    c.py_newstr(&typecodes, "bBhHiIlLqQfd");
    c.py_setdict(module, c.py_name("typecodes"), &typecodes);
}
