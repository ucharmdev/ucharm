const std = @import("std");
const pk = @import("pk");
const c = pk.c;

// Type handles for custom classes
var tp_ordereddict: c.py_Type = 0;
var tp_counter: c.py_Type = 0;
var tp_defaultdict: c.py_Type = 0;

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
    const dict = getCounterDict(self);

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
    _ = c.py_dict_apply(dict, collectFn, &collect_ctx);

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
    const dict = getCounterDict(self);

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
    _ = c.py_dict_apply(dict, appendFn, &append_ctx);

    return true;
}

fn counterSubtract(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "subtract requires an argument");
    }

    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);

    const self_dict = getCounterDict(self);

    const other_dict: c.py_Ref = if (c.py_isdict(other)) other else if (c.py_istype(other, tp_counter)) getCounterDict(other) else return c.py_exception(c.tp_TypeError, "subtract requires a Counter or dict");

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

    var sub_ctx = SubCtx{ .self_ref = self_dict };
    _ = c.py_dict_apply(other_dict, subFn, &sub_ctx);

    c.py_newnone(c.py_retval());
    return true;
}

// ============================================================================
// Proper Counter implementation as a class
// ============================================================================

fn getCounterDict(self: c.py_Ref) c.py_Ref {
    return c.py_getslot(self, 0);
}

fn counterNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_counter, 1, 0);
    c.py_newdict(c.py_r0());
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    return true;
}

fn counterNewKwargs(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    // Signature-bound __new__ so the Counter constructor can accept kwargs.
    _ = c.py_newobject(c.py_retval(), tp_counter, 1, 0);
    c.py_newdict(c.py_r0());
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    return true;
}

