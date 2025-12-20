const std = @import("std");
const pk = @import("pk");
const c = pk.c;

// Type handles for custom classes
var tp_ordereddict: c.py_Type = 0;

// ============================================================================
// OrderedDict implementation
// We create a custom type with 1 slot for internal dict storage
// and implement dict-like behavior via magic methods
// ============================================================================

fn orderedDictNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    // Create OrderedDict object with 1 slot for the internal dict
    _ = c.py_newobject(c.py_retval(), tp_ordereddict, 1, 0);
    // Initialize the internal dict in slot 0
    c.py_newdict(c.py_r0());
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    return true;
}

// Helper to get internal dict
fn getInternalDict(self: c.py_Ref) c.py_Ref {
    return c.py_getslot(self, 0);
}

fn orderedDictInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getInternalDict(self);

    if (argc > 1) {
        const arg = pk.argRef(argv, 1);

        // If it's a list of tuples, add each one
        if (c.py_islist(arg)) {
            const len = c.py_list_len(arg);
            var i: c_int = 0;
            while (i < len) : (i += 1) {
                const item = c.py_list_getitem(arg, i);
                if (!c.py_istuple(item)) {
                    return c.py_exception(c.tp_TypeError, "OrderedDict requires list of tuples");
                }
                if (c.py_tuple_len(item) != 2) {
                    return c.py_exception(c.tp_ValueError, "OrderedDict tuples must have 2 elements");
                }
                const key = c.py_tuple_getitem(item, 0);
                const val = c.py_tuple_getitem(item, 1);
                _ = c.py_dict_setitem(dict, key, val);
            }
        } else if (c.py_isdict(arg)) {
            // Copy from another dict using py_dict_apply
            const CopyCtx = struct { dest: c.py_Ref };
            const copyFn = struct {
                fn f(key: c.py_Ref, val: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
                    const copy_ctx: *CopyCtx = @ptrCast(@alignCast(ctx.?));
                    _ = c.py_dict_setitem(copy_ctx.dest, key, val);
                    return true;
                }
            }.f;
            var copy_ctx = CopyCtx{ .dest = dict };
            _ = c.py_dict_apply(arg, copyFn, &copy_ctx);
        }
    }

    c.py_newnone(c.py_retval());
    return true;
}

// __len__
fn orderedDictLen(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getInternalDict(self);
    c.py_newint(c.py_retval(), c.py_dict_len(dict));
    return true;
}

// __getitem__
fn orderedDictGetitem(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const dict = getInternalDict(self);
    const res = c.py_dict_getitem(dict, key);
    if (res <= 0) {
        return c.py_exception(c.tp_KeyError, "key not found");
    }
    // py_dict_getitem puts result in py_retval
    return true;
}

// __setitem__
fn orderedDictSetitem(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const val = pk.argRef(argv, 2);
    const dict = getInternalDict(self);
    _ = c.py_dict_setitem(dict, key, val);
    c.py_newnone(c.py_retval());
    return true;
}

// __delitem__
fn orderedDictDelitem(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const dict = getInternalDict(self);
    const res = c.py_dict_delitem(dict, key);
    if (res <= 0) {
        return c.py_exception(c.tp_KeyError, "key not found");
    }
    c.py_newnone(c.py_retval());
    return true;
}

// __contains__
fn orderedDictContains(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const dict = getInternalDict(self);
    const res = c.py_dict_getitem(dict, key);
    c.py_newbool(c.py_retval(), res > 0);
    return true;
}

// __iter__ - iterate over keys
fn orderedDictIter(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getInternalDict(self);
    // Get iterator from the internal dict
    return c.py_iter(dict);
}

