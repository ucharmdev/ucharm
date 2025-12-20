const pk = @import("pk");
const c = pk.c;

// Type for our lru_cache wrapper
var tp_lru_cache_wrapper: c.py_Type = 0;
var tp_wraps_decorator: c.py_Type = 0;

// =============================================================================
// Helper functions
// =============================================================================

fn seqLen(seq: *pk.Value) ?usize {
    return seq.len();
}

fn seqItem(seq: *pk.Value, idx: usize) ?pk.Value {
    return seq.getItem(idx);
}

// =============================================================================
// reduce - using new pk.Context API
// =============================================================================

fn reduceFnWrapped(ctx: *pk.Context) bool {
    // Get function argument
    var func = ctx.arg(0) orelse return ctx.typeError("reduce() requires a function");

    // Get sequence argument
    var seq = ctx.arg(1) orelse return ctx.typeError("reduce() requires a sequence");
    const n = seqLen(&seq) orelse return ctx.typeError("expected list or tuple");

    var acc: pk.Value = undefined;
    var start_idx: usize = 0;

    // Check for optional initial value
    if (ctx.argCount() >= 3) {
        acc = ctx.arg(2).?;
    } else {
        if (n == 0) {
            return ctx.typeError("reduce() of empty sequence");
        }
        acc = seqItem(&seq, 0) orelse return ctx.typeError("failed to get first item");
        start_idx = 1;
    }

    // Iterate and reduce
    var i: usize = start_idx;
    while (i < n) : (i += 1) {
        const item = seqItem(&seq, i) orelse return ctx.typeError("failed to get item");
        var args = [_]pk.Value{ acc, item };
        acc = func.call(&args) orelse return false; // Exception already raised
    }

    return ctx.returnValue(acc);
}

// =============================================================================
// partial property getters - using new pk.Context API
// =============================================================================

fn partialFuncGetterWrapped(ctx: *pk.Context) bool {
    var self = ctx.arg(0) orelse return ctx.typeError("expected self");
    const f = self.getDict("f") orelse return ctx.attributeError("partial has no 'f' attribute");
    return ctx.returnValue(f);
}

fn partialKeywordsGetterWrapped(ctx: *pk.Context) bool {
    var self = ctx.arg(0) orelse return ctx.typeError("expected self");
    if (self.getDict("kwargs")) |kwargs| {
        return ctx.returnValue(kwargs);
    }
    // Return empty dict if not found
    return ctx.returnDict();
}

// =============================================================================
// cmp_to_key - using new pk.Context API
// =============================================================================

fn cmpToKeyFnWrapped(ctx: *pk.Context) bool {
    var mycmp = ctx.arg(0) orelse return ctx.typeError("cmp_to_key() requires a comparison function");

    // Create a factory object that holds the comparison function
    _ = c.py_newobject(c.py_retval(), tp_cmp_key_factory, -1, 0);
    c.py_setdict(c.py_retval(), c.py_name("_cmp"), mycmp.ref());
    return true;
}

// =============================================================================
// lru_cache implementation (keeping raw API for complex logic)
// =============================================================================

fn lruCacheWrapperNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_lru_cache_wrapper, -1, 0);
    return true;
}

