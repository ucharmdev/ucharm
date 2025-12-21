/// template - TinyTemplate-backed templating (Jinja-ish, minimal)
///
/// Implements:
/// - render(src: str, params: dict|object) -> str
///
/// Template language (from TinyTemplate):
/// - Variables: {{name}}, dotted access: {{user.name}}
/// - Conditionals: {% if cond %}...{% else %}...{% end %}
/// - Loops: {% for item in items %}...{{item}}...{% end %}
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

const tt = struct {
    pub const tinytemplate_type_t = enum(c_int) {
        TINYTEMPLATE_TYPE_INT,
        TINYTEMPLATE_TYPE_FLOAT,
        TINYTEMPLATE_TYPE_DICT,
        TINYTEMPLATE_TYPE_ARRAY,
        TINYTEMPLATE_TYPE_STRING,
    };

    pub const tinytemplate_status_t = enum(c_int) {
        TINYTEMPLATE_STATUS_DONE,
        TINYTEMPLATE_STATUS_ESYMBOL,
        TINYTEMPLATE_STATUS_ESCOPE,
        TINYTEMPLATE_STATUS_EDEPTH,
        TINYTEMPLATE_STATUS_ETYPE,
        TINYTEMPLATE_STATUS_EITER,
        TINYTEMPLATE_STATUS_EMEMORY,
        TINYTEMPLATE_STATUS_ESYNTAX,
        TINYTEMPLATE_STATUS_ESEMANT,
    };

    pub const tinytemplate_value_t = extern struct {
        type: tinytemplate_type_t,
        data: tinytemplate_union_t,
    };

    // Note: we use `?*anyopaque` for the `tinytemplate_value_t*` parameter to
    // avoid a type dependency cycle in Zig while keeping the ABI identical
    // (it's still just a pointer).
    pub const tinytemplate_nextcallback_t = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.c) bool;
    pub const tinytemplate_getter_t = ?*const fn (?*anyopaque, [*c]const u8, usize, ?*anyopaque) callconv(.c) bool;
    pub const tinytemplate_callback_t = ?*const fn (?*anyopaque, [*c]const u8, usize) callconv(.c) void;

    pub const tinytemplate_dict_t = extern struct {
        data: ?*anyopaque,
        get: tinytemplate_getter_t,
    };

    pub const tinytemplate_array_t = extern struct {
        data: ?*anyopaque,
        next: tinytemplate_nextcallback_t,
    };

    pub const tinytemplate_string_t = extern struct {
        str: [*c]const u8,
        len: usize,
    };

    pub const tinytemplate_union_t = extern union {
        as_int: i64,
        as_float: f64,
        as_dict: tinytemplate_dict_t,
        as_array: tinytemplate_array_t,
        as_string: tinytemplate_string_t,
    };

    pub const Operand = extern struct {
        as_int: i64,
        as_size: usize,
        as_float: f64,
    };

    pub const tinytemplate_instr_t = extern struct {
        opcode: c_int,
        operands: [2]Operand,
    };

    pub extern fn tinytemplate_eval(
        src: [*c]const u8,
        program: [*c]const tinytemplate_instr_t,
        userp: ?*anyopaque,
        params: tinytemplate_getter_t,
        callback: tinytemplate_callback_t,
        errmsg: [*c]u8,
        errmax: usize,
    ) tinytemplate_status_t;

    pub extern fn tinytemplate_compile(
        src: [*c]const u8,
        len: usize,
        program: [*c]tinytemplate_instr_t,
        max_instr: usize,
        num_instr: *usize,
        errmsg: [*c]u8,
        errmax: usize,
    ) tinytemplate_status_t;

    pub extern fn tinytemplate_set_int(dst: [*c]tinytemplate_value_t, value: i64) void;
    pub extern fn tinytemplate_set_float(dst: [*c]tinytemplate_value_t, value: f32) void;
    pub extern fn tinytemplate_set_string(dst: [*c]tinytemplate_value_t, str: [*c]const u8, len: usize) void;
    pub extern fn tinytemplate_set_array(dst: [*c]tinytemplate_value_t, data: ?*anyopaque, next: tinytemplate_nextcallback_t) void;
    pub extern fn tinytemplate_set_dict(dst: [*c]tinytemplate_value_t, data: ?*anyopaque, get: tinytemplate_getter_t) void;
};