// keys()
fn orderedDictKeys(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getInternalDict(self);

    c.py_newlist(c.py_retval());

    const CollectCtx = struct { result: c.py_Ref };
    const collectFn = struct {
        fn f(k: c.py_Ref, _: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
            const collect_ctx: *CollectCtx = @ptrCast(@alignCast(ctx.?));
            c.py_list_append(collect_ctx.result, k);
            return true;
        }
    }.f;

    var collect_ctx = CollectCtx{ .result = c.py_retval() };
    _ = c.py_dict_apply(dict, collectFn, &collect_ctx);

    return true;
}

// values()
fn orderedDictValues(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getInternalDict(self);

    c.py_newlist(c.py_retval());

    const CollectCtx = struct { result: c.py_Ref };
    const collectFn = struct {
        fn f(_: c.py_Ref, v: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
            const collect_ctx: *CollectCtx = @ptrCast(@alignCast(ctx.?));
            c.py_list_append(collect_ctx.result, v);
            return true;
        }
    }.f;

    var collect_ctx = CollectCtx{ .result = c.py_retval() };
    _ = c.py_dict_apply(dict, collectFn, &collect_ctx);

    return true;
}

// items()
fn orderedDictItems(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getInternalDict(self);

    c.py_newlist(c.py_retval());

    const CollectCtx = struct { result: c.py_Ref };
    const collectFn = struct {
        fn f(k: c.py_Ref, v: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
            const collect_ctx: *CollectCtx = @ptrCast(@alignCast(ctx.?));
            const pair = c.py_newtuple(c.py_r0(), 2);
            pair[0] = k.*;
            pair[1] = v.*;
            c.py_list_append(collect_ctx.result, c.py_r0());
            return true;
        }
    }.f;

    var collect_ctx = CollectCtx{ .result = c.py_retval() };
    _ = c.py_dict_apply(dict, collectFn, &collect_ctx);

    return true;
}

// get(key, default=None)
fn orderedDictGet(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const dict = getInternalDict(self);

    const res = c.py_dict_getitem(dict, key);
    if (res > 0) {
        // Result is already in py_retval
        return true;
    }

    // Return default (None if not provided)
    if (argc > 2) {
        c.py_retval().* = pk.argRef(argv, 2).*;
    } else {
        c.py_newnone(c.py_retval());
    }
    return true;
}

fn orderedDictMoveToEnd(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const dict = getInternalDict(self);

    // Default: last=True (move to end)
    var last: bool = true;
    if (argc > 2) {
        const last_arg = pk.argRef(argv, 2);
        if (c.py_isbool(last_arg)) {
            last = c.py_tobool(last_arg);
        }
    }

    // Get the value
    const res = c.py_dict_getitem(dict, key);
    if (res <= 0) {
        return c.py_exception(c.tp_KeyError, "key not in OrderedDict");
    }

    // Store the value
    var val_copy: c.py_TValue = c.py_retval().*;

    // Delete and re-insert to move to end
    const del_res = c.py_dict_delitem(dict, key);
    if (del_res <= 0) return false;

    if (last) {
        // Move to end - just re-add
        _ = c.py_dict_setitem(dict, key, &val_copy);
    } else {
        // Move to beginning - we need to rebuild the dict
        // Collect all current items
        const CollectCtx = struct {
            keys: [256]c.py_TValue = undefined,
            vals: [256]c.py_TValue = undefined,
            count: usize = 0,
        };
        const collectFn = struct {
            fn f(k: c.py_Ref, v: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
                const collect_ctx: *CollectCtx = @ptrCast(@alignCast(ctx.?));
                if (collect_ctx.count >= 256) return true;
                collect_ctx.keys[collect_ctx.count] = k.*;
                collect_ctx.vals[collect_ctx.count] = v.*;
                collect_ctx.count += 1;
                return true;
            }
        }.f;

        var collect_ctx = CollectCtx{};
        _ = c.py_dict_apply(dict, collectFn, &collect_ctx);

        // Clear the dict by deleting each key
        var i: usize = 0;
        while (i < collect_ctx.count) : (i += 1) {
            _ = c.py_dict_delitem(dict, &collect_ctx.keys[i]);
        }

        // Add the moved key first
        _ = c.py_dict_setitem(dict, key, &val_copy);

        // Re-add all other items
        i = 0;
        while (i < collect_ctx.count) : (i += 1) {
            _ = c.py_dict_setitem(dict, &collect_ctx.keys[i], &collect_ctx.vals[i]);
        }
    }

    c.py_newnone(c.py_retval());
    return true;
}