fn lruCacheWrapperCall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    // Get stored function and cache
    const func_ptr = c.py_getdict(self, c.py_name("_func"));
    const cache_ptr = c.py_getdict(self, c.py_name("_cache"));
    const maxsize_ptr = c.py_getdict(self, c.py_name("_maxsize"));

    if (func_ptr == null or cache_ptr == null) {
        return c.py_exception(c.tp_RuntimeError, "lru_cache wrapper not initialized");
    }

    var func: c.py_TValue = func_ptr.?.*;
    const cache = cache_ptr.?;

    // Build args tuple for cache key and store it stably
    const n_args = argc - 1;
    var key_tuple: c.py_TValue = undefined;
    const args_tuple = c.py_newtuple(&key_tuple, n_args);
    var i: c_int = 0;
    while (i < n_args) : (i += 1) {
        args_tuple[@intCast(i)] = pk.argRef(argv, @intCast(@as(usize, @intCast(i)) + 1)).*;
    }

    // Check cache
    const cache_result = c.py_dict_getitem(cache, &key_tuple);
    if (cache_result > 0) {
        // hits += 1
        if (c.py_getdict(self, c.py_name("_hits"))) |hits_ptr| {
            if (c.py_isint(hits_ptr)) {
                c.py_newint(c.py_r0(), c.py_toint(hits_ptr) + 1);
                c.py_setdict(self, c.py_name("_hits"), c.py_r0());
            }
        }
        // Cache hit - return cached value
        return true;
    }

    // misses += 1
    if (c.py_getdict(self, c.py_name("_misses"))) |misses_ptr| {
        if (c.py_isint(misses_ptr)) {
            c.py_newint(c.py_r0(), c.py_toint(misses_ptr) + 1);
            c.py_setdict(self, c.py_name("_misses"), c.py_r0());
        }
    }

    // Cache miss - call function
    if (n_args == 0) {
        if (!c.py_call(&func, 0, null)) return false;
    } else {
        var call_args: [16]c.py_TValue = undefined;
        i = 0;
        while (i < n_args and i < 16) : (i += 1) {
            call_args[@intCast(i)] = pk.argRef(argv, @intCast(@as(usize, @intCast(i)) + 1)).*;
        }
        if (!c.py_call(&func, n_args, @ptrCast(&call_args))) return false;
    }

    // Store in cache
    var result_copy: c.py_TValue = c.py_retval().*;

    // Check maxsize - if not None and cache is full, remove oldest entry
    if (maxsize_ptr != null and !c.py_isnone(maxsize_ptr.?)) {
        if (c.py_isint(maxsize_ptr.?)) {
            const maxsize = c.py_toint(maxsize_ptr.?);
            const cache_len = c.py_dict_len(cache);
            if (cache_len >= maxsize) {
                // Remove first entry (oldest)
                const RemoveCtx = struct {
                    cache_ref: c.py_Ref,
                    found: bool = false,
                };
                const removeFn = struct {
                    fn f(k: c.py_Ref, _: c.py_Ref, ctx_ptr: ?*anyopaque) callconv(.c) bool {
                        const remove_ctx: *RemoveCtx = @ptrCast(@alignCast(ctx_ptr.?));
                        if (!remove_ctx.found) {
                            _ = c.py_dict_delitem(remove_ctx.cache_ref, k);
                            remove_ctx.found = true;
                        }
                        return true;
                    }
                }.f;
                var remove_ctx = RemoveCtx{ .cache_ref = cache };
                _ = c.py_dict_apply(cache, removeFn, &remove_ctx);
            }
        }
    }

    // Store result using saved key
    _ = c.py_dict_setitem(cache, &key_tuple, &result_copy);
    c.py_retval().* = result_copy;

    return true;
}

fn lruCacheCacheInfo(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    const cache_ptr = c.py_getdict(self, c.py_name("_cache"));
    const maxsize_ptr = c.py_getdict(self, c.py_name("_maxsize"));
    const hits_ptr = c.py_getdict(self, c.py_name("_hits"));
    const misses_ptr = c.py_getdict(self, c.py_name("_misses"));

    const t = c.py_newtuple(c.py_retval(), 4);

    if (hits_ptr != null) t[0] = hits_ptr.?.* else c.py_newint(c.py_r0(), 0);
    if (hits_ptr == null) t[0] = c.py_r0().*;

    if (misses_ptr != null) t[1] = misses_ptr.?.* else c.py_newint(c.py_r0(), 0);
    if (misses_ptr == null) t[1] = c.py_r0().*;

    if (maxsize_ptr != null) {
        t[2] = maxsize_ptr.?.*;
    } else {
        c.py_newnone(c.py_r0());
        t[2] = c.py_r0().*;
    }

    if (cache_ptr != null) {
        c.py_newint(c.py_r0(), c.py_dict_len(cache_ptr.?));
        t[3] = c.py_r0().*;
    } else {
        c.py_newint(c.py_r0(), 0);
        t[3] = c.py_r0().*;
    }

    return true;
}

fn lruCacheCacheClear(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    c.py_newdict(c.py_r0());
    c.py_setdict(self, c.py_name("_cache"), c.py_r0());
    c.py_newint(c.py_r0(), 0);
    c.py_setdict(self, c.py_name("_hits"), c.py_r0());
    c.py_newint(c.py_r0(), 0);
    c.py_setdict(self, c.py_name("_misses"), c.py_r0());
    c.py_newnone(c.py_retval());
    return true;
}

