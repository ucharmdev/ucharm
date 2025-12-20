const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_bytesio: c.py_Type = 0;
var tp_stringio: c.py_Type = 0;

const Buffer = struct {
    ptr: ?[*]u8 = null,
    len: usize = 0,
    cap: usize = 0,
    pos: usize = 0,
    closed: bool = false,
};

fn bufferDtor(ud: ?*anyopaque) callconv(.c) void {
    if (ud == null) return;
    const state: *Buffer = @ptrCast(@alignCast(ud.?));
    if (state.ptr) |p| {
        std.heap.page_allocator.free(p[0..state.cap]);
    }
}

fn ensureCap(state: *Buffer, needed: usize) !void {
    if (needed <= state.cap) return;
    var new_cap: usize = if (state.cap == 0) 64 else state.cap * 2;
    while (new_cap < needed) : (new_cap *= 2) {}
    const new_mem = try std.heap.page_allocator.alloc(u8, new_cap);
    if (state.ptr) |p| {
        @memcpy(new_mem[0..state.len], p[0..state.len]);
        std.heap.page_allocator.free(p[0..state.cap]);
    }
    state.ptr = new_mem.ptr;
    state.cap = new_cap;
}

fn setClosedAttr(self: c.py_Ref, closed: bool) void {
    c.py_newbool(c.py_r0(), closed);
    c.py_setdict(self, c.py_name("closed"), c.py_r0());
}

fn bytesio_new(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    const ud = c.py_newobject(c.py_retval(), tp_bytesio, -1, @sizeOf(Buffer));
    const state: *Buffer = @ptrCast(@alignCast(ud));
    state.* = .{};
    setClosedAttr(c.py_retval(), false);
    return true;
}

fn bytesio_init(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "BytesIO() takes 0 or 1 arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    state.* = .{};
    setClosedAttr(self, false);

    if (argc == 2) {
        const init_val = pk.argRef(argv, 1);
        if (!c.py_isnone(init_val)) {
            var size: c_int = 0;
            const data_ptr = c.py_tobytes(init_val, &size);
            if (data_ptr == null) return c.py_exception(c.tp_TypeError, "initial value must be bytes");
            const data_len: usize = @intCast(size);
            if (data_len > 0) {
                ensureCap(state, data_len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
                const dst = state.ptr.?[0..data_len];
                const src = @as([*]const u8, @ptrCast(data_ptr))[0..data_len];
                @memcpy(dst, src);
                state.len = data_len;
            }
        }
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn bytesio_getvalue(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "getvalue() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    const buf = c.py_newbytes(c.py_retval(), @intCast(state.len));
    if (state.len > 0) {
        const dst = @as([*]u8, @ptrCast(buf))[0..state.len];
        const src = state.ptr.?[0..state.len];
        @memcpy(dst, src);
    }
    return true;
}

fn bytesio_write(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "write() takes exactly 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");

    var size: c_int = 0;
    const data_ptr = c.py_tobytes(pk.argRef(argv, 1), &size);
    if (data_ptr == null) return c.py_exception(c.tp_TypeError, "a bytes-like object is required");
    const data_len: usize = @intCast(size);
    const end_pos = state.pos + data_len;

    ensureCap(state, end_pos) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

    if (state.pos > state.len) {
        @memset(state.ptr.?[state.len..state.pos], 0);
        state.len = state.pos;
    }

    const dst = state.ptr.?[state.pos..end_pos];
    const src = @as([*]const u8, @ptrCast(data_ptr))[0..data_len];
    @memcpy(dst, src);
    state.pos = end_pos;
    if (end_pos > state.len) state.len = end_pos;

    c.py_newint(c.py_retval(), @intCast(data_len));
    return true;
}

fn bytesio_read(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "read() takes 0 or 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");

    var req: isize = -1;
    if (argc == 2) req = @intCast(c.py_toint(pk.argRef(argv, 1)));
    const available = if (state.pos <= state.len) state.len - state.pos else 0;
    const to_read: usize = if (req < 0) available else @min(available, @as(usize, @intCast(req)));

    const buf = c.py_newbytes(c.py_retval(), @intCast(to_read));
    if (to_read > 0) {
        const dst = @as([*]u8, @ptrCast(buf))[0..to_read];
        const src = state.ptr.?[state.pos .. state.pos + to_read];
        @memcpy(dst, src);
    }
    state.pos += to_read;
    return true;
}

fn bytesio_tell(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "tell() takes no arguments");
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(pk.argRef(argv, 0))));
    c.py_newint(c.py_retval(), @intCast(state.pos));
    return true;
}

