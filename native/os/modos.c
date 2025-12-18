/*
 * modos.c - Extend MicroPython's os module with missing CPython features
 *
 * Uses MP_REGISTER_MODULE_DELEGATION to add attributes to the built-in os module:
 *   - os.environ: dict-like access to environment variables
 *   - os.path: submodule with path manipulation functions
 *   - os.name: "posix" on Unix, "nt" on Windows
 *   - os.linesep: line separator ("\n" on Unix)
 */

#include "py/runtime.h"
#include "py/obj.h"
#include "py/objstr.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

// External environ from libc
extern char **environ;

// ============================================================================
// os.environ - Environment variable dict-like object
// ============================================================================

typedef struct _mp_obj_environ_t {
    mp_obj_base_t base;
} mp_obj_environ_t;

static mp_obj_t environ_subscr(mp_obj_t self_in, mp_obj_t index, mp_obj_t value) {
    (void)self_in;
    
    if (value == MP_OBJ_SENTINEL) {
        // Load: environ[key]
        size_t key_len;
        const char *key = mp_obj_str_get_data(index, &key_len);
        
        // Null-terminate key
        char key_buf[256];
        if (key_len >= sizeof(key_buf)) {
            mp_raise_ValueError(MP_ERROR_TEXT("key too long"));
        }
        memcpy(key_buf, key, key_len);
        key_buf[key_len] = '\0';
        
        const char *val = getenv(key_buf);
        if (val == NULL) {
            mp_raise_type_arg(&mp_type_KeyError, index);
        }
        return mp_obj_new_str(val, strlen(val));
    } else if (value == MP_OBJ_NULL) {
        // Delete: del environ[key]
        size_t key_len;
        const char *key = mp_obj_str_get_data(index, &key_len);
        
        char key_buf[256];
        if (key_len >= sizeof(key_buf)) {
            mp_raise_ValueError(MP_ERROR_TEXT("key too long"));
        }
        memcpy(key_buf, key, key_len);
        key_buf[key_len] = '\0';
        
        if (getenv(key_buf) == NULL) {
            mp_raise_type_arg(&mp_type_KeyError, index);
        }
        unsetenv(key_buf);
        return mp_const_none;
    } else {
        // Store: environ[key] = value
        size_t key_len, val_len;
        const char *key = mp_obj_str_get_data(index, &key_len);
        const char *val = mp_obj_str_get_data(value, &val_len);
        
        char key_buf[256], val_buf[4096];
        if (key_len >= sizeof(key_buf) || val_len >= sizeof(val_buf)) {
            mp_raise_ValueError(MP_ERROR_TEXT("key or value too long"));
        }
        memcpy(key_buf, key, key_len);
        key_buf[key_len] = '\0';
        memcpy(val_buf, val, val_len);
        val_buf[val_len] = '\0';
        
        setenv(key_buf, val_buf, 1);
        return mp_const_none;
    }
}

static mp_obj_t environ_contains(mp_obj_t self_in, mp_obj_t key_in) {
    (void)self_in;
    size_t key_len;
    const char *key = mp_obj_str_get_data(key_in, &key_len);
    
    char key_buf[256];
    if (key_len >= sizeof(key_buf)) {
        return mp_const_false;
    }
    memcpy(key_buf, key, key_len);
    key_buf[key_len] = '\0';
    
    return mp_obj_new_bool(getenv(key_buf) != NULL);
}

static mp_obj_t environ_binary_op(mp_binary_op_t op, mp_obj_t lhs_in, mp_obj_t rhs_in) {
    if (op == MP_BINARY_OP_CONTAINS) {
        return environ_contains(lhs_in, rhs_in);
    }
    return MP_OBJ_NULL;
}