fn orderedDictPopitem(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getInternalDict(self);

    // Default: last=True (pop from end)
    var last: bool = true;
    if (argc > 1) {
        const last_arg = pk.argRef(argv, 1);
        if (c.py_isbool(last_arg)) {
            last = c.py_tobool(last_arg);
        }
    }

    // Check if empty
    if (c.py_dict_len(dict) == 0) {
        return c.py_exception(c.tp_KeyError, "dictionary is empty");
    }

    // Collect all items
    const CollectCtx = struct {
        keys: [256]c.py_TValue = undefined,
        vals: [256]c.py_TValue = undefined,
        count: usize = 0,
    };
    const collectFn = struct {
        fn f(k: c.py_Ref, v: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
            const collect_ctx: *CollectCtx = @ptrCast(@alignCast(ctx.?));
            if (collect_ctx.count >= 256) return true;
            collect_ctx.keys[collect_ctx.count] = k.*;
            collect_ctx.vals[collect_ctx.count] = v.*;
            collect_ctx.count += 1;
            return true;
        }
    }.f;

    var collect_ctx = CollectCtx{};
    _ = c.py_dict_apply(dict, collectFn, &collect_ctx);

    if (collect_ctx.count == 0) {
        return c.py_exception(c.tp_KeyError, "dictionary is empty");
    }

    const idx: usize = if (last) collect_ctx.count - 1 else 0;
    const key = &collect_ctx.keys[idx];
    const val = &collect_ctx.vals[idx];

    // Create result tuple
    const result = c.py_newtuple(c.py_retval(), 2);
    result[0] = key.*;
    result[1] = val.*;

    // Delete the key
    _ = c.py_dict_delitem(dict, key);

    return true;
}

// ============================================================================
// namedtuple implementation
// ============================================================================

