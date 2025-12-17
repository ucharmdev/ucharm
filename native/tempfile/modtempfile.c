/*
 * modtempfile - Native temporary file module for ucharm
 * 
 * This module bridges Zig's tempfile implementation to MicroPython.
 * 
 * Usage in Python:
 *   import tempfile
 *   tmp = tempfile.gettempdir()
 *   path = tempfile.mkstemp(prefix="my_", suffix=".txt")
 *   tempfile.mkdtemp(prefix="my_dir_")
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// External Zig functions
extern int tempfile_gettempdir(char *output, size_t output_len);
extern int tempfile_mktemp(const char *prefix, size_t prefix_len,
                           const char *suffix, size_t suffix_len,
                           char *output, size_t output_len);
extern int tempfile_mkstemp(const char *prefix, size_t prefix_len,
                            const char *suffix, size_t suffix_len,
                            char *output, size_t output_len);
extern int tempfile_mkdtemp(const char *prefix, size_t prefix_len,
                            const char *suffix, size_t suffix_len,
                            char *output, size_t output_len);
extern int tempfile_unlink(const char *path, size_t path_len);
extern int tempfile_rmdir(const char *path, size_t path_len);
extern int tempfile_rmtree(const char *path, size_t path_len);

// ============================================================================
// tempfile functions
// ============================================================================

// tempfile.gettempdir() -> str
MPY_FUNC_0(tempfile, gettempdir) {
    char buf[4096];
    int len = tempfile_gettempdir(buf, sizeof(buf));
    if (len < 0) {
        return mpy_new_str("/tmp");
    }
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_0(tempfile, gettempdir);

// tempfile.mktemp(prefix="tmp", suffix="") -> str
MPY_FUNC_VAR(tempfile, mktemp, 0, 2) {
    const char *prefix = "tmp";
    size_t prefix_len = 3;
    const char *suffix = "";
    size_t suffix_len = 0;
    
    if (n_args >= 1 && args[0] != mp_const_none) {
        prefix = mpy_str_len(args[0], &prefix_len);
    }
    if (n_args >= 2 && args[1] != mp_const_none) {
        suffix = mpy_str_len(args[1], &suffix_len);
    }
    
    char buf[4096];
    int len = tempfile_mktemp(prefix, prefix_len, suffix, suffix_len, buf, sizeof(buf));
    if (len < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_VAR(tempfile, mktemp, 0, 2);

// tempfile.mkstemp(prefix="tmp", suffix="") -> str (path to created file)
MPY_FUNC_VAR(tempfile, mkstemp, 0, 2) {
    const char *prefix = "tmp";
    size_t prefix_len = 3;
    const char *suffix = "";
    size_t suffix_len = 0;
    
    if (n_args >= 1 && args[0] != mp_const_none) {
        prefix = mpy_str_len(args[0], &prefix_len);
    }
    if (n_args >= 2 && args[1] != mp_const_none) {
        suffix = mpy_str_len(args[1], &suffix_len);
    }
    
    char buf[4096];
    int len = tempfile_mkstemp(prefix, prefix_len, suffix, suffix_len, buf, sizeof(buf));
    if (len < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_VAR(tempfile, mkstemp, 0, 2);

// tempfile.mkdtemp(prefix="tmp", suffix="") -> str (path to created directory)
MPY_FUNC_VAR(tempfile, mkdtemp, 0, 2) {
    const char *prefix = "tmp";
    size_t prefix_len = 3;
    const char *suffix = "";
    size_t suffix_len = 0;
    
    if (n_args >= 1 && args[0] != mp_const_none) {
        prefix = mpy_str_len(args[0], &prefix_len);
    }
    if (n_args >= 2 && args[1] != mp_const_none) {
        suffix = mpy_str_len(args[1], &suffix_len);
    }
    
    char buf[4096];
    int len = tempfile_mkdtemp(prefix, prefix_len, suffix, suffix_len, buf, sizeof(buf));
    if (len < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_VAR(tempfile, mkdtemp, 0, 2);

// ============================================================================
// Cleanup functions (bonus - useful utilities)
// ============================================================================

// tempfile.unlink(path) -> None
MPY_FUNC_1(tempfile, unlink) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    if (tempfile_unlink(path, path_len) < 0) {
        mp_raise_OSError(MP_ENOENT);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_1(tempfile, unlink);

// tempfile.rmdir(path) -> None
MPY_FUNC_1(tempfile, rmdir) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    if (tempfile_rmdir(path, path_len) < 0) {
        mp_raise_OSError(MP_ENOENT);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_1(tempfile, rmdir);

// tempfile.rmtree(path) -> None (recursive delete)
MPY_FUNC_1(tempfile, rmtree) {
    size_t path_len;
    const char *path = mpy_str_len(arg0, &path_len);
    
    if (tempfile_rmtree(path, path_len) < 0) {
        mp_raise_OSError(MP_ENOENT);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_1(tempfile, rmtree);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(tempfile)
    MPY_MODULE_FUNC(tempfile, gettempdir)
    MPY_MODULE_FUNC(tempfile, mktemp)
    MPY_MODULE_FUNC(tempfile, mkstemp)
    MPY_MODULE_FUNC(tempfile, mkdtemp)
    MPY_MODULE_FUNC(tempfile, unlink)
    MPY_MODULE_FUNC(tempfile, rmdir)
    MPY_MODULE_FUNC(tempfile, rmtree)
MPY_MODULE_END(tempfile)
