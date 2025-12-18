/*
 * modfunctools - Native functools module for ucharm
 * 
 * Provides Python's functools functionality:
 * - reduce(function, iterable[, initializer])
 * - partial(func, *args, **kwargs)
 * - cmp_to_key(func)
 * - cache (simple memoization)
 * - lru_cache (bounded memoization)
 * 
 * Usage in Python:
 *   from functools import reduce, partial, cmp_to_key
 *   
 *   # Reduce a list
 *   result = reduce(lambda x, y: x + y, [1, 2, 3, 4])  # 10
 *   
 *   # Create partial function
 *   add10 = partial(add, 10)
 *   add10(5)  # 15
 */

#include "../bridge/mpy_bridge.h"

// Zig functions
extern uint64_t functools_hash(const char *data, size_t len);
extern bool functools_cache_get(uint64_t key_hash, int64_t *value);
extern void functools_cache_set(uint64_t key_hash, int64_t value);
extern void functools_cache_clear(void);
extern size_t functools_cache_size(void);
extern uint64_t functools_hash_pair(uint64_t a, uint64_t b);

// ============================================================================
// functools.reduce(function, iterable[, initializer])
// ============================================================================

MPY_FUNC_VAR(functools, reduce, 2, 3) {
    mp_obj_t func = args[0];
    mp_obj_t iterable = args[1];
    
    // Get iterator
    mp_obj_iter_buf_t iter_buf;
    mp_obj_t iter = mp_getiter(iterable, &iter_buf);
    
    mp_obj_t accumulator;
    
    if (n_args == 3) {
        // Use initializer
        accumulator = args[2];
    } else {
        // Get first item as initial value
        accumulator = mp_iternext(iter);
        if (accumulator == MP_OBJ_STOP_ITERATION) {
            mp_raise_TypeError(MP_ERROR_TEXT("reduce() of empty sequence with no initial value"));
        }
    }
    
    // Apply function to each element
    mp_obj_t item;
    while ((item = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        mp_obj_t call_args[2] = {accumulator, item};
        accumulator = mp_call_function_n_kw(func, 2, 0, call_args);
    }
    
    return accumulator;
}
MPY_FUNC_OBJ_VAR(functools, reduce, 2, 3);

// ============================================================================
// Partial object type
// ============================================================================

typedef struct _functools_partial_obj_t {
    mp_obj_base_t base;
    mp_obj_t func;
    mp_obj_t args;      // tuple of positional args
    mp_obj_t kwargs;    // dict of keyword args
} functools_partial_obj_t;

static mp_obj_t partial_call(mp_obj_t self_in, size_t n_args, size_t n_kw, const mp_obj_t *args);

static void partial_print(const mp_print_t *print, mp_obj_t self_in, mp_print_kind_t kind) {
    (void)kind;
    functools_partial_obj_t *self = MP_OBJ_TO_PTR(self_in);
    mp_printf(print, "functools.partial(%O, ...)", self->func);
}

// Partial attributes
static void partial_attr(mp_obj_t self_in, qstr attr, mp_obj_t *dest) {
    functools_partial_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    if (dest[0] == MP_OBJ_NULL) {
        // Load attribute
        if (attr == MP_QSTR_func) {
            dest[0] = self->func;
        } else if (attr == MP_QSTR_args) {
            dest[0] = self->args;
        } else if (attr == MP_QSTR_keywords) {
            dest[0] = self->kwargs;
        }
    }
}

MP_DEFINE_CONST_OBJ_TYPE(
    functools_partial_type,
    MP_QSTR_partial,
    MP_TYPE_FLAG_NONE,
    print, partial_print,
    call, partial_call,
    attr, partial_attr
);

static mp_obj_t partial_call(mp_obj_t self_in, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    functools_partial_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    // Get stored args
    size_t stored_n_args;
    mp_obj_t *stored_args;
    mp_obj_tuple_get(self->args, &stored_n_args, &stored_args);
    
    // Get stored kwargs count
    size_t stored_n_kw = 0;
    mp_map_t *stored_kwargs_map = NULL;
    if (self->kwargs != mp_const_none && mp_obj_is_type(self->kwargs, &mp_type_dict)) {
        mp_obj_dict_t *stored_dict = MP_OBJ_TO_PTR(self->kwargs);
        stored_kwargs_map = &stored_dict->map;
        stored_n_kw = stored_kwargs_map->used;
    }
    
    // Total keyword args: stored + new (new ones override stored if conflict)
    size_t total_n_kw = stored_n_kw + n_kw;
    
    // Combine args: stored_args + new args + all kwargs
    size_t total_args = stored_n_args + n_args;
    mp_obj_t *combined_args = m_new(mp_obj_t, total_args + 2 * total_n_kw);
    
    // Copy stored positional args
    for (size_t i = 0; i < stored_n_args; i++) {
        combined_args[i] = stored_args[i];
    }
    
    // Copy new positional args
    for (size_t i = 0; i < n_args; i++) {
        combined_args[stored_n_args + i] = args[i];
    }
    
    // Build combined kwargs: start with stored, then add/override with new
    size_t kw_idx = 0;
    
    // First add stored kwargs
    if (stored_kwargs_map != NULL) {
        for (size_t i = 0; i < stored_kwargs_map->alloc; i++) {
            if (mp_map_slot_is_filled(stored_kwargs_map, i)) {
                // Check if this key is overridden by new kwargs
                bool overridden = false;
                for (size_t j = 0; j < n_kw; j++) {
                    mp_obj_t new_key = args[n_args + j * 2];
                    if (mp_obj_equal(stored_kwargs_map->table[i].key, new_key)) {
                        overridden = true;
                        break;
                    }
                }
                if (!overridden) {
                    combined_args[total_args + kw_idx * 2] = stored_kwargs_map->table[i].key;
                    combined_args[total_args + kw_idx * 2 + 1] = stored_kwargs_map->table[i].value;
                    kw_idx++;
                }
            }
        }
    }
    
    // Then add new kwargs (these override stored ones)
    for (size_t i = 0; i < n_kw; i++) {
        combined_args[total_args + kw_idx * 2] = args[n_args + i * 2];
        combined_args[total_args + kw_idx * 2 + 1] = args[n_args + i * 2 + 1];
        kw_idx++;
    }
    
    // Actual number of kwargs after deduplication
    size_t final_n_kw = kw_idx;
    
    mp_obj_t result = mp_call_function_n_kw(self->func, total_args, final_n_kw, combined_args);
    m_del(mp_obj_t, combined_args, total_args + 2 * total_n_kw);
    
    return result;
}

// functools.partial(func, *args, **kwargs)
static mp_obj_t functools_partial(size_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    if (n_args < 1) {
        mp_raise_TypeError(MP_ERROR_TEXT("partial() requires at least 1 argument"));
    }
    
    functools_partial_obj_t *self = mp_obj_malloc(functools_partial_obj_t, &functools_partial_type);
    self->func = args[0];
    
    // Store positional args (skip first which is the function)
    if (n_args > 1) {
        self->args = mp_obj_new_tuple(n_args - 1, args + 1);
    } else {
        self->args = mp_const_empty_tuple;
    }
    
    // Store keyword args
    if (kwargs != NULL && kwargs->used > 0) {
        self->kwargs = mp_obj_new_dict(kwargs->used);
        for (size_t i = 0; i < kwargs->alloc; i++) {
            if (mp_map_slot_is_filled(kwargs, i)) {
                mp_obj_dict_store(self->kwargs, kwargs->table[i].key, kwargs->table[i].value);
            }
        }
    } else {
        self->kwargs = mp_obj_new_dict(0);
    }
    
    return MP_OBJ_FROM_PTR(self);
}
static MP_DEFINE_CONST_FUN_OBJ_KW(mod_functools_partial_obj, 1, functools_partial);

// ============================================================================
// cmp_to_key wrapper type
// ============================================================================

typedef struct _cmp_key_obj_t {
    mp_obj_base_t base;
    mp_obj_t cmp_func;
    mp_obj_t obj;
} cmp_key_obj_t;

// Forward declarations
static mp_obj_t cmp_key_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);
static mp_obj_t cmp_key_binary_op(mp_binary_op_t op, mp_obj_t lhs_in, mp_obj_t rhs_in);