fn namedtupleFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "namedtuple requires typename and field_names");
    }

    const typename_arg = pk.argRef(argv, 0);
    const fields_arg = pk.argRef(argv, 1);

    const typename = c.py_tostr(typename_arg);
    if (typename == null) {
        return c.py_exception(c.tp_TypeError, "typename must be a string");
    }

    // Parse field names - either list or space/comma-separated string
    var field_names: [32][*c]const u8 = undefined;
    var n_fields: usize = 0;

    // Static buffers for string parsing
    const State = struct {
        var bufs: [32][64]u8 = undefined;
    };

    if (c.py_islist(fields_arg)) {
        const len = c.py_list_len(fields_arg);
        var i: c_int = 0;
        while (i < len and n_fields < 32) : (i += 1) {
            const item = c.py_list_getitem(fields_arg, i);
            const name = c.py_tostr(item);
            if (name == null) {
                return c.py_exception(c.tp_TypeError, "field names must be strings");
            }
            field_names[n_fields] = name;
            n_fields += 1;
        }
    } else if (c.py_isstr(fields_arg)) {
        // Parse space or comma-separated string
        const sv = c.py_tosv(fields_arg);
        const data: [*]const u8 = @ptrCast(sv.data);
        const len: usize = @intCast(sv.size);

        var start: usize = 0;
        var i: usize = 0;
        while (i <= len and n_fields < 32) : (i += 1) {
            const is_sep = i == len or data[i] == ' ' or data[i] == ',' or data[i] == '\t';
            if (is_sep and i > start) {
                const field_len = i - start;
                if (field_len < 64) {
                    @memcpy(State.bufs[n_fields][0..field_len], data[start..i]);
                    State.bufs[n_fields][field_len] = 0;
                    field_names[n_fields] = @ptrCast(&State.bufs[n_fields]);
                    n_fields += 1;
                }
            }
            if (is_sep) {
                start = i + 1;
            }
        }
    } else if (c.py_istuple(fields_arg)) {
        const len = c.py_tuple_len(fields_arg);
        var i: c_int = 0;
        while (i < len and n_fields < 32) : (i += 1) {
            const item = c.py_tuple_getitem(fields_arg, i);
            const name = c.py_tostr(item);
            if (name == null) {
                return c.py_exception(c.tp_TypeError, "field names must be strings");
            }
            field_names[n_fields] = name;
            n_fields += 1;
        }
    } else {
        return c.py_exception(c.tp_TypeError, "field_names must be a list, tuple, or string");
    }

    // Create a new type dynamically - use object as base since tuple can't be subclassed
    const module = c.py_getmodule("collections") orelse return false;

    // Create type with n_fields + 1 slots (slot 0 stores internal tuple for values)
    const new_type = c.py_newtype(typename, c.tp_object, module, null);

    // Store field names as _fields tuple on the type
    const fields_tuple = c.py_newtuple(c.py_r0(), @intCast(n_fields));
    var i: usize = 0;
    while (i < n_fields) : (i += 1) {
        c.py_newstr(c.py_r1(), field_names[i]);
        fields_tuple[i] = c.py_r1().*;
    }
    c.py_setdict(c.py_tpobject(new_type), c.py_name("_fields"), c.py_r0());

    // Store field count
    c.py_newint(c.py_r0(), @intCast(n_fields));
    c.py_setdict(c.py_tpobject(new_type), c.py_name("_n_fields"), c.py_r0());

    // Bind magic methods for tuple-like behavior
    c.py_bindmagic(new_type, c.py_name("__new__"), namedtupleInstanceNew);
    c.py_bindmagic(new_type, c.py_name("__getitem__"), namedtupleGetitem);
    c.py_bindmagic(new_type, c.py_name("__len__"), namedtupleLen);
    c.py_bindmagic(new_type, c.py_name("__iter__"), namedtupleIter);
    c.py_bindmethod(new_type, "_asdict", namedtupleAsdict);
    c.py_bindmethod(new_type, "_replace", namedtupleReplace);

    // Return the new type
    c.py_retval().* = c.py_tpobject(new_type).*;
    return true;
}

fn namedtupleInstanceNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const cls = pk.argRef(argv, 0);

    // Get the type from the class object
    const tp = c.py_totype(cls);

    // Get _n_fields from the type
    const n_fields_ptr = c.py_getdict(cls, c.py_name("_n_fields"));
    if (n_fields_ptr == null) {
        return c.py_exception(c.tp_TypeError, "not a namedtuple type");
    }
    const n_fields: c_int = @intCast(c.py_toint(n_fields_ptr.?));

    // Get _fields for attribute access
    const fields_ptr = c.py_getdict(cls, c.py_name("_fields"));

    // Create a namedtuple instance with dynamic dict (-1 slots)
    _ = c.py_newobject(c.py_retval(), tp, -1, 0);

    // Create the internal tuple with the values
    const internal_tuple = c.py_newtuple(c.py_r0(), n_fields);

    // Fill in positional args
    var i: c_int = 0;
    const pos_args = argc - 1;
    while (i < pos_args and i < n_fields) : (i += 1) {
        internal_tuple[@intCast(i)] = pk.argRef(argv, @intCast(@as(usize, @intCast(i)) + 1)).*;
    }

    // Fill remaining with None (shouldn't happen normally)
    while (i < n_fields) : (i += 1) {
        c.py_newnone(c.py_r1());
        internal_tuple[@intCast(i)] = c.py_r1().*;
    }

    // Store internal tuple as _values attribute
    c.py_setdict(c.py_retval(), c.py_name("_values"), c.py_r0());

    // Set up attribute access for field names
    if (fields_ptr != null) {
        i = 0;
        while (i < n_fields) : (i += 1) {
            const field_name = c.py_tuple_getitem(fields_ptr.?, i);
            const field_str = c.py_tostr(field_name);
            if (field_str != null) {
                // Store value as attribute
                c.py_setdict(c.py_retval(), c.py_name(field_str), c.py_tuple_getitem(c.py_r0(), i));
            }
        }
    }

    return true;
}

