/// dataclasses.zig - Minimal `dataclasses` module
///
/// Implements a small subset that is useful for simple CLI apps:
/// - dataclass(cls=None, init=True, repr=True, eq=True)
/// - is_dataclass(obj)
///
/// Limitations:
/// - no Field objects / metadata
/// - defaults only work if the default is a simple literal handled by PocketPy signature binding
/// - frozen/order/kw_only not supported yet
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_decorator: c.py_Type = 0;

const Opts = struct { init: bool, repr: bool, eq: bool };

fn collectFieldFn(key: c.py_Ref, _: c.py_Ref, ctx_ptr: ?*anyopaque) callconv(.c) bool {
    const list: *std.ArrayList(c.py_TValue) = @ptrCast(@alignCast(ctx_ptr));
    if (!c.py_isstr(key)) return true;
    list.append(std.heap.c_allocator, key.*) catch return false;
    return true;
}

fn setFuncOnClass(cls: c.py_Ref, name: [:0]const u8, sig: [:0]const u8, f: c.py_CFunction) bool {
    _ = c.py_newfunction(c.py_r0(), sig.ptr, f, null, -1);
    c.py_setdict(cls, c.py_name(name.ptr), c.py_r0());
    return true;
}

fn dataclassInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "__init__ missing self");
    const self = pk.argRef(argv, 0);
    const cls = c.py_tpobject(c.py_typeof(self));
    const fields_ptr = c.py_getdict(cls, c.py_name("__dataclass_fields__")) orelse {
        c.py_newnone(c.py_retval());
        return true;
    };
    if (!c.py_islist(fields_ptr)) {
        c.py_newnone(c.py_retval());
        return true;
    }
    const fields = fields_ptr;
    const n = c.py_list_len(fields);
    if (argc - 1 != n) {
        return c.py_exception(c.tp_TypeError, "wrong number of arguments");
    }
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const name_obj = c.py_list_getitem(fields, i);
        if (!c.py_isstr(name_obj)) continue;
        const key = c.py_name(c.py_tostr(name_obj));
        const idx: usize = @intCast(i + 1);
        c.py_setdict(self, key, pk.argRef(argv, idx));
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn dataclassRepr(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__repr__ takes no arguments");
    const self = pk.argRef(argv, 0);
    const cls = c.py_tpobject(c.py_typeof(self));
    const fields_ptr = c.py_getdict(cls, c.py_name("__dataclass_fields__"));

    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();
    w.print("{s}(", .{c.py_tpname(c.py_typeof(self))}) catch return c.py_exception(c.tp_RuntimeError, "repr too long");

    if (fields_ptr != null and c.py_islist(fields_ptr.?)) {
        const fields = fields_ptr.?;
        const n = c.py_list_len(fields);
        var i: c_int = 0;
        while (i < n) : (i += 1) {
            if (i != 0) w.writeAll(", ") catch return c.py_exception(c.tp_RuntimeError, "repr too long");
            const name_obj = c.py_list_getitem(fields, i);
            if (!c.py_isstr(name_obj)) continue;
            const name_c = c.py_tostr(name_obj);
            w.writeAll(name_c[0..std.mem.len(name_c)]) catch return c.py_exception(c.tp_RuntimeError, "repr too long");
            w.writeAll("=") catch return c.py_exception(c.tp_RuntimeError, "repr too long");
            const val_ptr = c.py_getdict(self, c.py_name(name_c));
            if (val_ptr == null) {
                w.writeAll("None") catch return c.py_exception(c.tp_RuntimeError, "repr too long");
                continue;
            }
            if (!c.py_repr(val_ptr.?)) return false;
            const s = c.py_tostr(c.py_retval());
            w.writeAll(s[0..std.mem.len(s)]) catch return c.py_exception(c.tp_RuntimeError, "repr too long");
        }
    }

    w.writeAll(")") catch return c.py_exception(c.tp_RuntimeError, "repr too long");
    const written = fbs.getWritten();
    const out = c.py_newstrn(c.py_retval(), @intCast(written.len));
    @memcpy(out[0..written.len], written);
    return true;
}

fn dataclassEq(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "__eq__ takes 2 arguments");
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    if (c.py_typeof(self) != c.py_typeof(other)) {
        c.py_newbool(c.py_retval(), false);
        return true;
    }
    const cls = c.py_tpobject(c.py_typeof(self));
    const fields_ptr = c.py_getdict(cls, c.py_name("__dataclass_fields__"));
    if (fields_ptr == null or !c.py_islist(fields_ptr.?)) {
        c.py_newbool(c.py_retval(), true);
        return true;
    }
    const fields = fields_ptr.?;
    const n = c.py_list_len(fields);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const name_obj = c.py_list_getitem(fields, i);
        if (!c.py_isstr(name_obj)) continue;
        const name_c = c.py_tostr(name_obj);
        const name_id = c.py_name(name_c);
        const a_ptr = c.py_getdict(self, name_id);
        const b_ptr = c.py_getdict(other, name_id);
        if (a_ptr == null or b_ptr == null) {
            c.py_newbool(c.py_retval(), false);
            return true;
        }
        const eq = c.py_equal(a_ptr.?, b_ptr.?);
        if (eq < 0) return false;
        if (eq == 0) {
            c.py_newbool(c.py_retval(), false);
            return true;
        }
    }
    c.py_newbool(c.py_retval(), true);
    return true;
}