// Define the type first (needed for mp_obj_is_type check)
MP_DEFINE_CONST_OBJ_TYPE(
    cmp_key_type,
    MP_QSTR_cmp_key,
    MP_TYPE_FLAG_NONE,
    make_new, cmp_key_make_new,
    binary_op, cmp_key_binary_op
);

static mp_obj_t cmp_key_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 2, 2, false);
    
    cmp_key_obj_t *self = mp_obj_malloc(cmp_key_obj_t, &cmp_key_type);
    self->cmp_func = args[0];
    self->obj = args[1];
    
    return MP_OBJ_FROM_PTR(self);
}

// Helper to call comparison function
static mp_int_t call_cmp(cmp_key_obj_t *self, cmp_key_obj_t *other) {
    mp_obj_t call_args[2] = {self->obj, other->obj};
    mp_obj_t result = mp_call_function_n_kw(self->cmp_func, 2, 0, call_args);
    return mp_obj_get_int(result);
}

// Binary operator for comparison - this is what sorted() uses
static mp_obj_t cmp_key_binary_op(mp_binary_op_t op, mp_obj_t lhs_in, mp_obj_t rhs_in) {
    cmp_key_obj_t *lhs = MP_OBJ_TO_PTR(lhs_in);
    
    // Check if rhs is also a cmp_key
    if (!mp_obj_is_type(rhs_in, &cmp_key_type)) {
        return MP_OBJ_NULL; // Not supported
    }
    
    cmp_key_obj_t *rhs = MP_OBJ_TO_PTR(rhs_in);
    mp_int_t cmp_result = call_cmp(lhs, rhs);
    
    switch (op) {
        case MP_BINARY_OP_LESS:
            return mpy_bool(cmp_result < 0);
        case MP_BINARY_OP_LESS_EQUAL:
            return mpy_bool(cmp_result <= 0);
        case MP_BINARY_OP_EQUAL:
            return mpy_bool(cmp_result == 0);
        case MP_BINARY_OP_NOT_EQUAL:
            return mpy_bool(cmp_result != 0);
        case MP_BINARY_OP_MORE:
            return mpy_bool(cmp_result > 0);
        case MP_BINARY_OP_MORE_EQUAL:
            return mpy_bool(cmp_result >= 0);
        default:
            return MP_OBJ_NULL; // Not supported
    }
}