fn lruCacheFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    var maxsize_val: c.py_TValue = undefined;
    c.py_newint(&maxsize_val, 128); // default

    if (argc >= 1) {
        const arg = pk.argRef(argv, 0);
        if (c.py_callable(arg) and !c.py_isint(arg) and !c.py_isnone(arg)) {
            _ = c.py_newobject(c.py_retval(), tp_lru_cache_wrapper, -1, 0);
            c.py_setdict(c.py_retval(), c.py_name("_func"), arg);
            c.py_newdict(c.py_r0());
            c.py_setdict(c.py_retval(), c.py_name("_cache"), c.py_r0());
            c.py_setdict(c.py_retval(), c.py_name("_maxsize"), &maxsize_val);
            c.py_newint(c.py_r0(), 0);
            c.py_setdict(c.py_retval(), c.py_name("_hits"), c.py_r0());
            c.py_newint(c.py_r0(), 0);
            c.py_setdict(c.py_retval(), c.py_name("_misses"), c.py_r0());
            return true;
        }
        maxsize_val = arg.*;
    }

    _ = c.py_newobject(c.py_retval(), tp_lru_cache_wrapper, -1, 0);
    c.py_setdict(c.py_retval(), c.py_name("_maxsize"), &maxsize_val);
    c.py_newdict(c.py_r0());
    c.py_setdict(c.py_retval(), c.py_name("_cache"), c.py_r0());
    c.py_newbool(c.py_r0(), true);
    c.py_setdict(c.py_retval(), c.py_name("_decorator_mode"), c.py_r0());
    c.py_newint(c.py_r0(), 0);
    c.py_setdict(c.py_retval(), c.py_name("_hits"), c.py_r0());
    c.py_newint(c.py_r0(), 0);
    c.py_setdict(c.py_retval(), c.py_name("_misses"), c.py_r0());

    return true;
}

fn lruCacheDecoratorCall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    const func_ptr = c.py_getdict(self, c.py_name("_func"));
    const decorator_mode = c.py_getdict(self, c.py_name("_decorator_mode"));

    if (func_ptr == null or (decorator_mode != null and c.py_tobool(decorator_mode.?))) {
        if (argc < 2) {
            return c.py_exception(c.tp_TypeError, "lru_cache decorator requires a function");
        }
        const func = pk.argRef(argv, 1);

        _ = c.py_newobject(c.py_retval(), tp_lru_cache_wrapper, -1, 0);
        c.py_setdict(c.py_retval(), c.py_name("_func"), func);

        const maxsize_ptr = c.py_getdict(self, c.py_name("_maxsize"));
        if (maxsize_ptr != null) {
            c.py_setdict(c.py_retval(), c.py_name("_maxsize"), maxsize_ptr.?);
        }
        c.py_newdict(c.py_r0());
        c.py_setdict(c.py_retval(), c.py_name("_cache"), c.py_r0());
        c.py_newint(c.py_r0(), 0);
        c.py_setdict(c.py_retval(), c.py_name("_hits"), c.py_r0());
        c.py_newint(c.py_r0(), 0);
        c.py_setdict(c.py_retval(), c.py_name("_misses"), c.py_r0());

        return true;
    }

    return lruCacheWrapperCall(argc, argv);
}

// =============================================================================
// wraps implementation (decorator object)
// =============================================================================

fn wrapsDecoratorNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_wraps_decorator, 1, 0);
    c.py_newnone(c.py_r0());
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    return true;
}

fn wrapsDecoratorCall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "wraps decorator requires a function");
    const self = pk.argRef(argv, 0);
    const wrapper = pk.argRef(argv, 1);
    const wrapped = c.py_getslot(self, 0);

    if (c.py_isnone(wrapped) or c.py_isnil(wrapped)) {
        c.py_retval().* = wrapper.*;
        return true;
    }

    // Use attribute setters on function objects (PocketPy exposes __name__/__doc__ as properties).
    if (c.py_getattr(wrapped, c.py_name("__name__"))) {
        var name_copy: c.py_TValue = c.py_retval().*;
        _ = c.py_setattr(wrapper, c.py_name("__name__"), &name_copy);
    } else {
        c.py_clearexc(null);
    }
    if (c.py_getattr(wrapped, c.py_name("__doc__"))) {
        var doc_copy: c.py_TValue = c.py_retval().*;
        _ = c.py_setattr(wrapper, c.py_name("__doc__"), &doc_copy);
    } else {
        c.py_clearexc(null);
    }

    c.py_retval().* = wrapper.*;
    return true;
}