fn bytesio_seek(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2 and argc != 3) return c.py_exception(c.tp_TypeError, "seek() takes 1 or 2 arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");

    const off = @as(i64, @intCast(c.py_toint(pk.argRef(argv, 1))));
    var whence: i64 = 0;
    if (argc == 3) whence = @intCast(c.py_toint(pk.argRef(argv, 2)));

    var base: i64 = 0;
    if (whence == 0) base = 0 else if (whence == 1) base = @intCast(state.pos) else if (whence == 2) base = @intCast(state.len) else return c.py_exception(c.tp_ValueError, "invalid whence");

    const new_pos_i = base + off;
    if (new_pos_i < 0) return c.py_exception(c.tp_ValueError, "negative seek position");
    state.pos = @intCast(new_pos_i);
    c.py_newint(c.py_retval(), @intCast(state.pos));
    return true;
}

fn bytesio_close(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "close() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    state.closed = true;
    setClosedAttr(self, true);
    c.py_newnone(c.py_retval());
    return true;
}

fn bytesio_enter(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__enter__() takes no arguments");
    pk.setRetval(pk.argRef(argv, 0));
    return true;
}

fn bytesio_exit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // PocketPy calls __exit__ with only `self` in `with` statements.
    if (argc != 1 and argc != 4) return c.py_exception(c.tp_TypeError, "__exit__() takes 3 arguments");
    _ = bytesio_close(1, argv);
    c.py_newbool(c.py_retval(), false);
    return true;
}

fn bytesio_readline(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "readline() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    const start = state.pos;
    if (start >= state.len) {
        _ = c.py_newbytes(c.py_retval(), 0);
        return true;
    }
    var end = start;
    while (end < state.len) : (end += 1) {
        if (state.ptr.?[end] == '\n') {
            end += 1;
            break;
        }
    }
    const to_read = end - start;
    const buf = c.py_newbytes(c.py_retval(), @intCast(to_read));
    if (to_read > 0) {
        const dst = @as([*]u8, @ptrCast(buf))[0..to_read];
        const src = state.ptr.?[start..end];
        @memcpy(dst, src);
    }
    state.pos = end;
    return true;
}

fn bytesio_readlines(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "readlines() takes 0 or 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    c.py_newlist(c.py_r0());
    const out = c.py_r0();
    while (state.pos < state.len) {
        if (!bytesio_readline(1, argv)) return false;
        c.py_r1().* = c.py_retval().*;
        c.py_list_append(out, c.py_r1());
        // bytesio_readline updated pos.
    }
    pk.setRetval(out);
    return true;
}

