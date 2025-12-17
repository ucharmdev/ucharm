/*
 * mpy_bridge.h - MicroPython <-> Zig Bridge Helpers
 * 
 * This header provides macros and utilities to simplify creating
 * MicroPython modules that wrap Zig code.
 * 
 * Usage:
 *   #include "mpy_bridge.h"
 *   
 *   // Declare Zig functions
 *   ZIG_EXTERN bool my_func(const char *str);
 *   
 *   // Wrap with MicroPython API
 *   MPY_FUNC_1(mymodule, my_func) {
 *       const char *str = mpy_str(args[0]);
 *       return mpy_bool(my_func(str));
 *   }
 *   
 *   // Define module
 *   MPY_MODULE_BEGIN(mymodule)
 *       MPY_MODULE_FUNC(my_func, 1)
 *   MPY_MODULE_END(mymodule)
 */

#ifndef MPY_BRIDGE_H
#define MPY_BRIDGE_H

#include "py/runtime.h"
#include "py/obj.h"
#include "py/objstr.h"

#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

// ============================================================================
// Zig Function Declaration Helpers
// ============================================================================

// Mark a function as extern (implemented in Zig)
#define ZIG_EXTERN extern

// ============================================================================
// Type Conversion: MicroPython -> C
// ============================================================================

// Get C string from MicroPython object
static inline const char *mpy_str(mp_obj_t obj) {
    return mp_obj_str_get_str(obj);
}

// Get C string with length from MicroPython object
static inline const char *mpy_str_len(mp_obj_t obj, size_t *len) {
    return mp_obj_str_get_data(obj, len);
}

// Get int from MicroPython object
static inline mp_int_t mpy_int(mp_obj_t obj) {
    return mp_obj_get_int(obj);
}

// Get bool from MicroPython object
static inline bool mpy_to_bool(mp_obj_t obj) {
    return mp_obj_is_true(obj);
}

// Get float from MicroPython object
static inline mp_float_t mpy_float(mp_obj_t obj) {
    return mp_obj_get_float(obj);
}

// Get bytes data with length from MicroPython object
static inline const char *mpy_bytes_len(mp_obj_t obj, size_t *len) {
    mp_buffer_info_t bufinfo;
    mp_get_buffer_raise(obj, &bufinfo, MP_BUFFER_READ);
    *len = bufinfo.len;
    return (const char *)bufinfo.buf;
}

// ============================================================================
// Memory Allocation Helpers
// ============================================================================

// Allocate memory (MicroPython managed)
static inline void *mpy_alloc(size_t size) {
    return m_malloc(size);
}

// Free memory (MicroPython managed) - handles API differences
static inline void mpy_free(void *ptr, size_t size) {
    m_free(ptr, size);
}

// Allocate array of doubles
static inline double *mpy_alloc_doubles(size_t count) {
    return (double *)m_malloc(count * sizeof(double));
}

// Free array of doubles
static inline void mpy_free_doubles(double *ptr, size_t count) {
    m_free(ptr, count * sizeof(double));
}

// ============================================================================
// Type Conversion: C -> MicroPython
// ============================================================================

// Create MicroPython string from C string
static inline mp_obj_t mpy_new_str(const char *str) {
    return mp_obj_new_str(str, strlen(str));
}

// Create MicroPython string with length
static inline mp_obj_t mpy_new_str_len(const char *str, size_t len) {
    return mp_obj_new_str(str, len);
}

// Create MicroPython int
static inline mp_obj_t mpy_new_int(mp_int_t val) {
    return mp_obj_new_int(val);
}

// Create MicroPython int from int64
static inline mp_obj_t mpy_new_int64(int64_t val) {
    return mp_obj_new_int(val);
}

// Create MicroPython bool
static inline mp_obj_t mpy_bool(bool val) {
    return val ? mp_const_true : mp_const_false;
}

// Create MicroPython float
static inline mp_obj_t mpy_new_float(mp_float_t val) {
    return mp_obj_new_float(val);
}

// None constant
#define mpy_none() mp_const_none

// ============================================================================
// Tuple/List Helpers
// ============================================================================

// Create a 2-tuple
static inline mp_obj_t mpy_tuple2(mp_obj_t a, mp_obj_t b) {
    mp_obj_t items[2] = {a, b};
    return mp_obj_new_tuple(2, items);
}

// Create a 3-tuple
static inline mp_obj_t mpy_tuple3(mp_obj_t a, mp_obj_t b, mp_obj_t c) {
    mp_obj_t items[3] = {a, b, c};
    return mp_obj_new_tuple(3, items);
}

// Create empty list
static inline mp_obj_t mpy_new_list(void) {
    return mp_obj_new_list(0, NULL);
}

// Append to list
static inline void mpy_list_append(mp_obj_t list, mp_obj_t item) {
    mp_obj_list_append(list, item);
}

// ============================================================================
// Dict Helpers
// ============================================================================

// Create empty dict
static inline mp_obj_t mpy_new_dict(void) {
    return mp_obj_new_dict(0);
}