fn counterInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    // Reset any existing state
    c.py_newdict(c.py_r0());
    c.py_setslot(self, 0, c.py_r0());
    const dict = getCounterDict(self);

    if (argc > 1) {
        const arg = pk.argRef(argv, 1);

        if (c.py_islist(arg)) {
            // Count elements in list
            const len = c.py_list_len(arg);
            var i: c_int = 0;
            while (i < len) : (i += 1) {
                const item = c.py_list_getitem(arg, i);
                const res = c.py_dict_getitem(dict, item);
                var count: c.py_i64 = 1;
                if (res > 0) {
                    count = c.py_toint(c.py_retval()) + 1;
                }
                c.py_newint(c.py_r0(), count);
                _ = c.py_dict_setitem(dict, item, c.py_r0());
            }
        } else if (c.py_isstr(arg)) {
            // Count characters in string
            const sv = c.py_tosv(arg);
            const data: [*]const u8 = @ptrCast(sv.data);
            const len: usize = @intCast(sv.size);
            var i: usize = 0;
            while (i < len) : (i += 1) {
                // Create single-char string as key
                const char_str = c.py_newstrn(c.py_r0(), 1);
                char_str[0] = data[i];

                const res = c.py_dict_getitem(dict, c.py_r0());
                var count: c.py_i64 = 1;
                if (res > 0) {
                    count = c.py_toint(c.py_retval()) + 1;
                }
                c.py_newint(c.py_r1(), count);
                _ = c.py_dict_setitem(dict, c.py_r0(), c.py_r1());
            }
        } else if (c.py_isdict(arg)) {
            // Copy from dict
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

fn counterInitKwargs(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    // Always reset state (CPython reinitializes on __init__ call)
    c.py_newdict(c.py_r0());
    c.py_setslot(self, 0, c.py_r0());
    const dict = getCounterDict(self);

    // Signature binding is expected to pass:
    //   __init__(self, iterable=None, **kwargs)
    // but be defensive about argv layout.
    var iterable: ?c.py_Ref = null;
    var kwargs: ?c.py_Ref = null;

    if (argc >= 2) {
        const a1 = pk.argRef(argv, 1);
        if (c.py_isdict(a1) and (argc == 2)) {
            // Some call paths may pass only kwargs dict
            kwargs = a1;
        } else if (!c.py_isnone(a1) and !c.py_isnil(a1)) {
            iterable = a1;
        }
    }
    if (argc >= 3) {
        const a2 = pk.argRef(argv, 2);
        if (c.py_isdict(a2)) kwargs = a2;
    }

    if (iterable) |arg| {
        if (c.py_islist(arg)) {
            // Count elements in list
            const len = c.py_list_len(arg);
            var i: c_int = 0;
            while (i < len) : (i += 1) {
                const item = c.py_list_getitem(arg, i);
                const res = c.py_dict_getitem(dict, item);
                var count: c.py_i64 = 1;
                if (res > 0) {
                    count = c.py_toint(c.py_retval()) + 1;
                }
                c.py_newint(c.py_r0(), count);
                _ = c.py_dict_setitem(dict, item, c.py_r0());
            }
        } else if (c.py_isstr(arg)) {
            // Count characters in string
            const sv = c.py_tosv(arg);
            const data: [*]const u8 = @ptrCast(sv.data);
            const len: usize = @intCast(sv.size);
            var i: usize = 0;
            while (i < len) : (i += 1) {
                const char_str = c.py_newstrn(c.py_r0(), 1);
                char_str[0] = data[i];

                const res = c.py_dict_getitem(dict, c.py_r0());
                var count: c.py_i64 = 1;
                if (res > 0) {
                    count = c.py_toint(c.py_retval()) + 1;
                }
                c.py_newint(c.py_r1(), count);
                _ = c.py_dict_setitem(dict, c.py_r0(), c.py_r1());
            }
        } else if (c.py_isdict(arg)) {
            // Copy from dict (mapping of item->count)
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

    if (kwargs) |kw| {
        const KwCtx = struct { dest: c.py_Ref };
        const kwFn = struct {
            fn f(key: c.py_Ref, val: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
                const kw_ctx: *KwCtx = @ptrCast(@alignCast(ctx.?));
                _ = c.py_dict_setitem(kw_ctx.dest, key, val);
                return true;
            }
        }.f;
        var kw_ctx = KwCtx{ .dest = dict };
        _ = c.py_dict_apply(kw, kwFn, &kw_ctx);
    }

    c.py_newnone(c.py_retval());
    return true;
}

fn counterGetitem(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const dict = getCounterDict(self);

    const res = c.py_dict_getitem(dict, key);
    if (res > 0) {
        return true;
    }
    // Missing key returns 0 for Counter
    c.py_newint(c.py_retval(), 0);
    return true;
}

fn counterSetitem(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const val = pk.argRef(argv, 2);
    const dict = getCounterDict(self);
    _ = c.py_dict_setitem(dict, key, val);
    c.py_newnone(c.py_retval());
    return true;
}

fn counterLen(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getCounterDict(self);
    c.py_newint(c.py_retval(), c.py_dict_len(dict));
    return true;
}

fn counterIter(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getCounterDict(self);
    return c.py_iter(dict);
}

fn counterRepr(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getCounterDict(self);

    // Build "Counter({...})" string
    var buffer: [4096]u8 = undefined;
    var pos: usize = 0;

    @memcpy(buffer[pos .. pos + 9], "Counter({");
    pos += 9;

    var first: bool = true;
    const FormatCtx = struct {
        buf: *[4096]u8,
        pos: *usize,
        first: *bool,
    };
    const formatFn = struct {
        fn f(k: c.py_Ref, v: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
            const fmt_ctx: *FormatCtx = @ptrCast(@alignCast(ctx.?));
            if (fmt_ctx.pos.* >= 4080) return true;

            if (!fmt_ctx.first.*) {
                @memcpy(fmt_ctx.buf[fmt_ctx.pos.* .. fmt_ctx.pos.* + 2], ", ");
                fmt_ctx.pos.* += 2;
            }
            fmt_ctx.first.* = false;

            // Format key
            if (c.py_isstr(k)) {
                fmt_ctx.buf[fmt_ctx.pos.*] = '\'';
                fmt_ctx.pos.* += 1;
                const sv = c.py_tosv(k);
                const key_len: usize = @intCast(sv.size);
                const max_len = @min(key_len, 4080 - fmt_ctx.pos.*);
                @memcpy(fmt_ctx.buf[fmt_ctx.pos.* .. fmt_ctx.pos.* + max_len], @as([*]const u8, @ptrCast(sv.data))[0..max_len]);
                fmt_ctx.pos.* += max_len;
                fmt_ctx.buf[fmt_ctx.pos.*] = '\'';
                fmt_ctx.pos.* += 1;
            } else if (c.py_isint(k)) {
                const key_int = c.py_toint(k);
                const result = std.fmt.bufPrint(fmt_ctx.buf[fmt_ctx.pos.*..], "{d}", .{key_int}) catch return true;
                fmt_ctx.pos.* += result.len;
            }

            @memcpy(fmt_ctx.buf[fmt_ctx.pos.* .. fmt_ctx.pos.* + 2], ": ");
            fmt_ctx.pos.* += 2;

            // Format value
            if (c.py_isint(v)) {
                const val_int = c.py_toint(v);
                const result = std.fmt.bufPrint(fmt_ctx.buf[fmt_ctx.pos.*..], "{d}", .{val_int}) catch return true;
                fmt_ctx.pos.* += result.len;
            }

            return true;
        }
    }.f;

    var fmt_ctx = FormatCtx{ .buf = &buffer, .pos = &pos, .first = &first };
    _ = c.py_dict_apply(dict, formatFn, &fmt_ctx);

    @memcpy(buffer[pos .. pos + 2], "})");
    pos += 2;

    const out = c.py_newstrn(c.py_retval(), @intCast(pos));
    @memcpy(out[0..pos], buffer[0..pos]);
    return true;
}

fn counterUpdate(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        c.py_newnone(c.py_retval());
        return true;
    }

    const self = pk.argRef(argv, 0);
    const arg = pk.argRef(argv, 1);
    const dict = getCounterDict(self);

    if (c.py_islist(arg)) {
        // Count elements in list
        const len = c.py_list_len(arg);
        var i: c_int = 0;
        while (i < len) : (i += 1) {
            const item = c.py_list_getitem(arg, i);
            const res = c.py_dict_getitem(dict, item);
            var count: c.py_i64 = 1;
            if (res > 0) {
                count = c.py_toint(c.py_retval()) + 1;
            }
            c.py_newint(c.py_r0(), count);
            _ = c.py_dict_setitem(dict, item, c.py_r0());
        }
    } else if (c.py_isdict(arg)) {
        // Add counts from dict
        const AddCtx = struct { dest: c.py_Ref };
        const addFn = struct {
            fn f(key: c.py_Ref, val: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
                const add_ctx: *AddCtx = @ptrCast(@alignCast(ctx.?));
                if (!c.py_isint(val)) return true;
                const add_count = c.py_toint(val);
                const res = c.py_dict_getitem(add_ctx.dest, key);
                var new_count = add_count;
                if (res > 0) {
                    new_count += c.py_toint(c.py_retval());
                }
                c.py_newint(c.py_r0(), new_count);
                _ = c.py_dict_setitem(add_ctx.dest, key, c.py_r0());
                return true;
            }
        }.f;
        var add_ctx = AddCtx{ .dest = dict };
        _ = c.py_dict_apply(arg, addFn, &add_ctx);
    }

    c.py_newnone(c.py_retval());
    return true;
}

// ============================================================================
// Proper defaultdict implementation as a class
// ============================================================================

fn getDefaultdictDict(self: c.py_Ref) c.py_Ref {
    return c.py_getslot(self, 0);
}

fn getDefaultdictFactory(self: c.py_Ref) c.py_Ref {
    return c.py_getslot(self, 1);
}

fn defaultdictNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_defaultdict, 2, 0);
    c.py_newdict(c.py_r0());
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    c.py_newnone(c.py_r0());
    c.py_setslot(c.py_retval(), 1, c.py_r0());
    return true;
}

fn defaultdictInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    if (argc > 1) {
        const factory = pk.argRef(argv, 1);
        c.py_setslot(self, 1, factory);
    }

    c.py_newnone(c.py_retval());
    return true;
}