fn applyDataclass(cls: c.py_Ref, opts: Opts) bool {
    if (!c.py_istype(cls, c.tp_type)) return c.py_exception(c.tp_TypeError, "expected class");

    // Extract annotations -> field list
    var fields: std.ArrayList(c.py_TValue) = .empty;
    defer fields.deinit(std.heap.c_allocator);

    const ann_ptr = c.py_getdict(cls, c.py_name("__annotations__"));
    if (ann_ptr != null and c.py_isdict(ann_ptr.?)) {
        if (!c.py_dict_apply(ann_ptr.?, collectFieldFn, &fields)) return false;
    }

    // Save fields on the class
    c.py_newlist(c.py_r0());
    const py_fields = c.py_r0();
    for (fields.items) |tv| {
        c.py_list_append(py_fields, @constCast(&tv));
    }
    c.py_setdict(cls, c.py_name("__dataclass_fields__"), py_fields);

    if (opts.init) {
        // Simple signature: positional args only (keywords work via binding).
        var sig_buf: [2048]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&sig_buf);
        const w = fbs.writer();
        w.writeAll("__init__(self") catch return c.py_exception(c.tp_RuntimeError, "sig too long");
        for (fields.items) |tv| {
            const sv = c.py_tosv(@constCast(&tv));
            const name_bytes: []const u8 = @as([*]const u8, @ptrCast(sv.data))[0..@intCast(sv.size)];
            w.writeAll(", ") catch return c.py_exception(c.tp_RuntimeError, "sig too long");
            w.writeAll(name_bytes) catch return c.py_exception(c.tp_RuntimeError, "sig too long");
        }
        w.writeAll(")") catch return c.py_exception(c.tp_RuntimeError, "sig too long");
        const sig_written = fbs.getWritten();
        // Ensure null-termination
        if (sig_written.len + 1 > sig_buf.len) return c.py_exception(c.tp_RuntimeError, "sig too long");
        sig_buf[sig_written.len] = 0;
        const sig_z: [:0]const u8 = sig_buf[0..sig_written.len :0];
        _ = setFuncOnClass(cls, "__init__", sig_z, dataclassInit);
    }
    if (opts.repr) _ = setFuncOnClass(cls, "__repr__", "__repr__(self)", dataclassRepr);
    if (opts.eq) _ = setFuncOnClass(cls, "__eq__", "__eq__(self, other)", dataclassEq);

    c.py_retval().* = cls.*;
    return true;
}

fn decoratorNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_decorator, 3, 0);
    c.py_newbool(c.py_r0(), true);
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    c.py_newbool(c.py_r0(), true);
    c.py_setslot(c.py_retval(), 1, c.py_r0());
    c.py_newbool(c.py_r0(), true);
    c.py_setslot(c.py_retval(), 2, c.py_r0());
    return true;
}

fn decoratorCall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "decorator requires a class");
    const self = pk.argRef(argv, 0);
    const cls = pk.argRef(argv, 1);
    const opts: Opts = .{
        .init = c.py_tobool(c.py_getslot(self, 0)),
        .repr = c.py_tobool(c.py_getslot(self, 1)),
        .eq = c.py_tobool(c.py_getslot(self, 2)),
    };
    return applyDataclass(cls, opts);
}

fn dataclassFn(ctx: *pk.Context) bool {
    const cls_opt = ctx.argOptional(0);
    const init_opt = ctx.argBool(1) orelse true;
    const repr_opt = ctx.argBool(2) orelse true;
    const eq_opt = ctx.argBool(3) orelse true;

    const opts: Opts = .{ .init = init_opt, .repr = repr_opt, .eq = eq_opt };

    if (cls_opt) |cls_val| {
        return applyDataclass(cls_val.refConst(), opts);
    }

    _ = c.py_newobject(c.py_retval(), tp_decorator, 3, 0);
    c.py_newbool(c.py_r0(), opts.init);
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    c.py_newbool(c.py_r0(), opts.repr);
    c.py_setslot(c.py_retval(), 1, c.py_r0());
    c.py_newbool(c.py_r0(), opts.eq);
    c.py_setslot(c.py_retval(), 2, c.py_r0());
    return true;
}

fn isDataclassFn(ctx: *pk.Context) bool {
    const obj = ctx.arg(0) orelse return ctx.typeError("expected object");
    const cls = c.py_tpobject(c.py_typeof(obj.refConst()));
    const fields_ptr = c.py_getdict(cls, c.py_name("__dataclass_fields__"));
    return ctx.returnBool(fields_ptr != null and c.py_islist(fields_ptr.?));
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("dataclasses");

    var decor_builder = pk.TypeBuilder.newSimple("_DataclassDecorator", builder.module);
    tp_decorator = decor_builder
        .magic("__new__", decoratorNew)
        .magic("__call__", decoratorCall)
        .build();

    _ = builder
        .funcSigWrapped("dataclass(cls=None, init=True, repr=True, eq=True)", 0, 4, dataclassFn)
        .funcWrapped("is_dataclass", 1, 1, isDataclassFn);
}