// Store in dict (string key)
static inline void mpy_dict_store_str(mp_obj_t dict, const char *key, mp_obj_t val) {
    mp_obj_dict_store(dict, mpy_new_str(key), val);
}

// Store in dict
static inline void mpy_dict_store(mp_obj_t dict, mp_obj_t key, mp_obj_t val) {
    mp_obj_dict_store(dict, key, val);
}

// ============================================================================
// Function Definition Macros
// ============================================================================

// Define a function with 0 arguments
#define MPY_FUNC_0(module, name) \
    static mp_obj_t mod_##module##_##name(void)

// Define a function with 1 argument
#define MPY_FUNC_1(module, name) \
    static mp_obj_t mod_##module##_##name(mp_obj_t arg0)

// Define a function with 2 arguments
#define MPY_FUNC_2(module, name) \
    static mp_obj_t mod_##module##_##name(mp_obj_t arg0, mp_obj_t arg1)

// Define a function with 3 arguments
#define MPY_FUNC_3(module, name) \
    static mp_obj_t mod_##module##_##name(mp_obj_t arg0, mp_obj_t arg1, mp_obj_t arg2)

// Define a function with variable arguments
#define MPY_FUNC_VAR(module, name, min, max) \
    static mp_obj_t mod_##module##_##name(size_t n_args, const mp_obj_t *args)

// Define function object after the function body
#define MPY_FUNC_OBJ_0(module, name) \
    static MP_DEFINE_CONST_FUN_OBJ_0(mod_##module##_##name##_obj, mod_##module##_##name)

#define MPY_FUNC_OBJ_1(module, name) \
    static MP_DEFINE_CONST_FUN_OBJ_1(mod_##module##_##name##_obj, mod_##module##_##name)

#define MPY_FUNC_OBJ_2(module, name) \
    static MP_DEFINE_CONST_FUN_OBJ_2(mod_##module##_##name##_obj, mod_##module##_##name)

#define MPY_FUNC_OBJ_3(module, name) \
    static MP_DEFINE_CONST_FUN_OBJ_3(mod_##module##_##name##_obj, mod_##module##_##name)

#define MPY_FUNC_OBJ_VAR(module, name, min, max) \
    static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_##module##_##name##_obj, min, max, mod_##module##_##name)

// ============================================================================
// Module Definition Macros
// ============================================================================

// Begin module globals table
#define MPY_MODULE_BEGIN(name) \
    static const mp_rom_map_elem_t name##_module_globals_table[] = { \
        { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR_##name) },

// Add a function to the module
#define MPY_MODULE_FUNC(module, name) \
        { MP_ROM_QSTR(MP_QSTR_##name), MP_ROM_PTR(&mod_##module##_##name##_obj) },

// Add a constant int to the module
#define MPY_MODULE_INT(name, value) \
        { MP_ROM_QSTR(MP_QSTR_##name), MP_ROM_INT(value) },

// Add a constant string to the module
#define MPY_MODULE_STR(name, value) \
        { MP_ROM_QSTR(MP_QSTR_##name), MP_ROM_QSTR(MP_QSTR_##value) },

// End module globals table and create module
// NOTE: The semicolon after MP_REGISTER_MODULE is required for MicroPython's
// build system to detect the module registration (makeqstrdefs.py regex)
#define MPY_MODULE_END(name) \
    }; \
    static MP_DEFINE_CONST_DICT(name##_module_globals, name##_module_globals_table); \
    const mp_obj_module_t mp_module_##name = { \
        .base = { &mp_type_module }, \
        .globals = (mp_obj_dict_t *)&name##_module_globals, \
    }; \
    MP_REGISTER_MODULE(MP_QSTR_##name, mp_module_##name);

// ============================================================================
// Error Handling
// ============================================================================

// Raise a ValueError
#define mpy_raise_value_error(msg) \
    mp_raise_ValueError(MP_ERROR_TEXT(msg))

// Raise a TypeError
#define mpy_raise_type_error(msg) \
    mp_raise_TypeError(MP_ERROR_TEXT(msg))

// Raise a RuntimeError
#define mpy_raise_runtime_error(msg) \
    mp_raise_msg(&mp_type_RuntimeError, MP_ERROR_TEXT(msg))

// Raise OSError with errno
#define mpy_raise_oserror(err) \
    mp_raise_OSError(err)

// Common error codes (POSIX)
#include <errno.h>
#ifndef MP_EIO
#define MP_EIO EIO
#endif
#ifndef MP_ENOENT
#define MP_ENOENT ENOENT
#endif
#ifndef MP_EEXIST
#define MP_EEXIST EEXIST
#endif
#ifndef MP_EACCES
#define MP_EACCES EACCES
#endif
#ifndef MP_EINVAL
#define MP_EINVAL EINVAL
#endif

// ============================================================================
// Bytes Helpers
// ============================================================================

// Create MicroPython bytes from data
static inline mp_obj_t mpy_new_bytes(const char *data, size_t len) {
    return mp_obj_new_bytes((const byte *)data, len);
}

#endif // MPY_BRIDGE_H
