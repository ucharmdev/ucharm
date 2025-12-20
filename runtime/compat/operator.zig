const std = @import("std");
const pk = @import("pk");
const c = pk.c;

// Type handles for custom classes
var tp_itemgetter: c.py_Type = 0;
var tp_attrgetter: c.py_Type = 0;
var tp_methodcaller: c.py_Type = 0;

fn posFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const arg = pk.argRef(argv, 0);
    // For numeric types, pos just returns the value
    if (c.py_isint(arg)) {
        c.py_retval().* = arg.*;
        return true;
    }
    var val: c.py_f64 = 0.0;
    if (c.py_castfloat(arg, &val)) {
        c.py_newfloat(c.py_retval(), val);
        return true;
    }
    return c.py_exception(c.tp_TypeError, "bad operand type for unary +");
}

fn absFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const arg = pk.argRef(argv, 0);
    if (c.py_isint(arg)) {
        const val = c.py_toint(arg);
        const abs_val = if (val < 0) -val else val;
        c.py_newint(c.py_retval(), abs_val);
        return true;
    }
    var val: c.py_f64 = 0.0;
    if (c.py_castfloat(arg, &val)) {
        const abs_val = if (val < 0) -val else val;
        c.py_newfloat(c.py_retval(), abs_val);
        return true;
    }
    return c.py_exception(c.tp_TypeError, "bad operand type for abs()");
}

fn indexFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const arg = pk.argRef(argv, 0);
    if (c.py_isint(arg)) {
        c.py_retval().* = arg.*;
        return true;
    }
    return c.py_exception(c.tp_TypeError, "'index' requires an integer");
}

fn invFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const arg = pk.argRef(argv, 0);
    if (c.py_isint(arg)) {
        const val = c.py_toint(arg);
        c.py_newint(c.py_retval(), ~val);
        return true;
    }
    return c.py_exception(c.tp_TypeError, "bad operand type for unary ~");
}

fn isNoneFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const arg = pk.argRef(argv, 0);
    if (c.py_isnone(arg)) {
        c.py_newbool(c.py_retval(), true);
    } else {
        c.py_newbool(c.py_retval(), false);
    }
    return true;
}

fn isNotNoneFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const arg = pk.argRef(argv, 0);
    if (c.py_isnone(arg)) {
        c.py_newbool(c.py_retval(), false);
    } else {
        c.py_newbool(c.py_retval(), true);
    }
    return true;
}

fn concatFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 0);
    const b = pk.argRef(argv, 1);

    // For lists
    if (c.py_islist(a) and c.py_islist(b)) {
        const len_a = c.py_list_len(a);
        const len_b = c.py_list_len(b);
        c.py_newlist(c.py_retval());
        var i: c_int = 0;
        while (i < len_a) : (i += 1) {
            c.py_list_append(c.py_retval(), c.py_list_getitem(a, i));
        }
        i = 0;
        while (i < len_b) : (i += 1) {
            c.py_list_append(c.py_retval(), c.py_list_getitem(b, i));
        }
        return true;
    }

    // For strings, concatenate using sv
    if (c.py_isstr(a) and c.py_isstr(b)) {
        const sv_a = c.py_tosv(a);
        const sv_b = c.py_tosv(b);
        const len_a: usize = @intCast(sv_a.size);
        const len_b: usize = @intCast(sv_b.size);
        const total = len_a + len_b;

        const out = c.py_newstrn(c.py_retval(), @intCast(total));
        @memcpy(out[0..len_a], sv_a.data[0..len_a]);
        @memcpy(out[len_a..total], sv_b.data[0..len_b]);
        return true;
    }

    return c.py_exception(c.tp_TypeError, "can only concatenate sequences");
}

fn countOfFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 0);
    const b = pk.argRef(argv, 1);

    if (!c.py_islist(a)) {
        return c.py_exception(c.tp_TypeError, "expected list");
    }

    const len = c.py_list_len(a);
    var count: c.py_i64 = 0;
    var i: c_int = 0;
    while (i < len) : (i += 1) {
        const item = c.py_list_getitem(a, i);
        const eq = c.py_equal(item, b);
        if (eq < 0) return false;
        if (eq == 1) count += 1;
    }

    c.py_newint(c.py_retval(), count);
    return true;
}