// Helper to get internal tuple from namedtuple instance
fn getNamedtupleTuple(self: c.py_Ref) c.py_Ref {
    const vals = c.py_getdict(self, c.py_name("_values"));
    if (vals == null) return self; // fallback
    return vals.?;
}

fn namedtupleGetitem(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const idx_arg = pk.argRef(argv, 1);

    if (!c.py_isint(idx_arg)) {
        return c.py_exception(c.tp_TypeError, "indices must be integers");
    }

    const internal = getNamedtupleTuple(self);
    const len = c.py_tuple_len(internal);
    var idx = c.py_toint(idx_arg);

    // Handle negative indices
    if (idx < 0) {
        idx = idx + len;
    }

    if (idx < 0 or idx >= len) {
        return c.py_exception(c.tp_IndexError, "tuple index out of range");
    }

    c.py_retval().* = c.py_tuple_getitem(internal, @intCast(idx)).*;
    return true;
}

fn namedtupleLen(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const internal = getNamedtupleTuple(self);
    c.py_newint(c.py_retval(), c.py_tuple_len(internal));
    return true;
}

fn namedtupleIter(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const internal = getNamedtupleTuple(self);
    // Return iterator over the internal tuple
    return c.py_iter(internal);
}

fn namedtupleAsdict(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    // Get _fields from the type
    const tp = c.py_typeof(self);
    const tp_obj = c.py_tpobject(tp);
    const fields_ptr = c.py_getdict(tp_obj, c.py_name("_fields"));
    if (fields_ptr == null) {
        return c.py_exception(c.tp_TypeError, "not a namedtuple");
    }

    const internal = getNamedtupleTuple(self);
    const n_fields = c.py_tuple_len(fields_ptr.?);

    // Create dict
    c.py_newdict(c.py_retval());

    var i: c_int = 0;
    while (i < n_fields) : (i += 1) {
        const key = c.py_tuple_getitem(fields_ptr.?, i);
        const val = c.py_tuple_getitem(internal, i);
        _ = c.py_dict_setitem(c.py_retval(), key, val);
    }

    return true;
}

fn namedtupleReplace(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    // Get type info
    const tp = c.py_typeof(self);
    const tp_obj = c.py_tpobject(tp);
    const fields_ptr = c.py_getdict(tp_obj, c.py_name("_fields"));
    if (fields_ptr == null) {
        return c.py_exception(c.tp_TypeError, "not a namedtuple");
    }

    const internal = getNamedtupleTuple(self);
    const n_fields = c.py_tuple_len(fields_ptr.?);

    // Create new namedtuple instance with dynamic dict
    _ = c.py_newobject(c.py_retval(), tp, -1, 0);

    // Create new internal tuple
    const new_tuple = c.py_newtuple(c.py_r0(), n_fields);

    // Copy values from self, checking for replacements
    var i: c_int = 0;
    while (i < n_fields) : (i += 1) {
        const val = c.py_tuple_getitem(internal, i);
        new_tuple[@intCast(i)] = val.*;

        // Check if replacement provided via extra args (kwargs as dict)
        if (argc > 1) {
            const kwargs = pk.argRef(argv, 1);
            if (c.py_isdict(kwargs)) {
                const field_name = c.py_tuple_getitem(fields_ptr.?, i);
                const res = c.py_dict_getitem(kwargs, field_name);
                if (res > 0) {
                    new_tuple[@intCast(i)] = c.py_retval().*;
                }
            }
        }
    }

    // Store internal tuple as _values
    c.py_setdict(c.py_retval(), c.py_name("_values"), c.py_r0());

    // Set up attribute access for field names
    i = 0;
    while (i < n_fields) : (i += 1) {
        const field_name = c.py_tuple_getitem(fields_ptr.?, i);
        const field_str = c.py_tostr(field_name);
        if (field_str != null) {
            c.py_setdict(c.py_retval(), c.py_name(field_str), c.py_tuple_getitem(c.py_r0(), i));
        }
    }

    return true;
}