const RenderCtx = struct {
    arena: std.heap.ArenaAllocator,
    out: std.ArrayList(u8),
    root: c.py_Ref,
    oom: bool = false,
    had_py_error: bool = false,

    fn init(root: c.py_Ref) RenderCtx {
        return .{
            .arena = std.heap.ArenaAllocator.init(std.heap.c_allocator),
            .out = std.ArrayList(u8).empty,
            .root = root,
        };
    }

    fn deinit(self: *RenderCtx) void {
        self.out.deinit(std.heap.c_allocator);
        self.arena.deinit();
    }

    fn allocZ(self: *RenderCtx, bytes: []const u8) ?[*:0]u8 {
        const a = self.arena.allocator();
        var buf = a.alloc(u8, bytes.len + 1) catch {
            self.oom = true;
            return null;
        };
        @memcpy(buf[0..bytes.len], bytes);
        buf[bytes.len] = 0;
        return @ptrCast(buf.ptr);
    }

    fn stashValue(self: *RenderCtx, v: c.py_Ref) ?c.py_Ref {
        const a = self.arena.allocator();
        const slot = a.create(c.py_TValue) catch {
            self.oom = true;
            return null;
        };
        slot.* = v.*;
        return slot;
    }
};

const DictData = struct {
    ctx: *RenderCtx,
    obj: c.py_Ref,
};

const ArrayIter = struct {
    ctx: *RenderCtx,
    seq: c.py_Ref,
    index: usize,
};

fn setValue(ctx: *RenderCtx, v: c.py_Ref, out: [*c]tt.tinytemplate_value_t) bool {
    if (c.py_isnone(v)) {
        tt.tinytemplate_set_string(out, "", 0);
        return true;
    }
    if (c.py_isbool(v)) {
        const b = c.py_tobool(v);
        tt.tinytemplate_set_int(out, if (b) 1 else 0);
        return true;
    }
    if (c.py_isint(v)) {
        tt.tinytemplate_set_int(out, @intCast(c.py_toint(v)));
        return true;
    }
    if (c.py_isfloat(v)) {
        tt.tinytemplate_set_float(out, @floatCast(c.py_tofloat(v)));
        return true;
    }
    if (c.py_isstr(v)) {
        const s = c.py_tostr(v);
        const sl = s[0..std.mem.len(s)];
        tt.tinytemplate_set_string(out, @ptrCast(sl.ptr), sl.len);
        return true;
    }
    if (c.py_istype(v, c.tp_bytes)) {
        var n: c_int = 0;
        const p = c.py_tobytes(v, &n);
        tt.tinytemplate_set_string(out, @ptrCast(p), @intCast(n));
        return true;
    }

    if (c.py_isdict(v)) {
        const a = ctx.arena.allocator();
        const dd = a.create(DictData) catch {
            ctx.oom = true;
            return false;
        };
        dd.* = .{ .ctx = ctx, .obj = v };
        tt.tinytemplate_set_dict(out, dd, dictGetCb);
        return true;
    }

    if (c.py_islist(v) or c.py_istuple(v)) {
        const a = ctx.arena.allocator();
        const it = a.create(ArrayIter) catch {
            ctx.oom = true;
            return false;
        };
        it.* = .{ .ctx = ctx, .seq = v, .index = 0 };
        tt.tinytemplate_set_array(out, it, arrayNextCb);
        return true;
    }

    // Fallback: stringify like Jinja2 would.
    if (!c.py_str(v)) {
        ctx.had_py_error = true;
        return false;
    }
    const str_ref = ctx.stashValue(c.py_retval()) orelse return false;
    const s = c.py_tostr(str_ref);
    const sl = s[0..std.mem.len(s)];
    tt.tinytemplate_set_string(out, @ptrCast(sl.ptr), sl.len);
    return true;
}

fn getAttrOrItem(ctx: *RenderCtx, obj: c.py_Ref, key: []const u8) ?c.py_Ref {
    const key_z = ctx.allocZ(key) orelse return null;
    if (c.py_isdict(obj)) {
        const found = c.py_dict_getitem_by_str(obj, key_z);
        if (found < 0) {
            ctx.had_py_error = true;
            return null;
        }
        if (found == 0) return null;
        return ctx.stashValue(c.py_retval());
    }

    if (!c.py_getattr(obj, c.py_name(key_z))) {
        c.py_clearexc(null);
        return null;
    }
    return ctx.stashValue(c.py_retval());
}

fn paramsCb(userp: ?*anyopaque, key_ptr: [*c]const u8, key_len: usize, out_any: ?*anyopaque) callconv(.c) bool {
    if (userp == null) return false;
    const ctx: *RenderCtx = @ptrCast(@alignCast(userp));
    if (out_any == null) return false;
    const out: [*c]tt.tinytemplate_value_t = @ptrCast(@alignCast(out_any));
    const key = @as([*]const u8, @ptrCast(key_ptr))[0..key_len];
    const v = getAttrOrItem(ctx, ctx.root, key) orelse return false;
    return setValue(ctx, v, out);
}