fn wrapsFnWrapped(ctx: *pk.Context) bool {
    const wrapped = ctx.arg(0) orelse return ctx.typeError("wraps() requires a function");
    _ = c.py_newobject(c.py_retval(), tp_wraps_decorator, 1, 0);
    c.py_setslot(c.py_retval(), 0, wrapped.refConst());
    return true;
}

// =============================================================================
// cmp_to_key types (keeping raw API for comparison operators)
// =============================================================================

var tp_cmp_key: c.py_Type = 0;
var tp_cmp_key_factory: c.py_Type = 0;

fn cmpKeyNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_cmp_key, -1, 0);
    return true;
}

fn cmpKeyInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "K() requires obj argument");
    }
    const self = pk.argRef(argv, 0);
    const obj = pk.argRef(argv, 1);
    c.py_setdict(self, c.py_name("obj"), obj);
    c.py_newnone(c.py_retval());
    return true;
}

fn cmpKeyCompare(self: c.py_Ref, other: c.py_Ref, cmp_func: c.py_Ref) ?c_int {
    const self_obj_ptr = c.py_getdict(self, c.py_name("obj"));
    const other_obj_ptr = c.py_getdict(other, c.py_name("obj"));
    const mycmp_ptr = c.py_getdict(self, c.py_name("_cmp"));

    if (self_obj_ptr == null or other_obj_ptr == null) return null;

    var cmp_fn: c.py_TValue = undefined;
    if (cmp_func != null) {
        cmp_fn = cmp_func.*;
    } else if (mycmp_ptr != null) {
        cmp_fn = mycmp_ptr.?.*;
    } else {
        return null;
    }

    var args: [2]c.py_TValue = .{ self_obj_ptr.?.*, other_obj_ptr.?.* };
    if (!c.py_call(&cmp_fn, 2, @ptrCast(&args))) return null;

    if (!c.py_isint(c.py_retval())) return null;
    return @intCast(c.py_toint(c.py_retval()));
}

fn cmpKeyLt(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    const result = cmpKeyCompare(self, other, null);
    if (result == null) {
        return c.py_exception(c.tp_TypeError, "comparison failed");
    }
    c.py_newbool(c.py_retval(), result.? < 0);
    return true;
}

fn cmpKeyGt(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    const result = cmpKeyCompare(self, other, null);
    if (result == null) {
        return c.py_exception(c.tp_TypeError, "comparison failed");
    }
    c.py_newbool(c.py_retval(), result.? > 0);
    return true;
}

fn cmpKeyEq(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    const result = cmpKeyCompare(self, other, null);
    if (result == null) {
        return c.py_exception(c.tp_TypeError, "comparison failed");
    }
    c.py_newbool(c.py_retval(), result.? == 0);
    return true;
}

fn cmpKeyLe(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    const result = cmpKeyCompare(self, other, null);
    if (result == null) {
        return c.py_exception(c.tp_TypeError, "comparison failed");
    }
    c.py_newbool(c.py_retval(), result.? <= 0);
    return true;
}

fn cmpKeyGe(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    const result = cmpKeyCompare(self, other, null);
    if (result == null) {
        return c.py_exception(c.tp_TypeError, "comparison failed");
    }
    c.py_newbool(c.py_retval(), result.? >= 0);
    return true;
}

fn cmpKeyNe(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const other = pk.argRef(argv, 1);
    const result = cmpKeyCompare(self, other, null);
    if (result == null) {
        return c.py_exception(c.tp_TypeError, "comparison failed");
    }
    c.py_newbool(c.py_retval(), result.? != 0);
    return true;
}

fn cmpKeyFactoryNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_cmp_key_factory, -1, 0);
    return true;
}

