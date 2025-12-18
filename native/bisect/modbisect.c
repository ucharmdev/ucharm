/*
 * modbisect - Native bisect module for ucharm
 * 
 * Provides Python's bisect module functionality:
 * - bisect_left(a, x[, lo[, hi[, key]]])
 * - bisect_right(a, x[, lo[, hi[, key]]])
 * - bisect(a, x[, lo[, hi[, key]]]) - alias for bisect_right
 * - insort_left(a, x[, lo[, hi[, key]]])
 * - insort_right(a, x[, lo[, hi[, key]]])
 * - insort(a, x[, lo[, hi[, key]]]) - alias for insort_right
 * 
 * Usage in Python:
 *   import bisect
 *   
 *   # Find insertion point
 *   a = [1, 3, 5, 7]
 *   i = bisect.bisect(a, 4)  # Returns 2
 *   
 *   # Insert and maintain sorted order
 *   bisect.insort(a, 4)  # a = [1, 3, 4, 5, 7]
 */

#include "../bridge/mpy_bridge.h"

// ============================================================================
// bisect_left(a, x, lo=0, hi=len(a), *, key=None)
// ============================================================================

static mp_obj_t mod_bisect_bisect_left(size_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    // Parse arguments
    mp_obj_t a = args[0];
    mp_obj_t x = args[1];
    
    // Get list length
    mp_obj_t len_obj = mp_obj_len(a);
    mp_int_t list_len = mp_obj_get_int(len_obj);
    
    // Default lo and hi
    mp_int_t lo = 0;
    mp_int_t hi = list_len;
    
    // Parse positional args for lo/hi
    if (n_args > 2) {
        lo = mp_obj_get_int(args[2]);
    }
    if (n_args > 3) {
        hi = mp_obj_get_int(args[3]);
    }
    
    // Also check kwargs for lo, hi, and key
    mp_obj_t key = mp_const_none;
    if (kwargs != NULL) {
        mp_map_elem_t *elem;
        
        elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_lo), MP_MAP_LOOKUP);
        if (elem != NULL) {
            lo = mp_obj_get_int(elem->value);
        }
        
        elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_hi), MP_MAP_LOOKUP);
        if (elem != NULL) {
            hi = mp_obj_get_int(elem->value);
        }
        
        elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_key), MP_MAP_LOOKUP);
        if (elem != NULL) {
            key = elem->value;
        }
    }
    
    // Validate bounds
    if (lo < 0) {
        lo = 0;
    }
    if (hi > list_len) {
        hi = list_len;
    }
    
    // Apply key to x once if needed
    mp_obj_t x_key = x;
    if (key != mp_const_none) {
        mp_obj_t call_args[1] = {x};
        x_key = mp_call_function_n_kw(key, 1, 0, call_args);
    }
    
    // Binary search - find leftmost position
    while (lo < hi) {
        mp_int_t mid = (lo + hi) / 2;
        mp_obj_t mid_val = mp_obj_subscr(a, mp_obj_new_int(mid), MP_OBJ_SENTINEL);
        
        // Apply key to mid_val if needed
        mp_obj_t mid_key = mid_val;
        if (key != mp_const_none) {
            mp_obj_t call_args[1] = {mid_val};
            mid_key = mp_call_function_n_kw(key, 1, 0, call_args);
        }
        
        if (mp_obj_is_true(mp_binary_op(MP_BINARY_OP_LESS, mid_key, x_key))) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    
    return mp_obj_new_int(lo);
}
static MP_DEFINE_CONST_FUN_OBJ_KW(mod_bisect_bisect_left_obj, 2, mod_bisect_bisect_left);

// ============================================================================
// bisect_right(a, x, lo=0, hi=len(a), *, key=None)
// ============================================================================