fn defaultdictGetitem(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const dict = getDefaultdictDict(self);

    const res = c.py_dict_getitem(dict, key);
    if (res > 0) {
        return true;
    }

    // Key not found - call factory if available
    const factory = getDefaultdictFactory(self);
    if (c.py_isnil(factory) or c.py_isnone(factory)) {
        return c.py_exception(c.tp_KeyError, "key not found");
    }

    // Call the factory with py_call (takes pointer to TValue)
    var factory_copy: c.py_TValue = factory.*;
    if (!c.py_call(&factory_copy, 0, null)) {
        return false;
    }

    // Store the result in the dict
    var result_copy: c.py_TValue = c.py_retval().*;
    _ = c.py_dict_setitem(dict, key, &result_copy);
    c.py_retval().* = result_copy;
    return true;
}

fn defaultdictSetitem(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const val = pk.argRef(argv, 2);
    const dict = getDefaultdictDict(self);
    _ = c.py_dict_setitem(dict, key, val);
    c.py_newnone(c.py_retval());
    return true;
}

fn defaultdictLen(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getDefaultdictDict(self);
    c.py_newint(c.py_retval(), c.py_dict_len(dict));
    return true;
}

fn defaultdictContains(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const key = pk.argRef(argv, 1);
    const dict = getDefaultdictDict(self);
    const res = c.py_dict_getitem(dict, key);
    c.py_newbool(c.py_retval(), res > 0);
    return true;
}