fn indexOfFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 0);
    const b = pk.argRef(argv, 1);

    if (!c.py_islist(a)) {
        return c.py_exception(c.tp_TypeError, "expected list");
    }

    const len = c.py_list_len(a);
    var i: c_int = 0;
    while (i < len) : (i += 1) {
        const item = c.py_list_getitem(a, i);
        const eq = c.py_equal(item, b);
        if (eq < 0) return false;
        if (eq == 1) {
            c.py_newint(c.py_retval(), i);
            return true;
        }
    }

    return c.py_exception(c.tp_ValueError, "sequence.index(x): x not in sequence");
}

fn ipowFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 0);
    const b = pk.argRef(argv, 1);

    // Compute power
    var val_a: c.py_f64 = 0.0;
    var val_b: c.py_f64 = 0.0;

    if (!c.py_castfloat(a, &val_a)) {
        return c.py_exception(c.tp_TypeError, "unsupported operand type for **");
    }
    if (!c.py_castfloat(b, &val_b)) {
        return c.py_exception(c.tp_TypeError, "unsupported operand type for **");
    }

    const result = @import("std").math.pow(c.py_f64, val_a, val_b);

    // Return int if both inputs are int and result is integral
    if (c.py_isint(a) and c.py_isint(b) and val_b >= 0 and result == @trunc(result)) {
        c.py_newint(c.py_retval(), @intFromFloat(result));
    } else {
        c.py_newfloat(c.py_retval(), result);
    }
    return true;
}

fn iconcatFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 0);
    const b = pk.argRef(argv, 1);

    // For lists, extend in place
    if (c.py_islist(a) and c.py_islist(b)) {
        const len_b = c.py_list_len(b);
        var i: c_int = 0;
        while (i < len_b) : (i += 1) {
            c.py_list_append(a, c.py_list_getitem(b, i));
        }
        c.py_retval().* = a.*;
        return true;
    }

    return c.py_exception(c.tp_TypeError, "can only concatenate sequences");
}

// itemgetter - creates a callable that fetches items from an object
fn itemgetterNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "itemgetter requires at least one argument");
    }

    // Create instance with keys stored as a tuple
    _ = c.py_newobject(c.py_retval(), tp_itemgetter, -1, 0);

    // Store keys as a tuple
    const n_keys = argc - 1;
    const keys = c.py_newtuple(c.py_r0(), n_keys);
    var i: usize = 0;
    while (i < @as(usize, @intCast(n_keys))) : (i += 1) {
        keys[i] = pk.argRef(argv, i + 1).*;
    }
    c.py_setdict(c.py_retval(), c.py_name("_keys"), c.py_r0());

    return true;
}

fn itemgetterCall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "itemgetter expected 1 argument");
    }

    const self = pk.argRef(argv, 0);
    const obj = pk.argRef(argv, 1);

    const keys_ptr = c.py_getdict(self, c.py_name("_keys"));
    if (keys_ptr == null) return c.py_exception(c.tp_RuntimeError, "itemgetter has no keys");
    const keys = keys_ptr.?;

    const n_keys = c.py_tuple_len(keys);

    if (n_keys == 1) {
        // Single key - return single value
        const key = c.py_tuple_getitem(keys, 0);
        return c.py_getitem(obj, key);
    } else {
        // Multiple keys - first collect all values, then create tuple
        var values: [16]c.py_TValue = undefined;
        if (n_keys > 16) {
            return c.py_exception(c.tp_ValueError, "too many keys");
        }

        var i: c_int = 0;
        while (i < n_keys) : (i += 1) {
            const key = c.py_tuple_getitem(keys, i);
            if (!c.py_getitem(obj, key)) return false;
            values[@intCast(i)] = c.py_retval().*;
        }

        // Now create tuple with collected values
        const result = c.py_newtuple(c.py_retval(), n_keys);
        i = 0;
        while (i < n_keys) : (i += 1) {
            result[@intCast(i)] = values[@intCast(i)];
        }
        return true;
    }
}

// attrgetter - creates a callable that fetches attributes from an object
fn attrgetterNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "attrgetter requires at least one argument");
    }

    // Create instance with attrs stored as a tuple
    _ = c.py_newobject(c.py_retval(), tp_attrgetter, -1, 0);

    // Store attrs as a tuple
    const n_attrs = argc - 1;
    const attrs = c.py_newtuple(c.py_r0(), n_attrs);
    var i: usize = 0;
    while (i < @as(usize, @intCast(n_attrs))) : (i += 1) {
        attrs[i] = pk.argRef(argv, i + 1).*;
    }
    c.py_setdict(c.py_retval(), c.py_name("_attrs"), c.py_r0());

    return true;
}

