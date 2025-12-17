/*
 * modglob - Native glob/fnmatch module for microcharm
 * 
 * This module bridges Zig's glob implementation to MicroPython.
 * 
 * Usage in Python:
 *   import glob
 *   files = glob.glob("*.py")
 *   if glob.fnmatch("test.py", "*.py"): ...
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// External Zig functions
extern int glob_fnmatch(const char *pattern, size_t pattern_len, 
                        const char *name, size_t name_len);
extern int glob_match_path(const char *pattern, size_t pattern_len,
                           const char *path, size_t path_len);

// Callback for glob results - accumulates into a Python list
typedef struct {
    mp_obj_t list;
} glob_context_t;

static int glob_callback(const char *path, size_t path_len, void *user_data) {
    glob_context_t *ctx = (glob_context_t *)user_data;
    mp_obj_t path_obj = mp_obj_new_str(path, path_len);
    mp_obj_list_append(ctx->list, path_obj);
    return 0;  // Continue
}

extern int glob_glob(const char *dir_path, size_t dir_path_len,
                     const char *pattern, size_t pattern_len,
                     int (*callback)(const char *, size_t, void *),
                     void *user_data);

extern int glob_rglob(const char *dir_path, size_t dir_path_len,
                      const char *pattern, size_t pattern_len,
                      int (*callback)(const char *, size_t, void *),
                      void *user_data);

// ============================================================================
// fnmatch functions
// ============================================================================

// fnmatch.fnmatch(name, pattern) -> bool
MPY_FUNC_2(fnmatch, fnmatch) {
    size_t name_len, pattern_len;
    const char *name = mpy_str_len(arg0, &name_len);
    const char *pattern = mpy_str_len(arg1, &pattern_len);
    
    int result = glob_fnmatch(pattern, pattern_len, name, name_len);
    return mpy_bool(result == 1);
}
MPY_FUNC_OBJ_2(fnmatch, fnmatch);

// fnmatch.filter(names, pattern) -> list of matching names
MPY_FUNC_2(fnmatch, filter) {
    // Get the list of names
    size_t len;
    mp_obj_t *items;
    mp_obj_get_array(arg0, &len, &items);
    
    size_t pattern_len;
    const char *pattern = mpy_str_len(arg1, &pattern_len);
    
    // Create result list
    mp_obj_t result = mp_obj_new_list(0, NULL);
    
    for (size_t i = 0; i < len; i++) {
        size_t name_len;
        const char *name = mpy_str_len(items[i], &name_len);
        
        if (glob_fnmatch(pattern, pattern_len, name, name_len) == 1) {
            mp_obj_list_append(result, items[i]);
        }
    }
    
    return result;
}
MPY_FUNC_OBJ_2(fnmatch, filter);

// ============================================================================
// glob functions
// ============================================================================

// glob.glob(pattern, root_dir=".") -> list of paths
MPY_FUNC_VAR(glob, glob, 1, 2) {
    size_t pattern_len;
    const char *pattern = mpy_str_len(args[0], &pattern_len);
    
    // Default to current directory
    const char *root_dir = ".";
    size_t root_len = 1;
    
    if (n_args >= 2 && args[1] != mp_const_none) {
        root_dir = mpy_str_len(args[1], &root_len);
    }
    
    // Create result list and context
    glob_context_t ctx;
    ctx.list = mp_obj_new_list(0, NULL);
    
    glob_glob(root_dir, root_len, pattern, pattern_len, glob_callback, &ctx);
    
    return ctx.list;
}
MPY_FUNC_OBJ_VAR(glob, glob, 1, 2);

// glob.iglob(pattern, root_dir=".") -> iterator
// For simplicity, this just returns the same as glob()
MPY_FUNC_VAR(glob, iglob, 1, 2) {
    return mod_glob_glob(n_args, args);
}
MPY_FUNC_OBJ_VAR(glob, iglob, 1, 2);

// glob.rglob(pattern, root_dir=".") -> list of paths (recursive)
MPY_FUNC_VAR(glob, rglob, 1, 2) {
    size_t pattern_len;
    const char *pattern = mpy_str_len(args[0], &pattern_len);
    
    // Default to current directory
    const char *root_dir = ".";
    size_t root_len = 1;
    
    if (n_args >= 2 && args[1] != mp_const_none) {
        root_dir = mpy_str_len(args[1], &root_len);
    }
    
    // Create result list and context
    glob_context_t ctx;
    ctx.list = mp_obj_new_list(0, NULL);
    
    glob_rglob(root_dir, root_len, pattern, pattern_len, glob_callback, &ctx);
    
    return ctx.list;
}
MPY_FUNC_OBJ_VAR(glob, rglob, 1, 2);

// ============================================================================
// Module Definitions
// ============================================================================

// fnmatch module
MPY_MODULE_BEGIN(fnmatch)
    MPY_MODULE_FUNC(fnmatch, fnmatch)
    MPY_MODULE_FUNC(fnmatch, filter)
MPY_MODULE_END(fnmatch)

// glob module  
MPY_MODULE_BEGIN(glob)
    MPY_MODULE_FUNC(glob, glob)
    MPY_MODULE_FUNC(glob, iglob)
    MPY_MODULE_FUNC(glob, rglob)
MPY_MODULE_END(glob)