fn defaultdictIter(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const dict = getDefaultdictDict(self);
    return c.py_iter(dict);
}

fn defaultdictDefaultFactory(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    c.py_retval().* = getDefaultdictFactory(self).*;
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

    // Create Counter type (replaces PocketPy's function-based Counter)
    tp_counter = c.py_newtype("Counter", c.tp_object, module, null);
    // Use signature-bound __new__/__init__ so Counter(...) supports kwargs.
    c.py_bind(c.py_tpobject(tp_counter), "__new__(cls, iterable=None, **kwargs)", counterNewKwargs);
    c.py_bind(c.py_tpobject(tp_counter), "__init__(self, iterable=None, **kwargs)", counterInitKwargs);
    c.py_bindmagic(tp_counter, c.py_name("__len__"), counterLen);
    c.py_bindmagic(tp_counter, c.py_name("__getitem__"), counterGetitem);
    c.py_bindmagic(tp_counter, c.py_name("__setitem__"), counterSetitem);
    c.py_bindmagic(tp_counter, c.py_name("__iter__"), counterIter);
    c.py_bindmagic(tp_counter, c.py_name("__repr__"), counterRepr);
    c.py_bindmethod(tp_counter, "most_common", counterMostCommon);
    c.py_bindmethod(tp_counter, "elements", counterElements);
    c.py_bindmethod(tp_counter, "subtract", counterSubtract);
    c.py_bindmethod(tp_counter, "update", counterUpdate);

    // Create defaultdict type (replaces PocketPy's function-based defaultdict)
    tp_defaultdict = c.py_newtype("defaultdict", c.tp_object, module, null);
    c.py_bindmagic(tp_defaultdict, c.py_name("__new__"), defaultdictNew);
    c.py_bindmagic(tp_defaultdict, c.py_name("__init__"), defaultdictInit);
    c.py_bindmagic(tp_defaultdict, c.py_name("__len__"), defaultdictLen);
    c.py_bindmagic(tp_defaultdict, c.py_name("__getitem__"), defaultdictGetitem);
    c.py_bindmagic(tp_defaultdict, c.py_name("__setitem__"), defaultdictSetitem);
    c.py_bindmagic(tp_defaultdict, c.py_name("__contains__"), defaultdictContains);
    c.py_bindmagic(tp_defaultdict, c.py_name("__iter__"), defaultdictIter);
    c.py_bindproperty(tp_defaultdict, "default_factory", defaultdictDefaultFactory, null);
}