static mp_obj_t environ_get(size_t n_args, const mp_obj_t *args) {
    size_t key_len;
    const char *key = mp_obj_str_get_data(args[1], &key_len);
    
    char key_buf[256];
    if (key_len >= sizeof(key_buf)) {
        return n_args > 2 ? args[2] : mp_const_none;
    }
    memcpy(key_buf, key, key_len);
    key_buf[key_len] = '\0';
    
    const char *val = getenv(key_buf);
    if (val == NULL) {
        return n_args > 2 ? args[2] : mp_const_none;
    }
    return mp_obj_new_str(val, strlen(val));
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(environ_get_obj, 2, 3, environ_get);

static mp_obj_t environ_keys(mp_obj_t self_in) {
    (void)self_in;
    mp_obj_list_t *list = MP_OBJ_TO_PTR(mp_obj_new_list(0, NULL));
    
    for (char **env = environ; *env != NULL; env++) {
        char *eq = strchr(*env, '=');
        if (eq != NULL) {
            mp_obj_list_append(MP_OBJ_FROM_PTR(list), mp_obj_new_str(*env, eq - *env));
        }
    }
    return MP_OBJ_FROM_PTR(list);
}
static MP_DEFINE_CONST_FUN_OBJ_1(environ_keys_obj, environ_keys);

static mp_obj_t environ_values(mp_obj_t self_in) {
    (void)self_in;
    mp_obj_list_t *list = MP_OBJ_TO_PTR(mp_obj_new_list(0, NULL));
    
    for (char **env = environ; *env != NULL; env++) {
        char *eq = strchr(*env, '=');
        if (eq != NULL) {
            mp_obj_list_append(MP_OBJ_FROM_PTR(list), mp_obj_new_str(eq + 1, strlen(eq + 1)));
        }
    }
    return MP_OBJ_FROM_PTR(list);
}
static MP_DEFINE_CONST_FUN_OBJ_1(environ_values_obj, environ_values);

static mp_obj_t environ_items(mp_obj_t self_in) {
    (void)self_in;
    mp_obj_list_t *list = MP_OBJ_TO_PTR(mp_obj_new_list(0, NULL));
    
    for (char **env = environ; *env != NULL; env++) {
        char *eq = strchr(*env, '=');
        if (eq != NULL) {
            mp_obj_t tuple[2] = {
                mp_obj_new_str(*env, eq - *env),
                mp_obj_new_str(eq + 1, strlen(eq + 1))
            };
            mp_obj_list_append(MP_OBJ_FROM_PTR(list), mp_obj_new_tuple(2, tuple));
        }
    }
    return MP_OBJ_FROM_PTR(list);
}
static MP_DEFINE_CONST_FUN_OBJ_1(environ_items_obj, environ_items);

// __getitem__ method for hasattr() compatibility
static mp_obj_t environ_getitem(mp_obj_t self_in, mp_obj_t key_in) {
    return environ_subscr(self_in, key_in, MP_OBJ_SENTINEL);
}
static MP_DEFINE_CONST_FUN_OBJ_2(environ_getitem_obj, environ_getitem);

// __setitem__ method
static mp_obj_t environ_setitem(mp_obj_t self_in, mp_obj_t key_in, mp_obj_t value_in) {
    return environ_subscr(self_in, key_in, value_in);
}
static MP_DEFINE_CONST_FUN_OBJ_3(environ_setitem_obj, environ_setitem);

// __delitem__ method
static mp_obj_t environ_delitem(mp_obj_t self_in, mp_obj_t key_in) {
    return environ_subscr(self_in, key_in, MP_OBJ_NULL);
}
static MP_DEFINE_CONST_FUN_OBJ_2(environ_delitem_obj, environ_delitem);

// __contains__ method  
static mp_obj_t environ_contains_method(mp_obj_t self_in, mp_obj_t key_in) {
    return environ_contains(self_in, key_in);
}
static MP_DEFINE_CONST_FUN_OBJ_2(environ_contains_method_obj, environ_contains_method);

static const mp_rom_map_elem_t environ_locals_dict_table[] = {
    { MP_ROM_QSTR(MP_QSTR_get), MP_ROM_PTR(&environ_get_obj) },
    { MP_ROM_QSTR(MP_QSTR_keys), MP_ROM_PTR(&environ_keys_obj) },
    { MP_ROM_QSTR(MP_QSTR_values), MP_ROM_PTR(&environ_values_obj) },
    { MP_ROM_QSTR(MP_QSTR_items), MP_ROM_PTR(&environ_items_obj) },
    { MP_ROM_QSTR(MP_QSTR___getitem__), MP_ROM_PTR(&environ_getitem_obj) },
    { MP_ROM_QSTR(MP_QSTR___setitem__), MP_ROM_PTR(&environ_setitem_obj) },
    { MP_ROM_QSTR(MP_QSTR___delitem__), MP_ROM_PTR(&environ_delitem_obj) },
    { MP_ROM_QSTR(MP_QSTR___contains__), MP_ROM_PTR(&environ_contains_method_obj) },
};
static MP_DEFINE_CONST_DICT(environ_locals_dict, environ_locals_dict_table);

MP_DEFINE_CONST_OBJ_TYPE(
    mp_type_environ,
    MP_QSTR_environ,
    MP_TYPE_FLAG_NONE,
    subscr, environ_subscr,
    binary_op, environ_binary_op,
    locals_dict, &environ_locals_dict
);

static const mp_obj_environ_t environ_obj = {{&mp_type_environ}};

// ============================================================================
// os.path submodule
// ============================================================================

// Import Zig path functions
extern int path_basename(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_dirname(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_join(const char *path1, size_t path1_len, const char *path2, size_t path2_len,
                     char *output, size_t output_len);
extern int path_normalize(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_is_absolute(const char *path, size_t path_len);
extern int path_exists(const char *path, size_t path_len);
extern int path_is_file(const char *path, size_t path_len);
extern int path_is_dir(const char *path, size_t path_len);
extern int path_getcwd(char *output, size_t output_len);
extern int path_extname(const char *path, size_t path_len, char *output, size_t output_len);

// os.path.exists(path)
static mp_obj_t ospath_exists(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    return mp_obj_new_bool(path_exists(path, path_len) == 1);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_exists_obj, ospath_exists);

// os.path.isfile(path)
static mp_obj_t ospath_isfile(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    return mp_obj_new_bool(path_is_file(path, path_len) == 1);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_isfile_obj, ospath_isfile);

// os.path.isdir(path)
static mp_obj_t ospath_isdir(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    return mp_obj_new_bool(path_is_dir(path, path_len) == 1);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_isdir_obj, ospath_isdir);

// os.path.isabs(path)
static mp_obj_t ospath_isabs(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    return mp_obj_new_bool(path_is_absolute(path, path_len) == 1);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_isabs_obj, ospath_isabs);

// os.path.join(path, *paths)
static mp_obj_t ospath_join(size_t n_args, const mp_obj_t *args) {
    if (n_args == 0) {
        return mp_obj_new_str("", 0);
    }
    
    char buf[4096];
    size_t buf_len;
    const char *first = mp_obj_str_get_data(args[0], &buf_len);
    
    if (buf_len >= sizeof(buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(buf, first, buf_len);
    
    for (size_t i = 1; i < n_args; i++) {
        size_t part_len;
        const char *part = mp_obj_str_get_data(args[i], &part_len);
        
        char result[4096];
        int len = path_join(buf, buf_len, part, part_len, result, sizeof(result));
        if (len < 0) {
            mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
        }
        memcpy(buf, result, len);
        buf_len = len;
    }
    
    return mp_obj_new_str(buf, buf_len);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR(ospath_join_obj, 1, ospath_join);

// os.path.basename(path)
static mp_obj_t ospath_basename(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    
    // CPython behavior: basename of path with trailing slash is empty
    // Don't strip trailing slash like we do for pathlib.Path.name
    
    // Find last separator
    size_t last_sep = path_len;
    for (size_t i = 0; i < path_len; i++) {
        if (path[i] == '/') {
            last_sep = i;
        }
    }
    
    if (last_sep == path_len) {
        // No separator, return whole path
        return path_in;
    }
    
    return mp_obj_new_str(path + last_sep + 1, path_len - last_sep - 1);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_basename_obj, ospath_basename);

// os.path.dirname(path)
static mp_obj_t ospath_dirname(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    
    char buf[4096];
    int len = path_dirname(path, path_len, buf, sizeof(buf));
    if (len < 0) {
        return mp_obj_new_str("", 0);
    }
    // CPython returns "" for paths without directory, not "."
    if (len == 1 && buf[0] == '.') {
        return mp_obj_new_str("", 0);
    }
    return mp_obj_new_str(buf, len);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_dirname_obj, ospath_dirname);

// os.path.split(path) -> (head, tail)
static mp_obj_t ospath_split(mp_obj_t path_in) {
    mp_obj_t head = ospath_dirname(path_in);
    mp_obj_t tail = ospath_basename(path_in);
    mp_obj_t tuple[2] = {head, tail};
    return mp_obj_new_tuple(2, tuple);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_split_obj, ospath_split);

// os.path.splitext(path) -> (root, ext)
static mp_obj_t ospath_splitext(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    
    // Find last dot in basename
    size_t last_sep = 0;
    size_t last_dot = path_len;
    
    for (size_t i = 0; i < path_len; i++) {
        if (path[i] == '/') {
            last_sep = i + 1;
            last_dot = path_len; // Reset dot search after separator
        } else if (path[i] == '.') {
            last_dot = i;
        }
    }
    
    // No dot found, or dot is at start of basename (hidden file)
    if (last_dot == path_len || last_dot == last_sep) {
        mp_obj_t tuple[2] = {path_in, mp_obj_new_str("", 0)};
        return mp_obj_new_tuple(2, tuple);
    }
    
    mp_obj_t tuple[2] = {
        mp_obj_new_str(path, last_dot),
        mp_obj_new_str(path + last_dot, path_len - last_dot)
    };
    return mp_obj_new_tuple(2, tuple);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_splitext_obj, ospath_splitext);

// os.path.abspath(path)
static mp_obj_t ospath_abspath(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    
    // If already absolute, normalize and return
    if (path_len > 0 && path[0] == '/') {
        char buf[4096];
        int len = path_normalize(path, path_len, buf, sizeof(buf));
        if (len < 0) {
            return path_in;
        }
        return mp_obj_new_str(buf, len);
    }
    
    // Get cwd and join
    char cwd[4096];
    int cwd_len = path_getcwd(cwd, sizeof(cwd));
    if (cwd_len < 0) {
        mp_raise_OSError(errno);
    }
    
    char joined[8192];
    int joined_len = path_join(cwd, cwd_len, path, path_len, joined, sizeof(joined));
    if (joined_len < 0) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    
    char result[4096];
    int result_len = path_normalize(joined, joined_len, result, sizeof(result));
    if (result_len < 0) {
        return mp_obj_new_str(joined, joined_len);
    }
    
    return mp_obj_new_str(result, result_len);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_abspath_obj, ospath_abspath);

// os.path.normpath(path)
static mp_obj_t ospath_normpath(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    
    char buf[4096];
    int len = path_normalize(path, path_len, buf, sizeof(buf));
    if (len < 0) {
        return path_in;
    }
    return mp_obj_new_str(buf, len);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_normpath_obj, ospath_normpath);

// os.path.getsize(path)
static mp_obj_t ospath_getsize(mp_obj_t path_in) {
    size_t path_len;
    const char *path = mp_obj_str_get_data(path_in, &path_len);
    
    char path_buf[4096];
    if (path_len >= sizeof(path_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(path_buf, path, path_len);
    path_buf[path_len] = '\0';
    
    struct stat st;
    if (stat(path_buf, &st) != 0) {
        mp_raise_OSError(errno);
    }
    
    return mp_obj_new_int_from_ll(st.st_size);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ospath_getsize_obj, ospath_getsize);

// os.path submodule definition
static const mp_rom_map_elem_t ospath_module_globals_table[] = {
    { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR_path) },
    { MP_ROM_QSTR(MP_QSTR_exists), MP_ROM_PTR(&ospath_exists_obj) },
    { MP_ROM_QSTR(MP_QSTR_isfile), MP_ROM_PTR(&ospath_isfile_obj) },
    { MP_ROM_QSTR(MP_QSTR_isdir), MP_ROM_PTR(&ospath_isdir_obj) },
    { MP_ROM_QSTR(MP_QSTR_isabs), MP_ROM_PTR(&ospath_isabs_obj) },
    { MP_ROM_QSTR(MP_QSTR_join), MP_ROM_PTR(&ospath_join_obj) },
    { MP_ROM_QSTR(MP_QSTR_basename), MP_ROM_PTR(&ospath_basename_obj) },
    { MP_ROM_QSTR(MP_QSTR_dirname), MP_ROM_PTR(&ospath_dirname_obj) },
    { MP_ROM_QSTR(MP_QSTR_split), MP_ROM_PTR(&ospath_split_obj) },
    { MP_ROM_QSTR(MP_QSTR_splitext), MP_ROM_PTR(&ospath_splitext_obj) },
    { MP_ROM_QSTR(MP_QSTR_abspath), MP_ROM_PTR(&ospath_abspath_obj) },
    { MP_ROM_QSTR(MP_QSTR_normpath), MP_ROM_PTR(&ospath_normpath_obj) },
    { MP_ROM_QSTR(MP_QSTR_getsize), MP_ROM_PTR(&ospath_getsize_obj) },
    { MP_ROM_QSTR(MP_QSTR_sep), MP_ROM_QSTR(MP_QSTR__slash_) },
};
static MP_DEFINE_CONST_DICT(ospath_module_globals, ospath_module_globals_table);

const mp_obj_module_t mp_module_ospath = {
    .base = { &mp_type_module },
    .globals = (mp_obj_dict_t *)&ospath_module_globals,
};

// ============================================================================
// os module delegation - add missing attributes to built-in os
// ============================================================================

// Delegation handler for os module attribute lookup
void os_ext_attr(mp_obj_t self_in, qstr attr, mp_obj_t *dest) {
    (void)self_in;
    
    if (attr == MP_QSTR_environ) {
        dest[0] = MP_OBJ_FROM_PTR(&environ_obj);
    } else if (attr == MP_QSTR_path) {
        dest[0] = MP_OBJ_FROM_PTR(&mp_module_ospath);
    } else if (attr == MP_QSTR_name) {
        #ifdef _WIN32
        dest[0] = MP_OBJ_NEW_QSTR(MP_QSTR_nt);
        #else
        dest[0] = MP_OBJ_NEW_QSTR(MP_QSTR_posix);
        #endif
    } else if (attr == MP_QSTR_linesep) {
        #ifdef _WIN32
        dest[0] = mp_obj_new_str("\r\n", 2);
        #else
        dest[0] = mp_obj_new_str("\n", 1);
        #endif
    }
}

// Declare external reference to mp_module_os  
extern const mp_obj_module_t mp_module_os;

// Register as delegate/extension to the os module
MP_REGISTER_MODULE_DELEGATION(mp_module_os, os_ext_attr);
