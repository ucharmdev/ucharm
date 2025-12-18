/*
 * modfnmatch.c - Native fnmatch module for ucharm
 *
 * Provides Unix shell-style pattern matching:
 * - fnmatch(name, pattern) - Test if name matches pattern
 * - fnmatchcase(name, pattern) - Case-sensitive matching  
 * - filter(names, pattern) - Filter list by pattern
 * - translate(pattern) - Convert pattern to regex
 *
 * Pattern syntax:
 *   *      - matches everything
 *   ?      - matches any single character
 *   [seq]  - matches any character in seq
 *   [!seq] - matches any character not in seq
 *
 * Usage in Python:
 *   import fnmatch
 *   fnmatch.fnmatch('hello.txt', '*.txt')  # True
 *   fnmatch.filter(['a.py', 'b.txt'], '*.py')  # ['a.py']
 */

#include "../bridge/mpy_bridge.h"

// ============================================================================
// Zig Function Declarations
// ============================================================================

ZIG_EXTERN bool fnmatch_fnmatch(const char *name, const char *pattern);
ZIG_EXTERN bool fnmatch_fnmatchcase(const char *name, const char *pattern);
ZIG_EXTERN size_t fnmatch_translate(const char *pattern, char *buf, size_t buf_size);

// ============================================================================
// fnmatch.fnmatch(name, pattern) -> bool
// ============================================================================

MPY_FUNC_2(fnmatch, fnmatch) {
    const char *name = mpy_str(arg0);
    const char *pattern = mpy_str(arg1);
    return mpy_bool(fnmatch_fnmatch(name, pattern));
}
MPY_FUNC_OBJ_2(fnmatch, fnmatch);

// ============================================================================
// fnmatch.fnmatchcase(name, pattern) -> bool
// ============================================================================

MPY_FUNC_2(fnmatch, fnmatchcase) {
    const char *name = mpy_str(arg0);
    const char *pattern = mpy_str(arg1);
    return mpy_bool(fnmatch_fnmatchcase(name, pattern));
}
MPY_FUNC_OBJ_2(fnmatch, fnmatchcase);

// ============================================================================
// fnmatch.filter(names, pattern) -> list
// ============================================================================

MPY_FUNC_2(fnmatch, filter) {
    mp_obj_t names_obj = arg0;
    const char *pattern = mpy_str(arg1);
    
    // Get the iterable
    mp_obj_t iter = mp_getiter(names_obj, NULL);
    mp_obj_t result = mpy_new_list();
    
    mp_obj_t item;
    while ((item = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        const char *name = mpy_str(item);
        if (fnmatch_fnmatch(name, pattern)) {
            mpy_list_append(result, item);
        }
    }
    
    return result;
}
MPY_FUNC_OBJ_2(fnmatch, filter);

// ============================================================================
// fnmatch.translate(pattern) -> str
// ============================================================================

MPY_FUNC_1(fnmatch, translate) {
    const char *pattern = mpy_str(arg0);
    
    // Allocate buffer for regex (pattern * 4 should be enough for escaping)
    size_t pattern_len = strlen(pattern);
    size_t buf_size = pattern_len * 4 + 16;
    char *buf = mpy_alloc(buf_size);
    
    size_t len = fnmatch_translate(pattern, buf, buf_size);
    mp_obj_t result = mpy_new_str_len(buf, len);
    
    mpy_free(buf, buf_size);
    return result;
}
MPY_FUNC_OBJ_1(fnmatch, translate);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(fnmatch)
    MPY_MODULE_FUNC(fnmatch, fnmatch)
    MPY_MODULE_FUNC(fnmatch, fnmatchcase)
    MPY_MODULE_FUNC(fnmatch, filter)
    MPY_MODULE_FUNC(fnmatch, translate)
MPY_MODULE_END(fnmatch)
