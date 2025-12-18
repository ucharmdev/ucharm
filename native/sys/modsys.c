/*
 * modsys.c - Extension to MicroPython's sys module
 *
 * Adds missing CPython-compatible functions/attributes:
 *   - sys.getrecursionlimit() / setrecursionlimit()
 *   - sys.getsizeof() - approximate
 *   - sys.intern()
 *   - sys.flags - empty flags object
 */

#include "py/runtime.h"
#include "py/obj.h"
#include "py/objstr.h"

// Global recursion limit (just a variable, not enforced)
static mp_int_t recursion_limit = 1000;

// sys.getrecursionlimit() -> int
static mp_obj_t sys_ext_getrecursionlimit(void) {
    return mp_obj_new_int(recursion_limit);
}
static MP_DEFINE_CONST_FUN_OBJ_0(sys_ext_getrecursionlimit_obj, sys_ext_getrecursionlimit);

// sys.setrecursionlimit(limit)
static mp_obj_t sys_ext_setrecursionlimit(mp_obj_t limit_in) {
    mp_int_t limit = mp_obj_get_int(limit_in);
    if (limit <= 0) {
        mp_raise_ValueError(MP_ERROR_TEXT("recursion limit must be positive"));
    }
    recursion_limit = limit;
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_1(sys_ext_setrecursionlimit_obj, sys_ext_setrecursionlimit);

// sys.getsizeof(obj) -> int
// Returns approximate size in bytes (best effort for MicroPython)
static mp_obj_t sys_ext_getsizeof(size_t n_args, const mp_obj_t *args) {
    mp_obj_t obj = args[0];
    
    // Return approximate sizes based on type
    if (mp_obj_is_small_int(obj)) {
        return mp_obj_new_int(sizeof(mp_int_t));
    }
    if (mp_obj_is_str(obj)) {
        size_t len;
        mp_obj_str_get_data(obj, &len);
        return mp_obj_new_int(sizeof(mp_obj_str_t) + len + 1);
    }
    if (mp_obj_is_type(obj, &mp_type_bytes)) {
        mp_buffer_info_t bufinfo;
        mp_get_buffer_raise(obj, &bufinfo, MP_BUFFER_READ);
        return mp_obj_new_int(sizeof(mp_obj_str_t) + bufinfo.len);
    }
    if (mp_obj_is_type(obj, &mp_type_list)) {
        mp_obj_list_t *list = MP_OBJ_TO_PTR(obj);
        return mp_obj_new_int(sizeof(mp_obj_list_t) + list->alloc * sizeof(mp_obj_t));
    }
    if (mp_obj_is_type(obj, &mp_type_dict)) {
        mp_obj_dict_t *dict = MP_OBJ_TO_PTR(obj);
        return mp_obj_new_int(sizeof(mp_obj_dict_t) + dict->map.alloc * sizeof(mp_map_elem_t));
    }
    if (mp_obj_is_type(obj, &mp_type_tuple)) {
        mp_obj_tuple_t *tuple = MP_OBJ_TO_PTR(obj);
        return mp_obj_new_int(sizeof(mp_obj_tuple_t) + tuple->len * sizeof(mp_obj_t));
    }
    
    // Default size for unknown objects
    return mp_obj_new_int(sizeof(mp_obj_base_t));
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(sys_ext_getsizeof_obj, 1, 2, sys_ext_getsizeof);

// Interned string cache (simple dict-based implementation)
static mp_obj_t intern_cache = MP_OBJ_NULL;

// sys.intern(string) -> string
static mp_obj_t sys_ext_intern(mp_obj_t str_in) {
    if (!mp_obj_is_str(str_in)) {
        mp_raise_TypeError(MP_ERROR_TEXT("intern() argument must be string"));
    }
    
    // Initialize cache if needed
    if (intern_cache == MP_OBJ_NULL) {
        intern_cache = mp_obj_new_dict(16);
    }
    
    // Check if already interned
    mp_obj_dict_t *cache = MP_OBJ_TO_PTR(intern_cache);
    mp_map_elem_t *elem = mp_map_lookup(&cache->map, str_in, MP_MAP_LOOKUP);
    if (elem != NULL) {
        return elem->value;
    }
    
    // Intern the string (store it as both key and value)
    mp_obj_dict_store(intern_cache, str_in, str_in);
    return str_in;
}
static MP_DEFINE_CONST_FUN_OBJ_1(sys_ext_intern_obj, sys_ext_intern);

// sys.flags - simple object with default attributes
typedef struct _mp_obj_flags_t {
    mp_obj_base_t base;
} mp_obj_flags_t;

static void flags_attr(mp_obj_t self_in, qstr attr, mp_obj_t *dest) {
    (void)self_in;
    if (dest[0] != MP_OBJ_NULL) return;
    
    // All flags are 0/False by default
    if (attr == MP_QSTR_debug ||
        attr == MP_QSTR_inspect ||
        attr == MP_QSTR_interactive ||
        attr == MP_QSTR_optimize ||
        attr == MP_QSTR_dont_write_bytecode ||
        attr == MP_QSTR_no_user_site ||
        attr == MP_QSTR_no_site ||
        attr == MP_QSTR_ignore_environment ||
        attr == MP_QSTR_verbose ||
        attr == MP_QSTR_bytes_warning ||
        attr == MP_QSTR_quiet ||
        attr == MP_QSTR_hash_randomization ||
        attr == MP_QSTR_isolated ||
        attr == MP_QSTR_dev_mode ||
        attr == MP_QSTR_utf8_mode) {
        dest[0] = MP_OBJ_NEW_SMALL_INT(0);
    }
}

static void flags_print(const mp_print_t *print, mp_obj_t self_in, mp_print_kind_t kind) {
    (void)self_in;
    (void)kind;
    mp_print_str(print, "sys.flags(debug=0, inspect=0, interactive=0, optimize=0, ...)");
}

MP_DEFINE_CONST_OBJ_TYPE(
    mp_type_flags,
    MP_QSTR_flags,
    MP_TYPE_FLAG_NONE,
    attr, flags_attr,
    print, flags_print
);

static const mp_obj_flags_t flags_obj = {{&mp_type_flags}};

// Delegation handler for sys module attribute lookup
void sys_ext_attr(mp_obj_t self_in, qstr attr, mp_obj_t *dest) {
    (void)self_in;
    
    if (attr == MP_QSTR_getrecursionlimit) {
        dest[0] = MP_OBJ_FROM_PTR(&sys_ext_getrecursionlimit_obj);
    } else if (attr == MP_QSTR_setrecursionlimit) {
        dest[0] = MP_OBJ_FROM_PTR(&sys_ext_setrecursionlimit_obj);
    } else if (attr == MP_QSTR_getsizeof) {
        dest[0] = MP_OBJ_FROM_PTR(&sys_ext_getsizeof_obj);
    } else if (attr == MP_QSTR_intern) {
        dest[0] = MP_OBJ_FROM_PTR(&sys_ext_intern_obj);
    } else if (attr == MP_QSTR_flags) {
        dest[0] = MP_OBJ_FROM_PTR(&flags_obj);
    }
}

// Declare external reference to mp_module_sys
extern const mp_obj_module_t mp_module_sys;

// Register as delegate/extension to the sys module
MP_REGISTER_MODULE_DELEGATION(mp_module_sys, sys_ext_attr);