static mp_obj_t mod_bisect_bisect_right(size_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    // Parse arguments
    mp_obj_t a = args[0];
    mp_obj_t x = args[1];
    
    // Get list length
    mp_obj_t len_obj = mp_obj_len(a);
    mp_int_t list_len = mp_obj_get_int(len_obj);
    
    // Default lo and hi
    mp_int_t lo = 0;
    mp_int_t hi = list_len;
    
    // Parse positional args for lo/hi
    if (n_args > 2) {
        lo = mp_obj_get_int(args[2]);
    }
    if (n_args > 3) {
        hi = mp_obj_get_int(args[3]);
    }
    
    // Also check kwargs for lo, hi, and key
    mp_obj_t key = mp_const_none;
    if (kwargs != NULL) {
        mp_map_elem_t *elem;
        
        elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_lo), MP_MAP_LOOKUP);
        if (elem != NULL) {
            lo = mp_obj_get_int(elem->value);
        }
        
        elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_hi), MP_MAP_LOOKUP);
        if (elem != NULL) {
            hi = mp_obj_get_int(elem->value);
        }
        
        elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_key), MP_MAP_LOOKUP);
        if (elem != NULL) {
            key = elem->value;
        }
    }
    
    // Validate bounds
    if (lo < 0) {
        lo = 0;
    }
    if (hi > list_len) {
        hi = list_len;
    }
    
    // Apply key to x once if needed
    mp_obj_t x_key = x;
    if (key != mp_const_none) {
        mp_obj_t call_args[1] = {x};
        x_key = mp_call_function_n_kw(key, 1, 0, call_args);
    }
    
    // Binary search - find rightmost position
    while (lo < hi) {
        mp_int_t mid = (lo + hi) / 2;
        mp_obj_t mid_val = mp_obj_subscr(a, mp_obj_new_int(mid), MP_OBJ_SENTINEL);
        
        // Apply key to mid_val if needed
        mp_obj_t mid_key = mid_val;
        if (key != mp_const_none) {
            mp_obj_t call_args[1] = {mid_val};
            mid_key = mp_call_function_n_kw(key, 1, 0, call_args);
        }
        
        if (mp_obj_is_true(mp_binary_op(MP_BINARY_OP_LESS, x_key, mid_key))) {
            hi = mid;
        } else {
            lo = mid + 1;
        }
    }
    
    return mp_obj_new_int(lo);
}
static MP_DEFINE_CONST_FUN_OBJ_KW(mod_bisect_bisect_right_obj, 2, mod_bisect_bisect_right);

// ============================================================================
// insort_left(a, x, lo=0, hi=len(a), *, key=None)
// ============================================================================

static mp_obj_t mod_bisect_insort_left(size_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    // Get the insertion point
    mp_obj_t pos = mod_bisect_bisect_left(n_args, args, kwargs);
    mp_int_t i = mp_obj_get_int(pos);
    
    // Insert at position
    mp_obj_t list = args[0];
    mp_obj_t x = args[1];
    
    // Call list.insert(i, x)
    mp_obj_t insert_method = mp_load_attr(list, MP_QSTR_insert);
    mp_obj_t call_args[2] = {mp_obj_new_int(i), x};
    mp_call_function_n_kw(insert_method, 2, 0, call_args);
    
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_KW(mod_bisect_insort_left_obj, 2, mod_bisect_insort_left);

// ============================================================================
// insort_right(a, x, lo=0, hi=len(a), *, key=None)
// ============================================================================

static mp_obj_t mod_bisect_insort_right(size_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    // Get the insertion point
    mp_obj_t pos = mod_bisect_bisect_right(n_args, args, kwargs);
    mp_int_t i = mp_obj_get_int(pos);
    
    // Insert at position
    mp_obj_t list = args[0];
    mp_obj_t x = args[1];
    
    // Call list.insert(i, x)
    mp_obj_t insert_method = mp_load_attr(list, MP_QSTR_insert);
    mp_obj_t call_args[2] = {mp_obj_new_int(i), x};
    mp_call_function_n_kw(insert_method, 2, 0, call_args);
    
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_KW(mod_bisect_insort_right_obj, 2, mod_bisect_insort_right);

// ============================================================================
// Module Definition
// ============================================================================

static const mp_rom_map_elem_t bisect_module_globals_table[] = {
    { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR_bisect) },
    
    // Primary functions
    { MP_ROM_QSTR(MP_QSTR_bisect_left), MP_ROM_PTR(&mod_bisect_bisect_left_obj) },
    { MP_ROM_QSTR(MP_QSTR_bisect_right), MP_ROM_PTR(&mod_bisect_bisect_right_obj) },
    { MP_ROM_QSTR(MP_QSTR_insort_left), MP_ROM_PTR(&mod_bisect_insort_left_obj) },
    { MP_ROM_QSTR(MP_QSTR_insort_right), MP_ROM_PTR(&mod_bisect_insort_right_obj) },
    
    // Aliases (bisect = bisect_right, insort = insort_right)
    { MP_ROM_QSTR(MP_QSTR_bisect), MP_ROM_PTR(&mod_bisect_bisect_right_obj) },
    { MP_ROM_QSTR(MP_QSTR_insort), MP_ROM_PTR(&mod_bisect_insort_right_obj) },
};
static MP_DEFINE_CONST_DICT(bisect_module_globals, bisect_module_globals_table);

const mp_obj_module_t mp_module_bisect = {
    .base = { &mp_type_module },
    .globals = (mp_obj_dict_t *)&bisect_module_globals,
};

MP_REGISTER_MODULE(MP_QSTR_bisect, mp_module_bisect);