fn bytesio_writelines(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "writelines() takes exactly 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    if (!c.py_iter(pk.argRef(argv, 1))) return false;
    c.py_r0().* = c.py_retval().*;
    const it = c.py_r0();
    while (true) {
        const res = c.py_next(it);
        if (res == 0) break;
        if (res < 0) return false;
        c.py_r1().* = c.py_retval().*;
        const item = c.py_r1();
        var sz: c_int = 0;
        const ptr = c.py_tobytes(item, &sz);
        if (ptr == null) return c.py_exception(c.tp_TypeError, "writelines() expects bytes");
        // Reuse write by constructing a temporary argv stack is hard; inline.
        const data_len: usize = @intCast(sz);
        const end_pos = state.pos + data_len;
        ensureCap(state, end_pos) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        if (state.pos > state.len) {
            @memset(state.ptr.?[state.len..state.pos], 0);
            state.len = state.pos;
        }
        @memcpy(state.ptr.?[state.pos..end_pos], @as([*]const u8, @ptrCast(ptr))[0..data_len]);
        state.pos = end_pos;
        if (end_pos > state.len) state.len = end_pos;
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn bytesio_truncate(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "truncate() takes 0 or 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    var new_len: usize = state.pos;
    if (argc == 2) {
        const v = c.py_toint(pk.argRef(argv, 1));
        if (v < 0) return c.py_exception(c.tp_ValueError, "negative size");
        new_len = @intCast(v);
    }
    if (new_len > state.len) {
        ensureCap(state, new_len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        @memset(state.ptr.?[state.len..new_len], 0);
    }
    state.len = new_len;
    if (state.pos > state.len) state.pos = state.len;
    c.py_newint(c.py_retval(), @intCast(state.len));
    return true;
}

fn stringio_new(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    const ud = c.py_newobject(c.py_retval(), tp_stringio, -1, @sizeOf(Buffer));
    const state: *Buffer = @ptrCast(@alignCast(ud));
    state.* = .{};
    setClosedAttr(c.py_retval(), false);
    return true;
}

fn stringio_init(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "StringIO() takes 0 or 1 arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    state.* = .{};
    setClosedAttr(self, false);

    if (argc == 2) {
        const init_val = pk.argRef(argv, 1);
        if (!c.py_isnone(init_val)) {
            if (!c.py_checkstr(init_val)) return false;
            const sv = c.py_tosv(init_val);
            if (sv.data == null) return c.py_exception(c.tp_TypeError, "initial value must be a string");
            const data_len: usize = @intCast(sv.size);
            if (data_len > 0) {
                ensureCap(state, data_len) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
                @memcpy(state.ptr.?[0..data_len], @as([*]const u8, @ptrCast(sv.data))[0..data_len]);
                state.len = data_len;
            }
        }
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn stringio_getvalue(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "getvalue() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    const out = c.py_newstrn(c.py_retval(), @intCast(state.len));
    if (state.len > 0) {
        @memcpy(@as([*]u8, @ptrCast(out))[0..state.len], state.ptr.?[0..state.len]);
    }
    return true;
}

fn stringio_write(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "write() takes exactly 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    const text_val = pk.argRef(argv, 1);
    if (!c.py_checkstr(text_val)) return false;
    const sv = c.py_tosv(text_val);
    if (sv.data == null) return c.py_exception(c.tp_TypeError, "text must be a string");
    const data_len: usize = @intCast(sv.size);
    const end_pos = state.pos + data_len;
    ensureCap(state, end_pos) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    if (state.pos > state.len) {
        @memset(state.ptr.?[state.len..state.pos], 0);
        state.len = state.pos;
    }
    @memcpy(state.ptr.?[state.pos..end_pos], @as([*]const u8, @ptrCast(sv.data))[0..data_len]);
    state.pos = end_pos;
    if (end_pos > state.len) state.len = end_pos;
    c.py_newint(c.py_retval(), @intCast(data_len));
    return true;
}

fn stringio_read(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "read() takes 0 or 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    var req: isize = -1;
    if (argc == 2) req = @intCast(c.py_toint(pk.argRef(argv, 1)));
    const available = if (state.pos <= state.len) state.len - state.pos else 0;
    const to_read: usize = if (req < 0) available else @min(available, @as(usize, @intCast(req)));
    const out = c.py_newstrn(c.py_retval(), @intCast(to_read));
    if (to_read > 0) {
        @memcpy(@as([*]u8, @ptrCast(out))[0..to_read], state.ptr.?[state.pos .. state.pos + to_read]);
    }
    state.pos += to_read;
    return true;
}

fn stringio_tell(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "tell() takes no arguments");
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(pk.argRef(argv, 0))));
    c.py_newint(c.py_retval(), @intCast(state.pos));
    return true;
}

fn stringio_seek(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2 and argc != 3) return c.py_exception(c.tp_TypeError, "seek() takes 1 or 2 arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    const off = @as(i64, @intCast(c.py_toint(pk.argRef(argv, 1))));
    var whence: i64 = 0;
    if (argc == 3) whence = @intCast(c.py_toint(pk.argRef(argv, 2)));
    var base: i64 = 0;
    if (whence == 0) base = 0 else if (whence == 1) base = @intCast(state.pos) else if (whence == 2) base = @intCast(state.len) else return c.py_exception(c.tp_ValueError, "invalid whence");
    const new_pos_i = base + off;
    if (new_pos_i < 0) return c.py_exception(c.tp_ValueError, "negative seek position");
    state.pos = @intCast(new_pos_i);
    c.py_newint(c.py_retval(), @intCast(state.pos));
    return true;
}

fn stringio_close(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "close() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    state.closed = true;
    setClosedAttr(self, true);
    c.py_newnone(c.py_retval());
    return true;
}

fn stringio_enter(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__enter__() takes no arguments");
    pk.setRetval(pk.argRef(argv, 0));
    return true;
}

fn stringio_exit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // PocketPy calls __exit__ with only `self` in `with` statements.
    if (argc != 1 and argc != 4) return c.py_exception(c.tp_TypeError, "__exit__() takes 3 arguments");
    _ = stringio_close(1, argv);
    c.py_newbool(c.py_retval(), false);
    return true;
}

fn stringio_readline(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "readline() takes no arguments");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    const start = state.pos;
    if (start >= state.len) {
        _ = c.py_newstrn(c.py_retval(), 0);
        return true;
    }
    var end = start;
    while (end < state.len) : (end += 1) {
        if (state.ptr.?[end] == '\n') {
            end += 1;
            break;
        }
    }
    const to_read = end - start;
    const out = c.py_newstrn(c.py_retval(), @intCast(to_read));
    if (to_read > 0) {
        @memcpy(@as([*]u8, @ptrCast(out))[0..to_read], state.ptr.?[start..end]);
    }
    state.pos = end;
    return true;
}