// ============================================================================
// Counter enhancements
// ============================================================================

fn counterMostCommon(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    // Default n = all items
    var n: c_int = -1;
    if (argc > 1) {
        const n_arg = pk.argRef(argv, 1);
        if (c.py_isint(n_arg)) {
            n = @intCast(c.py_toint(n_arg));
        }
    }

    // Collect all items using py_dict_apply
    const CollectCtx = struct {
        keys: [256]c.py_TValue = undefined,
        vals: [256]c.py_i64 = undefined,
        count: usize = 0,
    };
    const collectFn = struct {
        fn f(k: c.py_Ref, v: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
            const collect_ctx: *CollectCtx = @ptrCast(@alignCast(ctx.?));
            if (collect_ctx.count >= 256) return true;
            collect_ctx.keys[collect_ctx.count] = k.*;
            if (c.py_isint(v)) {
                collect_ctx.vals[collect_ctx.count] = c.py_toint(v);
            } else {
                collect_ctx.vals[collect_ctx.count] = 0;
            }
            collect_ctx.count += 1;
            return true;
        }
    }.f;

    var collect_ctx = CollectCtx{};
    _ = c.py_dict_apply(self, collectFn, &collect_ctx);

    // Sort by count descending (simple bubble sort for small lists)
    var i: usize = 0;
    while (i < collect_ctx.count) : (i += 1) {
        var j: usize = i + 1;
        while (j < collect_ctx.count) : (j += 1) {
            if (collect_ctx.vals[j] > collect_ctx.vals[i]) {
                const tmp_key = collect_ctx.keys[i];
                const tmp_val = collect_ctx.vals[i];
                collect_ctx.keys[i] = collect_ctx.keys[j];
                collect_ctx.vals[i] = collect_ctx.vals[j];
                collect_ctx.keys[j] = tmp_key;
                collect_ctx.vals[j] = tmp_val;
            }
        }
    }

    // Determine how many to return
    const result_count: usize = if (n < 0 or @as(usize, @intCast(n)) > collect_ctx.count) collect_ctx.count else @intCast(n);

    // Build result list
    c.py_newlist(c.py_retval());
    i = 0;
    while (i < result_count) : (i += 1) {
        const pair = c.py_newtuple(c.py_r0(), 2);
        pair[0] = collect_ctx.keys[i];
        c.py_newint(c.py_r1(), collect_ctx.vals[i]);
        pair[1] = c.py_r1().*;
        c.py_list_append(c.py_retval(), c.py_r0());
    }

    return true;
}

fn counterElements(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    // Build a list with each element repeated by its count
    c.py_newlist(c.py_retval());

    const AppendCtx = struct { result: c.py_Ref };
    const appendFn = struct {
        fn f(k: c.py_Ref, v: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
            const append_ctx: *AppendCtx = @ptrCast(@alignCast(ctx.?));
            if (c.py_isint(v)) {
                const count_val = c.py_toint(v);
                var i: c.py_i64 = 0;
                while (i < count_val) : (i += 1) {
                    c.py_list_append(append_ctx.result, k);
                }
            }
            return true;
        }
    }.f;

    var append_ctx = AppendCtx{ .result = c.py_retval() };
    _ = c.py_dict_apply(self, appendFn, &append_ctx);

    return true;
}

