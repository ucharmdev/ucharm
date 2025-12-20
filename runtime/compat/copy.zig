/// copy.zig - Python copy module implementation
///
/// Provides copy() for shallow copies and deepcopy() for deep copies.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

/// Shallow copy - copies the object but not nested objects
fn copyFn(ctx: *pk.Context) bool {
    var obj = ctx.arg(0) orelse return ctx.typeError("copy() requires 1 argument");

    // Immutable types - return same object
    if (obj.isNone() or obj.isBool() or obj.isInt() or obj.isFloat() or obj.isStr()) {
        return ctx.returnValue(obj);
    }

    // Tuples are immutable - return same object
    if (obj.isTuple()) {
        return ctx.returnValue(obj);
    }

    // List - create shallow copy
    if (obj.isList()) {
        c.py_newlist(c.py_retval());
        const new_list = c.py_retval();
        const len = c.py_list_len(obj.refConst());
        var i: c_int = 0;
        while (i < len) : (i += 1) {
            const item = c.py_list_getitem(obj.refConst(), i);
            c.py_list_append(new_list, item);
        }
        return true;
    }

    // Dict - create shallow copy using py_dict_apply
    if (obj.isDict()) {
        c.py_newdict(c.py_retval());

        const CopyCtx = struct {
            dest: c.py_Ref,
        };
        var copy_ctx = CopyCtx{ .dest = c.py_retval() };

        const copyItemFn = struct {
            fn f(key: c.py_Ref, val: c.py_Ref, ctx_ptr: ?*anyopaque) callconv(.c) bool {
                const copy_ptr: *CopyCtx = @ptrCast(@alignCast(ctx_ptr));
                _ = c.py_dict_setitem(copy_ptr.dest, key, val);
                return true;
            }
        }.f;

        _ = c.py_dict_apply(obj.refConst(), copyItemFn, &copy_ctx);
        return true;
    }

    // Try calling the type constructor with the object (handles set, frozenset, bytearray, etc.)
    const obj_type = c.py_typeof(obj.refConst());
    var args = [_]c.py_TValue{obj.val};
    if (c.py_call(c.py_tpobject(obj_type), 1, &args)) {
        return true;
    }
    // Clear the exception from failed call
    c.py_clearexc(null);

    // For other objects, try to call __copy__ method
    var copy_method = obj.getAttr("__copy__");
    if (copy_method != null) {
        const result = copy_method.?.call0();
        if (result != null) {
            return ctx.returnValue(result.?);
        }
        return false; // Exception was raised
    }

    return ctx.typeError("object does not support copy");
}

/// Context for deep copy operations
const DeepCopyCtx = struct {
    memo: c.py_Ref,
    success: bool,
};

/// Deep copy a single value, returning true on success
fn deepcopyValue(obj_ref: c.py_Ref, memo: c.py_Ref) bool {
    var obj = pk.Value.from(obj_ref);

    // Immutable types - return same object
    if (obj.isNone() or obj.isBool() or obj.isInt() or obj.isFloat() or obj.isStr()) {
        c.py_push(obj_ref);
        return true;
    }

    // Tuples - need to deepcopy contents
    if (obj.isTuple()) {
        const len = c.py_tuple_len(obj_ref);
        _ = c.py_newtuple(c.py_retval(), len);

        var i: c_int = 0;
        while (i < len) : (i += 1) {
            const item = c.py_tuple_getitem(obj_ref, i);
            if (!deepcopyValue(item, memo)) return false;
            c.py_tuple_setitem(c.py_retval(), i, c.py_peek(-1));
            c.py_pop();
        }
        c.py_push(c.py_retval());
        return true;
    }

    // List - deepcopy contents
    if (obj.isList()) {
        c.py_newlist(c.py_retval());
        c.py_push(c.py_retval()); // Push new list to protect it

        const len = c.py_list_len(obj_ref);
        var i: c_int = 0;
        while (i < len) : (i += 1) {
            const item = c.py_list_getitem(obj_ref, i);
            if (!deepcopyValue(item, memo)) {
                c.py_pop(); // Pop new list
                return false;
            }
            c.py_list_append(c.py_peek(-2), c.py_peek(-1));
            c.py_pop(); // Pop deepcopied item
        }
        // New list is still on stack
        return true;
    }

    // Dict - deepcopy contents using callbacks
    if (obj.isDict()) {
        c.py_newdict(c.py_retval());
        c.py_push(c.py_retval()); // Push new dict to protect it

        var deep_ctx = DeepCopyCtx{
            .memo = memo,
            .success = true,
        };

        const deepcopyItemFn = struct {
            fn f(key: c.py_Ref, val: c.py_Ref, ctx_ptr: ?*anyopaque) callconv(.c) bool {
                const dc: *DeepCopyCtx = @ptrCast(@alignCast(ctx_ptr));
                if (!dc.success) return false;

                // Deepcopy the key
                if (!deepcopyValue(key, dc.memo)) {
                    dc.success = false;
                    return false;
                }
                // Key is on stack

                // Deepcopy the value
                if (!deepcopyValue(val, dc.memo)) {
                    c.py_pop(); // Pop key
                    dc.success = false;
                    return false;
                }
                // Value is on stack, key below it

                // The new dict is at peek(-3)
                _ = c.py_dict_setitem(c.py_peek(-3), c.py_peek(-2), c.py_peek(-1));
                c.py_pop(); // Pop value
                c.py_pop(); // Pop key
                return true;
            }
        }.f;

        _ = c.py_dict_apply(obj_ref, deepcopyItemFn, &deep_ctx);
        if (!deep_ctx.success) {
            c.py_pop(); // Pop new dict
            return false;
        }
        // New dict is still on stack
        return true;
    }

    // For other objects, try __deepcopy__ method
    var deepcopy_method = obj.getAttr("__deepcopy__");
    if (deepcopy_method != null) {
        var memo_val = pk.Value.from(memo);
        var result = deepcopy_method.?.call1(&memo_val);
        if (result != null) {
            c.py_push(result.?.refConst());
            return true;
        }
        return false;
    }

    // Try __copy__ as fallback
    var copy_method = obj.getAttr("__copy__");
    if (copy_method != null) {
        var result = copy_method.?.call0();
        if (result != null) {
            c.py_push(result.?.refConst());
            return true;
        }
        return false;
    }

    // For unknown types, return the same object
    c.py_push(obj_ref);
    return true;
}

fn deepcopyFn(ctx: *pk.Context) bool {
    var obj = ctx.arg(0) orelse return ctx.typeError("deepcopy() requires 1 argument");

    // Create memo dict for circular reference handling
    var memo: c.py_TValue = undefined;
    c.py_newdict(&memo);

    if (!deepcopyValue(obj.refConst(), &memo)) {
        return false;
    }

    // Result is on stack - copy to retval
    c.py_retval().* = c.py_peek(-1).*;
    c.py_pop();
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("copy");
    _ = builder
        .funcSigWrapped("copy(x)", 1, 1, copyFn)
        .funcSigWrapped("deepcopy(x, memo=None)", 1, 2, deepcopyFn);

    // Add Error exception (just use RuntimeError for now)
    c.py_setdict(builder.getModule(), c.py_name("Error"), c.py_tpobject(c.tp_RuntimeError));
}