fn getNestedAttr(obj: c.py_Ref, attr_str: [*c]const u8) bool {
    // Handle nested attributes like "a.b.c"
    var current = obj.*;
    var start: usize = 0;
    var i: usize = 0;

    const len = std.mem.len(attr_str);

    while (i <= len) : (i += 1) {
        if (i == len or attr_str[i] == '.') {
            if (i > start) {
                // Get this attribute segment
                var name_buf: [128]u8 = undefined;
                const seg_len = i - start;
                if (seg_len >= name_buf.len) {
                    return c.py_exception(c.tp_ValueError, "attribute name too long");
                }
                @memcpy(name_buf[0..seg_len], attr_str[start..i]);
                name_buf[seg_len] = 0;

                const name = c.py_name(@ptrCast(&name_buf));
                if (!c.py_getattr(&current, name)) return false;
                current = c.py_retval().*;
            }
            start = i + 1;
        }
    }

    c.py_retval().* = current;
    return true;
}

fn attrgetterCall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "attrgetter expected 1 argument");
    }

    const self = pk.argRef(argv, 0);
    const obj = pk.argRef(argv, 1);

    const attrs_ptr = c.py_getdict(self, c.py_name("_attrs"));
    if (attrs_ptr == null) return c.py_exception(c.tp_RuntimeError, "attrgetter has no attrs");
    const attrs = attrs_ptr.?;

    const n_attrs = c.py_tuple_len(attrs);

    if (n_attrs == 1) {
        // Single attr - return single value
        const attr = c.py_tuple_getitem(attrs, 0);
        const attr_str = c.py_tostr(attr);
        if (attr_str == null) return c.py_exception(c.tp_TypeError, "attribute name must be string");
        return getNestedAttr(obj, attr_str);
    } else {
        // Multiple attrs - first collect all values, then create tuple
        var values: [16]c.py_TValue = undefined;
        if (n_attrs > 16) {
            return c.py_exception(c.tp_ValueError, "too many attributes");
        }

        var i: c_int = 0;
        while (i < n_attrs) : (i += 1) {
            const attr = c.py_tuple_getitem(attrs, i);
            const attr_str = c.py_tostr(attr);
            if (attr_str == null) return c.py_exception(c.tp_TypeError, "attribute name must be string");
            if (!getNestedAttr(obj, attr_str)) return false;
            values[@intCast(i)] = c.py_retval().*;
        }

        // Now create tuple with collected values
        const result = c.py_newtuple(c.py_retval(), n_attrs);
        i = 0;
        while (i < n_attrs) : (i += 1) {
            result[@intCast(i)] = values[@intCast(i)];
        }
        return true;
    }
}

// methodcaller - creates a callable that calls a method on an object
fn methodcallerNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "methodcaller requires at least one argument");
    }

    // Create instance
    _ = c.py_newobject(c.py_retval(), tp_methodcaller, -1, 0);

    // Store method name
    c.py_setdict(c.py_retval(), c.py_name("_name"), pk.argRef(argv, 1));

    // Store args as a tuple
    const n_args = argc - 2;
    const args = c.py_newtuple(c.py_r0(), n_args);
    var i: usize = 0;
    while (i < @as(usize, @intCast(n_args))) : (i += 1) {
        args[i] = pk.argRef(argv, i + 2).*;
    }
    c.py_setdict(c.py_retval(), c.py_name("_args"), c.py_r0());

    return true;
}