fn dictGetCb(data: ?*anyopaque, key_ptr: [*c]const u8, key_len: usize, out_any: ?*anyopaque) callconv(.c) bool {
    if (data == null) return false;
    const dd: *DictData = @ptrCast(@alignCast(data));
    if (out_any == null) return false;
    const out: [*c]tt.tinytemplate_value_t = @ptrCast(@alignCast(out_any));
    const key = @as([*]const u8, @ptrCast(key_ptr))[0..key_len];
    const v = getAttrOrItem(dd.ctx, dd.obj, key) orelse return false;
    return setValue(dd.ctx, v, out);
}

fn arrayNextCb(data: ?*anyopaque, out_any: ?*anyopaque) callconv(.c) bool {
    if (data == null) return false;
    const it: *ArrayIter = @ptrCast(@alignCast(data));
    if (out_any == null) return false;
    const out: [*c]tt.tinytemplate_value_t = @ptrCast(@alignCast(out_any));
    const seq = it.seq;

    if (c.py_islist(seq)) {
        const n: usize = @intCast(c.py_list_len(seq));
        if (it.index >= n) return false;
        const item = c.py_list_getitem(seq, @intCast(it.index));
        it.index += 1;
        return setValue(it.ctx, item, out);
    }
    if (c.py_istuple(seq)) {
        const n: usize = @intCast(c.py_tuple_len(seq));
        if (it.index >= n) return false;
        const item = c.py_tuple_getitem(seq, @intCast(it.index));
        it.index += 1;
        return setValue(it.ctx, item, out);
    }

    return false;
}

fn outputCb(userp: ?*anyopaque, str_ptr: [*c]const u8, len: usize) callconv(.c) void {
    if (userp == null) return;
    const ctx: *RenderCtx = @ptrCast(@alignCast(userp));
    if (ctx.oom) return;
    const bytes = @as([*]const u8, @ptrCast(str_ptr))[0..len];
    ctx.out.appendSlice(std.heap.c_allocator, bytes) catch {
        ctx.oom = true;
        return;
    };
}

fn renderFn(ctx: *pk.Context) bool {
    const src = ctx.argStr(0) orelse return ctx.typeError("src must be a string");
    var data_val = ctx.argOptional(1) orelse pk.Value.from(c.py_None());
    const data_ref = data_val.refConst();
    if (!c.py_isdict(data_ref) and !c.py_isnone(data_ref)) {
        // Allow objects too, but reject primitives.
        if (c.py_isstr(data_ref) or c.py_isint(data_ref) or c.py_isfloat(data_ref) or c.py_isbool(data_ref)) {
            return ctx.typeError("params must be dict or object");
        }
    }

    var rctx = RenderCtx.init(data_ref);
    defer rctx.deinit();

    // Compile (grow program buffer on demand).
    var errmsg: [256]u8 = undefined;
    errmsg[errmsg.len - 1] = 0;
    var prog_cap: usize = 256;
    var program = std.heap.c_allocator.alloc(tt.tinytemplate_instr_t, prog_cap) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    defer std.heap.c_allocator.free(program);

    var num_instr: usize = 0;
    while (true) {
        const st = tt.tinytemplate_compile(@ptrCast(src.ptr), src.len, program.ptr, prog_cap, &num_instr, @ptrCast(&errmsg[0]), errmsg.len);
        if (st == tt.tinytemplate_status_t.TINYTEMPLATE_STATUS_DONE) break;
        if (st != tt.tinytemplate_status_t.TINYTEMPLATE_STATUS_EMEMORY) {
            errmsg[errmsg.len - 1] = 0;
            return c.py_exception(c.tp_ValueError, "%s", @as([*c]const u8, @ptrCast(&errmsg[0])));
        }
        prog_cap *= 2;
        std.heap.c_allocator.free(program);
        program = std.heap.c_allocator.alloc(tt.tinytemplate_instr_t, prog_cap) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    }

    // Evaluate.
    errmsg[errmsg.len - 1] = 0;
    const st_eval = tt.tinytemplate_eval(@ptrCast(src.ptr), program.ptr, &rctx, paramsCb, outputCb, @ptrCast(&errmsg[0]), errmsg.len);
    if (rctx.had_py_error) return false;
    if (rctx.oom) return c.py_exception(c.tp_RuntimeError, "out of memory");
    if (st_eval != tt.tinytemplate_status_t.TINYTEMPLATE_STATUS_DONE) {
        errmsg[errmsg.len - 1] = 0;
        return c.py_exception(c.tp_ValueError, "%s", @as([*c]const u8, @ptrCast(&errmsg[0])));
    }

    return ctx.returnStr(rctx.out.items);
}

pub fn register() void {
    const module = c.py_newmodule("template");
    c.py_bindfunc(module, "render", pk.wrapFn(1, 2, renderFn));
}