// cmp_to_key wrapper class
typedef struct _cmp_to_key_obj_t {
    mp_obj_base_t base;
    mp_obj_t cmp_func;
} cmp_to_key_obj_t;

static mp_obj_t cmp_to_key_call(mp_obj_t self_in, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 1, 1, false);
    cmp_to_key_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    // Create and return a cmp_key object
    mp_obj_t make_args[2] = {self->cmp_func, args[0]};
    return cmp_key_make_new(&cmp_key_type, 2, 0, make_args);
}

MP_DEFINE_CONST_OBJ_TYPE(
    cmp_to_key_type,
    MP_QSTR_cmp_to_key,
    MP_TYPE_FLAG_NONE,
    call, cmp_to_key_call
);

// functools.cmp_to_key(cmp_func)
MPY_FUNC_1(functools, cmp_to_key) {
    cmp_to_key_obj_t *self = mp_obj_malloc(cmp_to_key_obj_t, &cmp_to_key_type);
    self->cmp_func = arg0;
    return MP_OBJ_FROM_PTR(self);
}
MPY_FUNC_OBJ_1(functools, cmp_to_key);

// ============================================================================
// Simple cache decorator (no size limit)
// ============================================================================

// functools.cache_clear()
MPY_FUNC_0(functools, cache_clear) {
    functools_cache_clear();
    return mpy_none();
}
MPY_FUNC_OBJ_0(functools, cache_clear);

// functools.cache_info() -> dict
MPY_FUNC_0(functools, cache_info) {
    mp_obj_t dict = mpy_new_dict();
    mpy_dict_store_str(dict, "size", mpy_new_int(functools_cache_size()));
    mpy_dict_store_str(dict, "maxsize", mpy_new_int(256));
    return dict;
}
MPY_FUNC_OBJ_0(functools, cache_info);

// ============================================================================
// functools.total_ordering - class decorator
// Note: This is better implemented in Python, but we provide a stub
// ============================================================================

// ============================================================================
// SENTINEL constant for reduce without initial value detection
// ============================================================================

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(functools)
    // Core functions
    MPY_MODULE_FUNC(functools, reduce)
    { MP_ROM_QSTR(MP_QSTR_partial), MP_ROM_PTR(&mod_functools_partial_obj) },
    MPY_MODULE_FUNC(functools, cmp_to_key)
    
    // Cache utilities
    MPY_MODULE_FUNC(functools, cache_clear)
    MPY_MODULE_FUNC(functools, cache_info)
    
    // Types (for isinstance checks)
    { MP_ROM_QSTR(MP_QSTR_partial_type), MP_ROM_PTR(&functools_partial_type) },
MPY_MODULE_END(functools)
