/*
 * modcopy.c - Native copy module for ucharm
 *
 * Provides Python's copy functionality:
 * - copy(obj) - Shallow copy (new container, same element references)
 * - deepcopy(obj) - Deep copy (recursively copy all nested objects)
 *
 * Usage in Python:
 *   from copy import copy, deepcopy
 *
 *   original = [1, [2, 3], {'a': 4}]
 *   shallow = copy(original)       # New list, same nested objects
 *   deep = deepcopy(original)      # New list, new nested objects
 */

#include "../bridge/mpy_bridge.h"

// Zig functions
ZIG_EXTERN uint64_t copy_hash_pointer(size_t ptr);
ZIG_EXTERN uint32_t copy_version(void);

// ============================================================================
// Forward declarations
// ============================================================================

static mp_obj_t do_copy(mp_obj_t obj);
static mp_obj_t do_deepcopy(mp_obj_t obj, mp_obj_t memo);

// ============================================================================
// Helper: Check if object is immutable (can be shared without copying)
// ============================================================================

static bool is_immutable(mp_obj_t obj) {
    // None, True, False are singletons
    if (obj == mp_const_none || obj == mp_const_true || obj == mp_const_false) {
        return true;
    }
    
    // Small integers are immutable
    if (mp_obj_is_small_int(obj)) {
        return true;
    }
    
    // Check type
    const mp_obj_type_t *type = mp_obj_get_type(obj);
    
    // Strings are immutable
    if (type == &mp_type_str) {
        return true;
    }
    
    // Bytes are immutable
    if (type == &mp_type_bytes) {
        return true;
    }
    
    // Integers (big ints) are immutable
    if (type == &mp_type_int) {
        return true;
    }
    
    // Floats are immutable
#if MICROPY_PY_BUILTINS_FLOAT
    if (type == &mp_type_float) {
        return true;
    }
#endif
    
    // Tuples contain immutable structure (but may contain mutable items)
    // For shallow copy, tuples are returned as-is
    if (type == &mp_type_tuple) {
        return true;
    }
    
    return false;
}

// ============================================================================
// copy.copy(obj) - Shallow copy
// ============================================================================