fn cmpKeyFactoryCall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "K() requires obj argument");
    }
    const self = pk.argRef(argv, 0);
    const obj = pk.argRef(argv, 1);

    const mycmp_ptr = c.py_getdict(self, c.py_name("_cmp"));
    if (mycmp_ptr == null) {
        return c.py_exception(c.tp_RuntimeError, "cmp_to_key factory not initialized");
    }

    _ = c.py_newobject(c.py_retval(), tp_cmp_key, -1, 0);
    c.py_setdict(c.py_retval(), c.py_name("obj"), obj);
    c.py_setdict(c.py_retval(), c.py_name("_cmp"), mycmp_ptr.?);
    return true;
}

// =============================================================================
// Module registration - demonstrating ModuleBuilder
// =============================================================================

pub fn register() void {
    // Import and extend the functools module
    var builder = pk.ModuleBuilder.importAndExtend("functools") orelse {
        c.py_clearexc(null);
        return;
    };
    const module = builder.getModule();

    // Register reduce using wrapped function (demonstrates new API)
    _ = builder.func("reduce", pk.wrapFn(2, 3, reduceFnWrapped));

    // Create lru_cache wrapper type using TypeBuilder (demonstrates new API)
    var lru_builder = pk.TypeBuilder.newSimple("_lru_cache_wrapper", module);
    tp_lru_cache_wrapper = lru_builder
        .magic("__new__", lruCacheWrapperNew)
        .magic("__call__", lruCacheDecoratorCall)
        .method("cache_info", lruCacheCacheInfo)
        .method("cache_clear", lruCacheCacheClear)
        .build();

    // Bind native lru_cache implementation
    _ = builder.func("_lru_cache_native", lruCacheFn);

    // wraps decorator object + wraps() function
    var wraps_builder = pk.TypeBuilder.newSimple("_WrapsDecorator", module);
    tp_wraps_decorator = wraps_builder
        .magic("__new__", wrapsDecoratorNew)
        .magic("__call__", wrapsDecoratorCall)
        .build();
    _ = builder.funcWrapped("wraps", 1, 1, wrapsFnWrapped);

    // Create cmp_to_key types using TypeBuilder
    var cmp_key_builder = pk.TypeBuilder.newSimple("_K", module);
    tp_cmp_key = cmp_key_builder
        .magic("__new__", cmpKeyNew)
        .magic("__init__", cmpKeyInit)
        .magic("__lt__", cmpKeyLt)
        .magic("__gt__", cmpKeyGt)
        .magic("__eq__", cmpKeyEq)
        .magic("__le__", cmpKeyLe)
        .magic("__ge__", cmpKeyGe)
        .magic("__ne__", cmpKeyNe)
        .build();

    var factory_builder = pk.TypeBuilder.newSimple("_CmpKeyFactory", module);
    tp_cmp_key_factory = factory_builder
        .magic("__new__", cmpKeyFactoryNew)
        .magic("__call__", cmpKeyFactoryCall)
        .build();

    // Register cmp_to_key using wrapped function
    _ = builder.func("cmp_to_key", pk.wrapFn(1, 1, cmpToKeyFnWrapped));

    // Inject Python wrapper for lru_cache that handles keyword arguments
    const lru_cache_wrapper =
        \\def lru_cache(maxsize=128, typed=False):
        \\    import functools
        \\    if callable(maxsize) and not isinstance(maxsize, type):
        \\        func = maxsize
        \\        return functools._lru_cache_native(128)(func)
        \\    def decorator(func):
        \\        if maxsize is None:
        \\            return functools._lru_cache_native(None)(func)
        \\        return functools._lru_cache_native(maxsize)(func)
        \\    return decorator
    ;
    _ = builder.exec(lru_cache_wrapper);

    // Add CPython-compatible aliases to partial type
    if (builder.getDict("partial")) |partial_val| {
        var partial = partial_val;
        if (partial.typeof() == c.tp_type) {
            const partial_tp = c.py_totype(partial.ref());
            // Add 'func' as alias for 'f' using wrapped getters
            c.py_bindproperty(partial_tp, "func", pk.wrapFnN(1, partialFuncGetterWrapped), null);
            // Add 'keywords' as alias for 'kwargs'
            c.py_bindproperty(partial_tp, "keywords", pk.wrapFnN(1, partialKeywordsGetterWrapped), null);
        }
    }
}