fn counterSubtract(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "subtract requires an argument");
    }

    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);

    if (!c.py_isdict(other)) {
        return c.py_exception(c.tp_TypeError, "subtract requires a Counter or dict");
    }

    // Subtract counts using py_dict_apply
    const SubCtx = struct { self_ref: c.py_Ref };
    const subFn = struct {
        fn f(k: c.py_Ref, v: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
            const sub_ctx: *SubCtx = @ptrCast(@alignCast(ctx.?));
            if (!c.py_isint(v)) return true;

            const sub_count = c.py_toint(v);
            const existing_res = c.py_dict_getitem(sub_ctx.self_ref, k);

            var new_count: c.py_i64 = -sub_count;
            if (existing_res > 0) {
                const existing = c.py_retval();
                if (c.py_isint(existing)) {
                    new_count = c.py_toint(existing) - sub_count;
                }
            }

            c.py_newint(c.py_r0(), new_count);
            _ = c.py_dict_setitem(sub_ctx.self_ref, k, c.py_r0());
            return true;
        }
    }.f;

    var sub_ctx = SubCtx{ .self_ref = self };
    _ = c.py_dict_apply(other, subFn, &sub_ctx);

    c.py_newnone(c.py_retval());
    return true;
}

pub fn register() void {
    // Force-import collections module so we can extend it
    if (c.py_import("collections") == 0) {
        c.py_clearexc(null);
        return;
    }

    const module = c.py_getmodule("collections") orelse return;

    // Add namedtuple function
    c.py_bind(module, "namedtuple(typename, field_names)", namedtupleFn);

    // Create OrderedDict type with 1 slot for internal dict
    tp_ordereddict = c.py_newtype("OrderedDict", c.tp_object, module, null);
    c.py_bindmagic(tp_ordereddict, c.py_name("__new__"), orderedDictNew);
    c.py_bindmagic(tp_ordereddict, c.py_name("__init__"), orderedDictInit);
    c.py_bindmagic(tp_ordereddict, c.py_name("__len__"), orderedDictLen);
    c.py_bindmagic(tp_ordereddict, c.py_name("__getitem__"), orderedDictGetitem);
    c.py_bindmagic(tp_ordereddict, c.py_name("__setitem__"), orderedDictSetitem);
    c.py_bindmagic(tp_ordereddict, c.py_name("__delitem__"), orderedDictDelitem);
    c.py_bindmagic(tp_ordereddict, c.py_name("__contains__"), orderedDictContains);
    c.py_bindmagic(tp_ordereddict, c.py_name("__iter__"), orderedDictIter);
    c.py_bindmethod(tp_ordereddict, "keys", orderedDictKeys);
    c.py_bindmethod(tp_ordereddict, "values", orderedDictValues);
    c.py_bindmethod(tp_ordereddict, "items", orderedDictItems);
    c.py_bindmethod(tp_ordereddict, "get", orderedDictGet);
    c.py_bindmethod(tp_ordereddict, "move_to_end", orderedDictMoveToEnd);
    c.py_bindmethod(tp_ordereddict, "popitem", orderedDictPopitem);

    // Get Counter type and enhance it
    const counter_ptr = c.py_getdict(module, c.py_name("Counter"));
    if (counter_ptr != null) {
        // Counter is stored as a type object - use py_typeof to check, then get type
        const counter_type = c.py_typeof(counter_ptr.?);
        if (counter_type == c.tp_type) {
            // It's a type object, we can get the py_Type value
            const counter_tp = c.py_totype(counter_ptr.?);
            c.py_bindmethod(counter_tp, "most_common", counterMostCommon);
            c.py_bindmethod(counter_tp, "elements", counterElements);
            c.py_bindmethod(counter_tp, "subtract", counterSubtract);
        }
    }
}