fn stringio_readlines(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "readlines() takes 0 or 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    c.py_newlist(c.py_r0());
    const out = c.py_r0();
    while (state.pos < state.len) {
        if (!stringio_readline(1, argv)) return false;
        c.py_r1().* = c.py_retval().*;
        c.py_list_append(out, c.py_r1());
    }
    pk.setRetval(out);
    return true;
}

fn stringio_writelines(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "writelines() takes exactly 1 argument");
    const self = pk.argRef(argv, 0);
    const state: *Buffer = @ptrCast(@alignCast(c.py_touserdata(self)));
    if (state.closed) return c.py_exception(c.tp_ValueError, "I/O operation on closed file");
    if (!c.py_iter(pk.argRef(argv, 1))) return false;
    c.py_r0().* = c.py_retval().*;
    const it = c.py_r0();
    while (true) {
        const res = c.py_next(it);
        if (res == 0) break;
        if (res < 0) return false;
        c.py_r1().* = c.py_retval().*;
        const item = c.py_r1();
        if (!c.py_checkstr(item)) return false;
        const sv = c.py_tosv(item);
        if (sv.data == null) return c.py_exception(c.tp_TypeError, "writelines() expects strings");
        const data_len: usize = @intCast(sv.size);
        const end_pos = state.pos + data_len;
        ensureCap(state, end_pos) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        if (state.pos > state.len) {
            @memset(state.ptr.?[state.len..state.pos], 0);
            state.len = state.pos;
        }
        @memcpy(state.ptr.?[state.pos..end_pos], @as([*]const u8, @ptrCast(sv.data))[0..data_len]);
        state.pos = end_pos;
        if (end_pos > state.len) state.len = end_pos;
    }
    c.py_newnone(c.py_retval());
    return true;
}

pub fn register() void {
    const name: [:0]const u8 = "io";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);

    tp_bytesio = c.py_newtype("BytesIO", c.tp_object, module, bufferDtor);
    c.py_bind(c.py_tpobject(tp_bytesio), "__new__(cls, initial_bytes=None)", bytesio_new);
    c.py_bind(c.py_tpobject(tp_bytesio), "__init__(self, initial_bytes=None)", bytesio_init);
    c.py_bindmethod(tp_bytesio, "getvalue", bytesio_getvalue);
    c.py_bindmethod(tp_bytesio, "write", bytesio_write);
    c.py_bindmethod(tp_bytesio, "read", bytesio_read);
    c.py_bindmethod(tp_bytesio, "readline", bytesio_readline);
    c.py_bindmethod(tp_bytesio, "readlines", bytesio_readlines);
    c.py_bindmethod(tp_bytesio, "writelines", bytesio_writelines);
    c.py_bindmethod(tp_bytesio, "tell", bytesio_tell);
    c.py_bindmethod(tp_bytesio, "seek", bytesio_seek);
    c.py_bindmethod(tp_bytesio, "truncate", bytesio_truncate);
    c.py_bindmethod(tp_bytesio, "close", bytesio_close);
    c.py_bind(c.py_tpobject(tp_bytesio), "__enter__(self)", bytesio_enter);
    c.py_bind(c.py_tpobject(tp_bytesio), "__exit__(self, exc_type=None, exc=None, tb=None)", bytesio_exit);
    c.py_setdict(module, c.py_name("BytesIO"), c.py_tpobject(tp_bytesio));

    tp_stringio = c.py_newtype("StringIO", c.tp_object, module, bufferDtor);
    c.py_bind(c.py_tpobject(tp_stringio), "__new__(cls, initial_value=None)", stringio_new);
    c.py_bind(c.py_tpobject(tp_stringio), "__init__(self, initial_value=None)", stringio_init);
    c.py_bindmethod(tp_stringio, "getvalue", stringio_getvalue);
    c.py_bindmethod(tp_stringio, "write", stringio_write);
    c.py_bindmethod(tp_stringio, "writelines", stringio_writelines);
    c.py_bindmethod(tp_stringio, "read", stringio_read);
    c.py_bindmethod(tp_stringio, "readline", stringio_readline);
    c.py_bindmethod(tp_stringio, "readlines", stringio_readlines);
    c.py_bindmethod(tp_stringio, "tell", stringio_tell);
    c.py_bindmethod(tp_stringio, "seek", stringio_seek);
    c.py_bindmethod(tp_stringio, "close", stringio_close);
    c.py_bind(c.py_tpobject(tp_stringio), "__enter__(self)", stringio_enter);
    c.py_bind(c.py_tpobject(tp_stringio), "__exit__(self, exc_type=None, exc=None, tb=None)", stringio_exit);
    c.py_setdict(module, c.py_name("StringIO"), c.py_tpobject(tp_stringio));
}
