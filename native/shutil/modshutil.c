/*
 * modshutil - Native shell utilities module for microcharm
 * 
 * This module bridges Zig's shutil implementation to MicroPython.
 * 
 * Usage in Python:
 *   import shutil
 *   shutil.copy("src.txt", "dst.txt")
 *   shutil.move("old.txt", "new.txt")
 *   shutil.rmtree("mydir")
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// External Zig functions
extern int shutil_copy(const char *src, size_t src_len,
                       const char *dst, size_t dst_len);
extern int shutil_copy2(const char *src, size_t src_len,
                        const char *dst, size_t dst_len);
extern int shutil_move(const char *src, size_t src_len,
                       const char *dst, size_t dst_len);
extern int shutil_rmtree(const char *path, size_t path_len);
extern int shutil_makedirs(const char *path, size_t path_len);
extern int shutil_exists(const char *path, size_t path_len);
extern int shutil_isfile(const char *path, size_t path_len);
extern int shutil_isdir(const char *path, size_t path_len);
extern int64_t shutil_getsize(const char *path, size_t path_len);
extern int shutil_copytree(const char *src, size_t src_len,
                           const char *dst, size_t dst_len);

// ============================================================================
// shutil functions
// ============================================================================

// shutil.copy(src, dst) -> None
MPY_FUNC_2(shutil, copy) {
    size_t src_len, dst_len;
    const char *src = mpy_str_len(arg0, &src_len);
    const char *dst = mpy_str_len(arg1, &dst_len);
    
    if (shutil_copy(src, src_len, dst, dst_len) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_2(shutil, copy);

// shutil.copy2(src, dst) -> None (preserves metadata)
MPY_FUNC_2(shutil, copy2) {
    size_t src_len, dst_len;
    const char *src = mpy_str_len(arg0, &src_len);
    const char *dst = mpy_str_len(arg1, &dst_len);
    
    if (shutil_copy2(src, src_len, dst, dst_len) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_2(shutil, copy2);

// shutil.copyfile(src, dst) -> dst (alias for copy)
MPY_FUNC_2(shutil, copyfile) {
    size_t src_len, dst_len;
    const char *src = mpy_str_len(arg0, &src_len);
    const char *dst = mpy_str_len(arg1, &dst_len);
    
    if (shutil_copy(src, src_len, dst, dst_len) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return arg1;  // Return dst path
}
MPY_FUNC_OBJ_2(shutil, copyfile);

// shutil.copytree(src, dst) -> None
MPY_FUNC_2(shutil, copytree) {
    size_t src_len, dst_len;
    const char *src = mpy_str_len(arg0, &src_len);
    const char *dst = mpy_str_len(arg1, &dst_len);
    
    if (shutil_copytree(src, src_len, dst, dst_len) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_2(shutil, copytree);

// shutil.move(src, dst) -> None
MPY_FUNC_2(shutil, move) {
    size_t src_len, dst_len;
    const char *src = mpy_str_len(arg0, &src_len);
    const char *dst = mpy_str_len(arg1, &dst_len);
    
    if (shutil_move(src, src_len, dst, dst_len) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_2(shutil, move);

// shutil.rmtree(path) -> None
MPY_FUNC_1(shutil, rmtree) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    if (shutil_rmtree(path, path_len) < 0) {
        mp_raise_OSError(MP_ENOENT);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_1(shutil, rmtree);

// shutil.makedirs(path) -> None (os.makedirs equivalent)
MPY_FUNC_1(shutil, makedirs) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    if (shutil_makedirs(path, path_len) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_1(shutil, makedirs);

// ============================================================================
// os.path-like functions (bonus utilities)
// ============================================================================

// shutil.exists(path) -> bool
MPY_FUNC_1(shutil, exists) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    return mpy_bool(shutil_exists(path, path_len) == 1);
}
MPY_FUNC_OBJ_1(shutil, exists);

// shutil.isfile(path) -> bool
MPY_FUNC_1(shutil, isfile) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    return mpy_bool(shutil_isfile(path, path_len) == 1);
}
MPY_FUNC_OBJ_1(shutil, isfile);

// shutil.isdir(path) -> bool
MPY_FUNC_1(shutil, isdir) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    return mpy_bool(shutil_isdir(path, path_len) == 1);
}
MPY_FUNC_OBJ_1(shutil, isdir);

// shutil.getsize(path) -> int
MPY_FUNC_1(shutil, getsize) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    int64_t size = shutil_getsize(path, path_len);
    if (size < 0) {
        mp_raise_OSError(MP_ENOENT);
    }
    return mp_obj_new_int_from_ll(size);
}
MPY_FUNC_OBJ_1(shutil, getsize);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(shutil)
    MPY_MODULE_FUNC(shutil, copy)
    MPY_MODULE_FUNC(shutil, copy2)
    MPY_MODULE_FUNC(shutil, copyfile)
    MPY_MODULE_FUNC(shutil, copytree)
    MPY_MODULE_FUNC(shutil, move)
    MPY_MODULE_FUNC(shutil, rmtree)
    MPY_MODULE_FUNC(shutil, makedirs)
    MPY_MODULE_FUNC(shutil, exists)
    MPY_MODULE_FUNC(shutil, isfile)
    MPY_MODULE_FUNC(shutil, isdir)
    MPY_MODULE_FUNC(shutil, getsize)
MPY_MODULE_END(shutil)
