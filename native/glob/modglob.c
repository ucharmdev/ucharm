/*
 * modglob - Native glob module for ucharm
 * 
 * This module bridges Zig's glob implementation to MicroPython.
 * 
 * Usage in Python:
 *   import glob
 *   files = glob.glob("*.py")
 * 
 * Note: fnmatch is now a separate module in native/fnmatch/
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// External Zig functions
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
// glob functions
// ============================================================================

// Helper to find the last path separator
static int find_last_sep(const char *path, size_t len) {
    for (int i = (int)len - 1; i >= 0; i--) {
        if (path[i] == '/') {
            return i;
        }
    }
    return -1;
}

// Helper to find position of ** in path
static int find_double_star(const char *path, size_t len) {
    for (size_t i = 0; i + 1 < len; i++) {
        if (path[i] == '*' && path[i+1] == '*') {
            return (int)i;
        }
    }
    return -1;
}

// glob.glob(pathname, root_dir=None, dir_fd=None, recursive=False) -> list of paths
// We support pathname, root_dir, and recursive
MPY_FUNC_VAR(glob, glob, 1, 4) {
    size_t pathname_len;
    const char *pathname = mpy_str_len(args[0], &pathname_len);
    
    // Check for recursive flag (arg[3] if provided, or check for ** in pattern)
    bool recursive = false;
    if (n_args >= 4 && mp_obj_is_true(args[3])) {
        recursive = true;
    }
    
    // Check for ** in pattern
    int dstar_pos = find_double_star(pathname, pathname_len);
    if (dstar_pos >= 0) {
        recursive = true;
    }
    
    const char *root_dir;
    size_t root_len;
    const char *pattern;
    size_t pattern_len;
    
    if (recursive && dstar_pos >= 0) {
        // For recursive patterns like "/tmp/test/**/*.py":
        // - root_dir = "/tmp/test" (everything before **)
        // - pattern = "*.py" (everything after **/)
        
        // Find separator before **
        int sep_before_star = -1;
        for (int i = dstar_pos - 1; i >= 0; i--) {
            if (pathname[i] == '/') {
                sep_before_star = i;
                break;
            }
        }
        
        if (sep_before_star >= 0) {
            root_dir = pathname;
            root_len = sep_before_star;
            if (root_len == 0) {
                root_dir = "/";
                root_len = 1;
            }
        } else {
            root_dir = ".";
            root_len = 1;
        }
        
        // Pattern is after **/
        // Find the / after **
        int sep_after_star = -1;
        for (size_t i = dstar_pos + 2; i < pathname_len; i++) {
            if (pathname[i] == '/') {
                sep_after_star = (int)i;
                break;
            }
        }
        
        if (sep_after_star >= 0) {
            pattern = pathname + sep_after_star + 1;
            pattern_len = pathname_len - sep_after_star - 1;
        } else {
            // ** at end - match everything
            pattern = "*";
            pattern_len = 1;
        }
    } else {
        // Non-recursive: split at last separator
        // e.g., "/tmp/test/*.py" -> dir="/tmp/test", pattern="*.py"
        int sep_pos = find_last_sep(pathname, pathname_len);
        
        if (sep_pos >= 0) {
            root_dir = pathname;
            root_len = sep_pos;
            if (root_len == 0) {
                root_dir = "/";
                root_len = 1;
            }
            pattern = pathname + sep_pos + 1;
            pattern_len = pathname_len - sep_pos - 1;
        } else {
            root_dir = ".";
            root_len = 1;
            pattern = pathname;
            pattern_len = pathname_len;
        }
    }
    
    // Check for root_dir kwarg override (arg[1] if provided)
    if (n_args >= 2 && args[1] != mp_const_none) {
        root_dir = mpy_str_len(args[1], &root_len);
    }
    
    // Create result list and context
    glob_context_t ctx;
    ctx.list = mp_obj_new_list(0, NULL);
    
    if (recursive) {
        glob_rglob(root_dir, root_len, pattern, pattern_len, glob_callback, &ctx);
    } else {
        glob_glob(root_dir, root_len, pattern, pattern_len, glob_callback, &ctx);
    }
    
    return ctx.list;
}
MPY_FUNC_OBJ_VAR(glob, glob, 1, 4);

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

// glob module (fnmatch is now a separate module in native/fnmatch/)
MPY_MODULE_BEGIN(glob)
    MPY_MODULE_FUNC(glob, glob)
    MPY_MODULE_FUNC(glob, iglob)
    MPY_MODULE_FUNC(glob, rglob)
MPY_MODULE_END(glob)