static mp_obj_t do_copy(mp_obj_t obj) {
    // Immutable objects don't need copying
    if (is_immutable(obj)) {
        return obj;
    }
    
    const mp_obj_type_t *type = mp_obj_get_type(obj);
    
    // List: create new list with same elements
    if (type == &mp_type_list) {
        size_t len;
        mp_obj_t *items;
        mp_obj_list_get(obj, &len, &items);
        return mp_obj_new_list(len, items);
    }
    
    // Dict: create new dict with same key-value pairs
    if (type == &mp_type_dict) {
        mp_obj_t new_dict = mp_obj_new_dict(0);
        mp_map_t *map = mp_obj_dict_get_map(obj);
        
        for (size_t i = 0; i < map->alloc; i++) {
            if (mp_map_slot_is_filled(map, i)) {
                mp_obj_dict_store(new_dict, map->table[i].key, map->table[i].value);
            }
        }
        return new_dict;
    }
    
    // Set: create new set with same elements
    if (type == &mp_type_set) {
        mp_obj_t new_set = mp_obj_new_set(0, NULL);
        mp_obj_t iter = mp_getiter(obj, NULL);
        mp_obj_t item;
        while ((item = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
            mp_obj_set_store(new_set, item);
        }
        return new_set;
    }
    
    // Bytearray: create new bytearray with same content
    if (type == &mp_type_bytearray) {
        mp_buffer_info_t bufinfo;
        mp_get_buffer_raise(obj, &bufinfo, MP_BUFFER_READ);
        return mp_obj_new_bytearray(bufinfo.len, bufinfo.buf);
    }
    
    // For other objects, try to use __copy__ method if available
    mp_obj_t dest[2];
    mp_load_method_maybe(obj, MP_QSTR___copy__, dest);
    if (dest[0] != MP_OBJ_NULL) {
        return mp_call_method_n_kw(0, 0, dest);
    }
    
    // Fallback: return the same object (for objects without copy support)
    return obj;
}

MPY_FUNC_1(copy, copy) {
    return do_copy(arg0);
}
MPY_FUNC_OBJ_1(copy, copy);

// ============================================================================
// copy.deepcopy(obj, memo=None) - Deep copy
// ============================================================================

static mp_obj_t do_deepcopy(mp_obj_t obj, mp_obj_t memo) {
    // Immutable primitives don't need copying
    if (obj == mp_const_none || obj == mp_const_true || obj == mp_const_false) {
        return obj;
    }
    
    if (mp_obj_is_small_int(obj)) {
        return obj;
    }
    
    const mp_obj_type_t *type = mp_obj_get_type(obj);
    
    // Strings, bytes, ints, floats are immutable
    if (type == &mp_type_str || type == &mp_type_bytes || type == &mp_type_int) {
        return obj;
    }
    
#if MICROPY_PY_BUILTINS_FLOAT
    if (type == &mp_type_float) {
        return obj;
    }
#endif
    
    // Check memo for already-copied objects (handles circular references)
    if (memo != mp_const_none) {
        mp_obj_t id_obj = mp_obj_new_int((mp_int_t)(uintptr_t)obj);
        mp_map_t *memo_map = mp_obj_dict_get_map(memo);
        mp_map_elem_t *elem = mp_map_lookup(memo_map, id_obj, MP_MAP_LOOKUP);
        if (elem != NULL) {
            return elem->value;
        }
    }
    
    mp_obj_t result;
    
    // Tuple: create new tuple with deep-copied elements
    if (type == &mp_type_tuple) {
        size_t len;
        mp_obj_t *items;
        mp_obj_tuple_get(obj, &len, &items);
        
        // Check if all items are immutable (no need to copy)
        bool all_immutable = true;
        for (size_t i = 0; i < len; i++) {
            if (!is_immutable(items[i])) {
                all_immutable = false;
                break;
            }
        }
        
        if (all_immutable) {
            return obj;
        }
        
        // Deep copy each element
        mp_obj_t *new_items = m_new(mp_obj_t, len);
        for (size_t i = 0; i < len; i++) {
            new_items[i] = do_deepcopy(items[i], memo);
        }
        result = mp_obj_new_tuple(len, new_items);
        m_del(mp_obj_t, new_items, len);
        
        if (memo != mp_const_none) {
            mp_obj_t id_obj = mp_obj_new_int((mp_int_t)(uintptr_t)obj);
            mp_obj_dict_store(memo, id_obj, result);
        }
        return result;
    }
    
    // List: create new list with deep-copied elements
    if (type == &mp_type_list) {
        size_t len;
        mp_obj_t *items;
        mp_obj_list_get(obj, &len, &items);
        
        result = mp_obj_new_list(0, NULL);
        
        // Store in memo before recursing (handles circular references)
        if (memo != mp_const_none) {
            mp_obj_t id_obj = mp_obj_new_int((mp_int_t)(uintptr_t)obj);
            mp_obj_dict_store(memo, id_obj, result);
        }
        
        for (size_t i = 0; i < len; i++) {
            mp_obj_list_append(result, do_deepcopy(items[i], memo));
        }
        return result;
    }
    
    // Dict: create new dict with deep-copied keys and values
    if (type == &mp_type_dict) {
        result = mp_obj_new_dict(0);
        
        if (memo != mp_const_none) {
            mp_obj_t id_obj = mp_obj_new_int((mp_int_t)(uintptr_t)obj);
            mp_obj_dict_store(memo, id_obj, result);
        }
        
        mp_map_t *map = mp_obj_dict_get_map(obj);
        for (size_t i = 0; i < map->alloc; i++) {
            if (mp_map_slot_is_filled(map, i)) {
                mp_obj_t key = do_deepcopy(map->table[i].key, memo);
                mp_obj_t value = do_deepcopy(map->table[i].value, memo);
                mp_obj_dict_store(result, key, value);
            }
        }
        return result;
    }
    
    // Set: create new set with deep-copied elements
    if (type == &mp_type_set) {
        result = mp_obj_new_set(0, NULL);
        
        if (memo != mp_const_none) {
            mp_obj_t id_obj = mp_obj_new_int((mp_int_t)(uintptr_t)obj);
            mp_obj_dict_store(memo, id_obj, result);
        }
        
        mp_obj_t iter = mp_getiter(obj, NULL);
        mp_obj_t item;
        while ((item = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
            mp_obj_set_store(result, do_deepcopy(item, memo));
        }
        return result;
    }
    
    // Bytearray: create new bytearray with same content
    if (type == &mp_type_bytearray) {
        mp_buffer_info_t bufinfo;
        mp_get_buffer_raise(obj, &bufinfo, MP_BUFFER_READ);
        result = mp_obj_new_bytearray(bufinfo.len, bufinfo.buf);
        
        if (memo != mp_const_none) {
            mp_obj_t id_obj = mp_obj_new_int((mp_int_t)(uintptr_t)obj);
            mp_obj_dict_store(memo, id_obj, result);
        }
        return result;
    }
    
    // For other objects, try to use __deepcopy__ method if available
    mp_obj_t dest[2];
    mp_load_method_maybe(obj, MP_QSTR___deepcopy__, dest);
    if (dest[0] != MP_OBJ_NULL) {
        return mp_call_method_n_kw(1, 0, (mp_obj_t[]){dest[0], dest[1], memo});
    }
    
    // Try __copy__ as fallback
    mp_load_method_maybe(obj, MP_QSTR___copy__, dest);
    if (dest[0] != MP_OBJ_NULL) {
        return mp_call_method_n_kw(0, 0, dest);
    }
    
    // Fallback: return the same object
    return obj;
}

MPY_FUNC_VAR(copy, deepcopy, 1, 2) {
    mp_obj_t obj = args[0];
    mp_obj_t memo;
    
    if (n_args > 1 && args[1] != mp_const_none) {
        memo = args[1];
    } else {
        memo = mp_obj_new_dict(0);
    }
    
    return do_deepcopy(obj, memo);
}
MPY_FUNC_OBJ_VAR(copy, deepcopy, 1, 2);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(copy)
    MPY_MODULE_FUNC(copy, copy)
    MPY_MODULE_FUNC(copy, deepcopy)
MPY_MODULE_END(copy)