fn methodcallerCall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "methodcaller expected 1 argument");
    }

    const self = pk.argRef(argv, 0);
    const obj = pk.argRef(argv, 1);

    const name_ptr = c.py_getdict(self, c.py_name("_name"));
    if (name_ptr == null) return c.py_exception(c.tp_RuntimeError, "methodcaller has no name");
    const name_str = c.py_tostr(name_ptr.?);
    if (name_str == null) return c.py_exception(c.tp_TypeError, "method name must be string");

    const args_ptr = c.py_getdict(self, c.py_name("_args"));
    if (args_ptr == null) return c.py_exception(c.tp_RuntimeError, "methodcaller has no args");
    const args = args_ptr.?;

    // Get the method
    const name = c.py_name(name_str);
    if (!c.py_getattr(obj, name)) return false;
    var method = c.py_retval().*;

    // Call with stored args
    const n_args = c.py_tuple_len(args);
    if (n_args == 0) {
        return c.py_call(&method, 0, null);
    }

    var call_args: [16]c.py_TValue = undefined;
    if (n_args > 16) {
        return c.py_exception(c.tp_ValueError, "too many arguments");
    }

    var i: c_int = 0;
    while (i < n_args) : (i += 1) {
        call_args[@intCast(i)] = c.py_tuple_getitem(args, i).*;
    }

    return c.py_call(&method, n_args, @ptrCast(&call_args));
}

// length_hint - return estimated length of an object
fn lengthHintFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const obj = pk.argRef(argv, 0);

    // Default value (second argument, defaults to 0)
    var default_val: c.py_i64 = 0;
    if (argc >= 2) {
        const def_arg = pk.argRef(argv, 1);
        if (c.py_isint(def_arg)) {
            default_val = c.py_toint(def_arg);
        }
    }

    // Try __len__ first
    if (c.py_islist(obj)) {
        c.py_newint(c.py_retval(), c.py_list_len(obj));
        return true;
    }
    if (c.py_istuple(obj)) {
        c.py_newint(c.py_retval(), c.py_tuple_len(obj));
        return true;
    }
    if (c.py_isstr(obj)) {
        const sv = c.py_tosv(obj);
        c.py_newint(c.py_retval(), sv.size);
        return true;
    }

    // Return default
    c.py_newint(c.py_retval(), default_val);
    return true;
}

fn callFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) {
        return c.py_exception(c.tp_TypeError, "call() requires at least 1 argument");
    }

    const func = pk.argRef(argv, 0);

    // Build args array (skipping the function itself)
    const n_args = argc - 1;
    if (n_args == 0) {
        return c.py_call(func, 0, null);
    }

    var args: [16]c.py_TValue = undefined;
    if (n_args > 16) {
        return c.py_exception(c.tp_ValueError, "too many arguments");
    }

    var i: usize = 0;
    while (i < @as(usize, @intCast(n_args))) : (i += 1) {
        args[i] = pk.argRef(argv, i + 1).*;
    }

    return c.py_call(func, n_args, @ptrCast(&args));
}

pub fn register() void {
    // Force-import operator module so we can extend it
    if (c.py_import("operator") == 0) {
        c.py_clearexc(null);
        return;
    }

    const module = c.py_getmodule("operator") orelse return;

    c.py_bind(module, "pos(a)", posFn);
    c.py_bind(module, "abs(a)", absFn);
    c.py_bind(module, "index(a)", indexFn);
    c.py_bind(module, "inv(a)", invFn);
    c.py_bind(module, "is_none(a)", isNoneFn);
    c.py_bind(module, "is_not_none(a)", isNotNoneFn);
    c.py_bind(module, "concat(a, b)", concatFn);
    c.py_bind(module, "countOf(a, b)", countOfFn);
    c.py_bind(module, "indexOf(a, b)", indexOfFn);
    c.py_bind(module, "ipow(a, b)", ipowFn);
    c.py_bind(module, "iconcat(a, b)", iconcatFn);
    c.py_bindfunc(module, "call", callFn);
    c.py_bindfunc(module, "length_hint", lengthHintFn);

    // Create itemgetter type
    tp_itemgetter = c.py_newtype("itemgetter", c.tp_object, module, null);
    c.py_bindmagic(tp_itemgetter, c.py_name("__new__"), itemgetterNew);
    c.py_bindmagic(tp_itemgetter, c.py_name("__call__"), itemgetterCall);

    // Create attrgetter type
    tp_attrgetter = c.py_newtype("attrgetter", c.tp_object, module, null);
    c.py_bindmagic(tp_attrgetter, c.py_name("__new__"), attrgetterNew);
    c.py_bindmagic(tp_attrgetter, c.py_name("__call__"), attrgetterCall);

    // Create methodcaller type
    tp_methodcaller = c.py_newtype("methodcaller", c.tp_object, module, null);
    c.py_bindmagic(tp_methodcaller, c.py_name("__new__"), methodcallerNew);
    c.py_bindmagic(tp_methodcaller, c.py_name("__call__"), methodcallerCall);
}
