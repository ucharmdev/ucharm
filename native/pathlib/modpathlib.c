/*
 * modpathlib - Native path operations module for microcharm
 * 
 * This module bridges Zig's pathlib implementation to MicroPython.
 * Provides low-level path manipulation functions.
 * 
 * Note: The full Path class is implemented in Python and uses these
 * native functions for performance-critical operations.
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// External Zig functions
extern int path_basename(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_dirname(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_extname(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_stem(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_is_absolute(const char *path, size_t path_len);
extern int path_join(const char *path1, size_t path1_len, const char *path2, size_t path2_len,
                     char *output, size_t output_len);
extern int path_normalize(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_exists(const char *path, size_t path_len);
extern int path_is_file(const char *path, size_t path_len);
extern int path_is_dir(const char *path, size_t path_len);
extern int64_t path_getsize(const char *path, size_t path_len);
extern int path_getcwd(char *output, size_t output_len);

// ============================================================================
// Path manipulation functions
// ============================================================================

// path.basename(p) -> str
MPY_FUNC_1(path, basename) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    char buf[4096];
    int len = path_basename(path, path_len, buf, sizeof(buf));
    if (len < 0) return mpy_new_str("");
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_1(path, basename);

// path.dirname(p) -> str
MPY_FUNC_1(path, dirname) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    char buf[4096];
    int len = path_dirname(path, path_len, buf, sizeof(buf));
    if (len < 0) return mpy_new_str(".");
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_1(path, dirname);

// path.extname(p) -> str
MPY_FUNC_1(path, extname) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    char buf[256];
    int len = path_extname(path, path_len, buf, sizeof(buf));
    if (len < 0) return mpy_new_str("");
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_1(path, extname);

// path.stem(p) -> str
MPY_FUNC_1(path, stem) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    char buf[4096];
    int len = path_stem(path, path_len, buf, sizeof(buf));
    if (len < 0) return mpy_new_str("");
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_1(path, stem);

// path.is_absolute(p) -> bool
MPY_FUNC_1(path, is_absolute) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    return mpy_bool(path_is_absolute(path, path_len) == 1);
}
MPY_FUNC_OBJ_1(path, is_absolute);

// path.join(p1, p2) -> str
MPY_FUNC_2(path, join) {
    size_t p1_len, p2_len;
    const char *p1 = mpy_str_len(arg0, &p1_len);
    const char *p2 = mpy_str_len(arg1, &p2_len);
    
    char buf[8192];
    int len = path_join(p1, p1_len, p2, p2_len, buf, sizeof(buf));
    if (len < 0) return mpy_new_str("");
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_2(path, join);

// path.normalize(p) -> str
MPY_FUNC_1(path, normalize) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    char buf[4096];
    int len = path_normalize(path, path_len, buf, sizeof(buf));
    if (len < 0) return arg0;  // Return original on error
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_1(path, normalize);

// ============================================================================
// Filesystem operations
// ============================================================================

// path.exists(p) -> bool
MPY_FUNC_1(path, exists) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    return mpy_bool(path_exists(path, path_len) == 1);
}
MPY_FUNC_OBJ_1(path, exists);

// path.isfile(p) -> bool
MPY_FUNC_1(path, isfile) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    return mpy_bool(path_is_file(path, path_len) == 1);
}
MPY_FUNC_OBJ_1(path, isfile);

// path.isdir(p) -> bool
MPY_FUNC_1(path, isdir) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    return mpy_bool(path_is_dir(path, path_len) == 1);
}
MPY_FUNC_OBJ_1(path, isdir);

// path.getsize(p) -> int
MPY_FUNC_1(path, getsize) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    int64_t size = path_getsize(path, path_len);
    if (size < 0) {
        mp_raise_OSError(MP_ENOENT);
    }
    return mp_obj_new_int_from_ll(size);
}
MPY_FUNC_OBJ_1(path, getsize);

// path.getcwd() -> str
MPY_FUNC_0(path, getcwd) {
    char buf[4096];
    int len = path_getcwd(buf, sizeof(buf));
    if (len < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_0(path, getcwd);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(path)
    MPY_MODULE_FUNC(path, basename)
    MPY_MODULE_FUNC(path, dirname)
    MPY_MODULE_FUNC(path, extname)
    MPY_MODULE_FUNC(path, stem)
    MPY_MODULE_FUNC(path, is_absolute)
    MPY_MODULE_FUNC(path, join)
    MPY_MODULE_FUNC(path, normalize)
    MPY_MODULE_FUNC(path, exists)
    MPY_MODULE_FUNC(path, isfile)
    MPY_MODULE_FUNC(path, isdir)
    MPY_MODULE_FUNC(path, getsize)
    MPY_MODULE_FUNC(path, getcwd)
MPY_MODULE_END(path)
