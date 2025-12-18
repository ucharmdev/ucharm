/*
 * modpathlib.c - Native pathlib module for MicroPython
 *
 * Provides Path class with CPython-compatible interface:
 *   - Path construction and / operator
 *   - Properties: name, parent, suffix, stem, parts
 *   - Methods: is_absolute, joinpath, with_name, with_suffix
 *   - Filesystem: exists, is_file, is_dir, cwd, resolve, stat
 *   - I/O: read_text, read_bytes, write_text, write_bytes
 */

#include "py/runtime.h"
#include "py/objstr.h"
#include "py/stream.h"
#include "py/builtin.h"
#include "py/objlist.h"
#include <string.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>

// External Zig functions
extern int path_basename(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_dirname(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_extname(const char *path, size_t path_len, char *output, size_t output_len);
extern int zig_path_stem(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_is_absolute(const char *path, size_t path_len);
extern int path_join(const char *path1, size_t path1_len, const char *path2, size_t path2_len,
                     char *output, size_t output_len);
extern int path_normalize(const char *path, size_t path_len, char *output, size_t output_len);
extern int path_exists(const char *path, size_t path_len);
extern int path_is_file(const char *path, size_t path_len);
extern int path_is_dir(const char *path, size_t path_len);
extern int path_getcwd(char *output, size_t output_len);

// ============================================================================
// Path type definition
// ============================================================================

typedef struct _mp_obj_path_t {
    mp_obj_base_t base;
    mp_obj_t path_str;  // Store the path as a string object
} mp_obj_path_t;

const mp_obj_type_t mp_type_Path;
const mp_obj_type_t mp_type_PurePath;
const mp_obj_type_t mp_type_PurePosixPath;
const mp_obj_type_t mp_type_PosixPath;

// Helper to get path string from Path object
static const char *get_path_str(mp_obj_t self_in, size_t *len) {
    mp_obj_path_t *self = MP_OBJ_TO_PTR(self_in);
    return mp_obj_str_get_data(self->path_str, len);
}

// Helper to create a new Path object
static mp_obj_t path_new_from_str(const mp_obj_type_t *type, const char *str, size_t len) {
    mp_obj_path_t *o = mp_obj_malloc(mp_obj_path_t, type);
    if (len == 0 || (len == 1 && str[0] == '\0')) {
        o->path_str = mp_obj_new_str(".", 1);
    } else {
        o->path_str = mp_obj_new_str(str, len);
    }
    return MP_OBJ_FROM_PTR(o);
}

// ============================================================================
// Path.__new__ / __init__
// ============================================================================

static mp_obj_t path_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 0, MP_OBJ_FUN_ARGS_MAX, false);
    
    if (n_args == 0) {
        return path_new_from_str(type, ".", 1);
    }
    
    if (n_args == 1) {
        // Single argument - could be string or Path
        if (mp_obj_is_type(args[0], &mp_type_Path) || 
            mp_obj_is_type(args[0], &mp_type_PurePath)) {
            mp_obj_path_t *other = MP_OBJ_TO_PTR(args[0]);
            size_t other_len;
            const char *other_str = mp_obj_str_get_data(other->path_str, &other_len);
            return path_new_from_str(type, other_str, other_len);
        }
        size_t len;
        const char *str = mp_obj_str_get_data(args[0], &len);
        if (len == 0) {
            return path_new_from_str(type, ".", 1);
        }
        return path_new_from_str(type, str, len);
    }
    
    // Multiple arguments - join them
    char buf[4096];
    size_t buf_pos = 0;
    
    for (size_t i = 0; i < n_args; i++) {
        size_t part_len;
        const char *part;
        
        if (mp_obj_is_type(args[i], &mp_type_Path) || 
            mp_obj_is_type(args[i], &mp_type_PurePath)) {
            mp_obj_path_t *p = MP_OBJ_TO_PTR(args[i]);
            part = mp_obj_str_get_data(p->path_str, &part_len);
        } else {
            part = mp_obj_str_get_data(args[i], &part_len);
        }
        
        if (part_len == 0) continue;
        
        if (buf_pos > 0 && buf[buf_pos-1] != '/') {
            buf[buf_pos++] = '/';
        }
        
        if (buf_pos + part_len >= sizeof(buf)) {
            mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
        }
        
        memcpy(buf + buf_pos, part, part_len);
        buf_pos += part_len;
    }
    
    if (buf_pos == 0) {
        return path_new_from_str(type, ".", 1);
    }
    
    return path_new_from_str(type, buf, buf_pos);
}

// ============================================================================
// Path.__str__, __repr__, __hash__, __eq__
// ============================================================================

static void path_print(const mp_print_t *print, mp_obj_t self_in, mp_print_kind_t kind) {
    mp_obj_path_t *self = MP_OBJ_TO_PTR(self_in);
    if (kind == PRINT_STR) {
        mp_print_str(print, mp_obj_str_get_str(self->path_str));
    } else {
        mp_printf(print, "Path('%s')", mp_obj_str_get_str(self->path_str));
    }
}

static mp_obj_t path_unary_op(mp_unary_op_t op, mp_obj_t self_in) {
    mp_obj_path_t *self = MP_OBJ_TO_PTR(self_in);
    switch (op) {
        case MP_UNARY_OP_HASH:
            return mp_unary_op(MP_UNARY_OP_HASH, self->path_str);
        default:
            return MP_OBJ_NULL;
    }
}

static mp_obj_t path_binary_op(mp_binary_op_t op, mp_obj_t lhs_in, mp_obj_t rhs_in) {
    mp_obj_path_t *lhs = MP_OBJ_TO_PTR(lhs_in);
    
    if (op == MP_BINARY_OP_EQUAL) {
        if (mp_obj_is_type(rhs_in, &mp_type_Path) || 
            mp_obj_is_type(rhs_in, &mp_type_PurePath)) {
            mp_obj_path_t *rhs = MP_OBJ_TO_PTR(rhs_in);
            return mp_obj_new_bool(mp_obj_equal(lhs->path_str, rhs->path_str));
        }
        if (mp_obj_is_str(rhs_in)) {
            return mp_obj_new_bool(mp_obj_equal(lhs->path_str, rhs_in));
        }
        return mp_const_false;
    }
    
    if (op == MP_BINARY_OP_TRUE_DIVIDE) {
        // Path / "other"
        size_t lhs_len, rhs_len;
        const char *lhs_str = mp_obj_str_get_data(lhs->path_str, &lhs_len);
        const char *rhs_str;
        
        if (mp_obj_is_type(rhs_in, &mp_type_Path) || 
            mp_obj_is_type(rhs_in, &mp_type_PurePath)) {
            mp_obj_path_t *rhs = MP_OBJ_TO_PTR(rhs_in);
            rhs_str = mp_obj_str_get_data(rhs->path_str, &rhs_len);
        } else {
            rhs_str = mp_obj_str_get_data(rhs_in, &rhs_len);
        }
        
        // If rhs is absolute, return it
        if (rhs_len > 0 && rhs_str[0] == '/') {
            return path_new_from_str(lhs->base.type, rhs_str, rhs_len);
        }
        
        char buf[4096];
        int len = path_join(lhs_str, lhs_len, rhs_str, rhs_len, buf, sizeof(buf));
        if (len < 0) {
            mp_raise_ValueError(MP_ERROR_TEXT("path join failed"));
        }
        return path_new_from_str(lhs->base.type, buf, len);
    }
    
    return MP_OBJ_NULL;
}

// ============================================================================
// Path properties
// ============================================================================

// Path.name - property implementation
static mp_obj_t path_name(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    char buf[4096];
    int len = path_basename(path, path_len, buf, sizeof(buf));
    if (len < 0) return mp_obj_new_str("", 0);
    return mp_obj_new_str(buf, len);
}

// Path.parent - property implementation
static mp_obj_t path_parent(mp_obj_t self_in) {
    mp_obj_path_t *self = MP_OBJ_TO_PTR(self_in);
    size_t path_len;
    const char *path = mp_obj_str_get_data(self->path_str, &path_len);
    char buf[4096];
    int len = path_dirname(path, path_len, buf, sizeof(buf));
    if (len < 0 || len == 0) {
        return path_new_from_str(self->base.type, ".", 1);
    }
    return path_new_from_str(self->base.type, buf, len);
}

// Path.suffix - property implementation
static mp_obj_t path_suffix(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    char buf[256];
    int len = path_extname(path, path_len, buf, sizeof(buf));
    if (len < 0) return mp_obj_new_str("", 0);
    return mp_obj_new_str(buf, len);
}

// Path.stem - property implementation
static mp_obj_t path_stem_method(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    char buf[4096];
    int len = zig_path_stem(path, path_len, buf, sizeof(buf));
    if (len < 0) return mp_obj_new_str("", 0);
    return mp_obj_new_str(buf, len);
}

// Path.parts - property implementation
static mp_obj_t path_parts(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    
    if (path_len == 0 || (path_len == 1 && path[0] == '.')) {
        mp_obj_t items[1] = {mp_obj_new_str(".", 1)};
        return mp_obj_new_tuple(1, items);
    }
    
    // Count parts
    mp_obj_t parts[64];
    size_t n_parts = 0;
    
    // Handle absolute path
    if (path[0] == '/') {
        parts[n_parts++] = mp_obj_new_str("/", 1);
    }
    
    // Split by /
    size_t start = (path[0] == '/') ? 1 : 0;
    for (size_t i = start; i <= path_len && n_parts < 64; i++) {
        if (i == path_len || path[i] == '/') {
            if (i > start) {
                parts[n_parts++] = mp_obj_new_str(path + start, i - start);
            }
            start = i + 1;
        }
    }
    
    if (n_parts == 0) {
        parts[n_parts++] = mp_obj_new_str(".", 1);
    }
    
    return mp_obj_new_tuple(n_parts, parts);
}

// ============================================================================
// Path methods
// ============================================================================

// Path.is_absolute()
static mp_obj_t path_is_absolute_method(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    return mp_obj_new_bool(path_is_absolute(path, path_len) == 1);
}
static MP_DEFINE_CONST_FUN_OBJ_1(path_is_absolute_method_obj, path_is_absolute_method);

// Path.joinpath(*args)
static mp_obj_t path_joinpath(size_t n_args, const mp_obj_t *args) {
    mp_obj_path_t *self = MP_OBJ_TO_PTR(args[0]);
    mp_obj_t result = MP_OBJ_FROM_PTR(self);
    
    for (size_t i = 1; i < n_args; i++) {
        result = path_binary_op(MP_BINARY_OP_TRUE_DIVIDE, result, args[i]);
    }
    
    return result;
}
static MP_DEFINE_CONST_FUN_OBJ_VAR(path_joinpath_obj, 1, path_joinpath);

// Path.with_name(name)
static mp_obj_t path_with_name(mp_obj_t self_in, mp_obj_t name_in) {
    mp_obj_t parent = path_parent(self_in);
    return path_binary_op(MP_BINARY_OP_TRUE_DIVIDE, parent, name_in);
}
static MP_DEFINE_CONST_FUN_OBJ_2(path_with_name_obj, path_with_name);

// Path.with_suffix(suffix)
static mp_obj_t path_with_suffix(mp_obj_t self_in, mp_obj_t suffix_in) {
    mp_obj_path_t *self = MP_OBJ_TO_PTR(self_in);
    
    // Get stem and parent
    size_t path_len;
    const char *path = mp_obj_str_get_data(self->path_str, &path_len);
    
    char stem_buf[4096];
    int stem_len = zig_path_stem(path, path_len, stem_buf, sizeof(stem_buf));
    if (stem_len < 0) stem_len = 0;
    
    char dir_buf[4096];
    int dir_len = path_dirname(path, path_len, dir_buf, sizeof(dir_buf));
    
    size_t suffix_len;
    const char *suffix = mp_obj_str_get_data(suffix_in, &suffix_len);
    
    // Build new name: stem + suffix
    char name_buf[4096];
    memcpy(name_buf, stem_buf, stem_len);
    memcpy(name_buf + stem_len, suffix, suffix_len);
    
    // Join with parent
    if (dir_len <= 0) {
        return path_new_from_str(self->base.type, name_buf, stem_len + suffix_len);
    }
    
    char result_buf[8192];
    int result_len = path_join(dir_buf, dir_len, name_buf, stem_len + suffix_len, 
                               result_buf, sizeof(result_buf));
    if (result_len < 0) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    
    return path_new_from_str(self->base.type, result_buf, result_len);
}
static MP_DEFINE_CONST_FUN_OBJ_2(path_with_suffix_obj, path_with_suffix);

// ============================================================================
// Filesystem operations
// ============================================================================

// Path.exists()
static mp_obj_t path_exists_method(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    return mp_obj_new_bool(path_exists(path, path_len) == 1);
}
static MP_DEFINE_CONST_FUN_OBJ_1(path_exists_method_obj, path_exists_method);

// Path.is_file()
static mp_obj_t path_is_file_method(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    return mp_obj_new_bool(path_is_file(path, path_len) == 1);
}
static MP_DEFINE_CONST_FUN_OBJ_1(path_is_file_method_obj, path_is_file_method);

// Path.is_dir()
static mp_obj_t path_is_dir_method(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    return mp_obj_new_bool(path_is_dir(path, path_len) == 1);
}
static MP_DEFINE_CONST_FUN_OBJ_1(path_is_dir_method_obj, path_is_dir_method);

// Path.cwd() - classmethod
static mp_obj_t path_cwd(mp_obj_t cls_in) {
    char buf[4096];
    int len = path_getcwd(buf, sizeof(buf));
    if (len < 0) {
        mp_raise_OSError(errno);
    }
    return path_new_from_str(&mp_type_Path, buf, len);
}
static MP_DEFINE_CONST_FUN_OBJ_1(path_cwd_obj, path_cwd);
static MP_DEFINE_CONST_CLASSMETHOD_OBJ(path_cwd_classmethod_obj, MP_ROM_PTR(&path_cwd_obj));

// Path.resolve()
static mp_obj_t path_resolve(size_t n_args, const mp_obj_t *args) {
    mp_obj_path_t *self = MP_OBJ_TO_PTR(args[0]);
    size_t path_len;
    const char *path = mp_obj_str_get_data(self->path_str, &path_len);
    
    char buf[4096];
    
    // If not absolute, prepend cwd
    if (path_len == 0 || path[0] != '/') {
        char cwd_buf[4096];
        int cwd_len = path_getcwd(cwd_buf, sizeof(cwd_buf));
        if (cwd_len < 0) {
            mp_raise_OSError(errno);
        }
        
        char joined_buf[8192];
        int joined_len = path_join(cwd_buf, cwd_len, path, path_len, joined_buf, sizeof(joined_buf));
        if (joined_len < 0) {
            mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
        }
        
        int norm_len = path_normalize(joined_buf, joined_len, buf, sizeof(buf));
        if (norm_len < 0) {
            return path_new_from_str(self->base.type, joined_buf, joined_len);
        }
        return path_new_from_str(self->base.type, buf, norm_len);
    }
    
    int norm_len = path_normalize(path, path_len, buf, sizeof(buf));
    if (norm_len < 0) {
        return MP_OBJ_FROM_PTR(self);
    }
    return path_new_from_str(self->base.type, buf, norm_len);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(path_resolve_obj, 1, 2, path_resolve);

// Path.stat()
static mp_obj_t path_stat_method(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    
    // Null-terminate for stat()
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
    
    // Return a tuple similar to os.stat
    mp_obj_t items[10];
    items[0] = mp_obj_new_int(st.st_mode);
    items[1] = mp_obj_new_int(st.st_ino);
    items[2] = mp_obj_new_int(st.st_dev);
    items[3] = mp_obj_new_int(st.st_nlink);
    items[4] = mp_obj_new_int(st.st_uid);
    items[5] = mp_obj_new_int(st.st_gid);
    items[6] = mp_obj_new_int(st.st_size);
    items[7] = mp_obj_new_int(st.st_atime);
    items[8] = mp_obj_new_int(st.st_mtime);
    items[9] = mp_obj_new_int(st.st_ctime);
    
    return mp_obj_new_tuple(10, items);
}
static MP_DEFINE_CONST_FUN_OBJ_1(path_stat_method_obj, path_stat_method);

// ============================================================================
// I/O operations
// ============================================================================

// Path.read_text()
static mp_obj_t path_read_text(size_t n_args, const mp_obj_t *args) {
    size_t path_len;
    const char *path = get_path_str(args[0], &path_len);
    
    char path_buf[4096];
    if (path_len >= sizeof(path_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(path_buf, path, path_len);
    path_buf[path_len] = '\0';
    
    mp_obj_t file_args[2] = {mp_obj_new_str(path_buf, path_len), MP_OBJ_NEW_QSTR(MP_QSTR_r)};
    mp_obj_t file = mp_builtin_open(2, file_args, (mp_map_t *)&mp_const_empty_map);
    
    // Read all content using stream protocol
    mp_obj_t read_method = mp_load_attr(file, MP_QSTR_read);
    mp_obj_t content = mp_call_function_0(read_method);
    mp_stream_close(file);
    
    return content;
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(path_read_text_obj, 1, 2, path_read_text);

// Path.read_bytes()
static mp_obj_t path_read_bytes(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    
    char path_buf[4096];
    if (path_len >= sizeof(path_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(path_buf, path, path_len);
    path_buf[path_len] = '\0';
    
    mp_obj_t file_args[2] = {mp_obj_new_str(path_buf, path_len), MP_OBJ_NEW_QSTR(MP_QSTR_rb)};
    mp_obj_t file = mp_builtin_open(2, file_args, (mp_map_t *)&mp_const_empty_map);
    
    mp_obj_t read_method = mp_load_attr(file, MP_QSTR_read);
    mp_obj_t content = mp_call_function_0(read_method);
    mp_stream_close(file);
    
    return content;
}
static MP_DEFINE_CONST_FUN_OBJ_1(path_read_bytes_obj, path_read_bytes);

// Path.write_text(data)
static mp_obj_t path_write_text(size_t n_args, const mp_obj_t *args) {
    size_t path_len;
    const char *path = get_path_str(args[0], &path_len);
    
    char path_buf[4096];
    if (path_len >= sizeof(path_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(path_buf, path, path_len);
    path_buf[path_len] = '\0';
    
    mp_obj_t file_args[2] = {mp_obj_new_str(path_buf, path_len), MP_OBJ_NEW_QSTR(MP_QSTR_w)};
    mp_obj_t file = mp_builtin_open(2, file_args, (mp_map_t *)&mp_const_empty_map);
    
    size_t data_len;
    const char *data = mp_obj_str_get_data(args[1], &data_len);
    mp_stream_write(file, data, data_len, MP_STREAM_RW_WRITE);
    mp_stream_close(file);
    
    return mp_obj_new_int(data_len);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(path_write_text_obj, 2, 3, path_write_text);

// Path.write_bytes(data)
static mp_obj_t path_write_bytes(mp_obj_t self_in, mp_obj_t data_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    
    char path_buf[4096];
    if (path_len >= sizeof(path_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(path_buf, path, path_len);
    path_buf[path_len] = '\0';
    
    mp_obj_t file_args[2] = {mp_obj_new_str(path_buf, path_len), MP_OBJ_NEW_QSTR(MP_QSTR_wb)};
    mp_obj_t file = mp_builtin_open(2, file_args, (mp_map_t *)&mp_const_empty_map);
    
    mp_buffer_info_t bufinfo;
    mp_get_buffer_raise(data_in, &bufinfo, MP_BUFFER_READ);
    mp_stream_write(file, bufinfo.buf, bufinfo.len, MP_STREAM_RW_WRITE);
    mp_stream_close(file);
    
    return mp_obj_new_int(bufinfo.len);
}
static MP_DEFINE_CONST_FUN_OBJ_2(path_write_bytes_obj, path_write_bytes);

// Path.mkdir()
static mp_obj_t path_mkdir(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    enum { ARG_mode, ARG_parents, ARG_exist_ok };
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_mode, MP_ARG_INT, {.u_int = 0777} },
        { MP_QSTR_parents, MP_ARG_BOOL, {.u_bool = false} },
        { MP_QSTR_exist_ok, MP_ARG_BOOL, {.u_bool = false} },
    };
    
    mp_arg_val_t args[MP_ARRAY_SIZE(allowed_args)];
    mp_arg_parse_all(n_args - 1, pos_args + 1, kw_args, MP_ARRAY_SIZE(allowed_args), allowed_args, args);
    
    size_t path_len;
    const char *path = get_path_str(pos_args[0], &path_len);
    
    char path_buf[4096];
    if (path_len >= sizeof(path_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(path_buf, path, path_len);
    path_buf[path_len] = '\0';
    
    int ret = mkdir(path_buf, args[ARG_mode].u_int);
    if (ret != 0) {
        if (args[ARG_exist_ok].u_bool && errno == EEXIST) {
            // Check if it's a directory
            struct stat st;
            if (stat(path_buf, &st) == 0 && S_ISDIR(st.st_mode)) {
                return mp_const_none;
            }
        }
        mp_raise_OSError(errno);
    }
    
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_KW(path_mkdir_obj, 1, path_mkdir);

// Path.rmdir()
static mp_obj_t path_rmdir(mp_obj_t self_in) {
    size_t path_len;
    const char *path = get_path_str(self_in, &path_len);
    
    char path_buf[4096];
    if (path_len >= sizeof(path_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(path_buf, path, path_len);
    path_buf[path_len] = '\0';
    
    if (rmdir(path_buf) != 0) {
        mp_raise_OSError(errno);
    }
    
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_1(path_rmdir_obj, path_rmdir);

// Path.unlink()
static mp_obj_t path_unlink(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    enum { ARG_missing_ok };
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_missing_ok, MP_ARG_BOOL, {.u_bool = false} },
    };
    
    mp_arg_val_t args[MP_ARRAY_SIZE(allowed_args)];
    mp_arg_parse_all(n_args - 1, pos_args + 1, kw_args, MP_ARRAY_SIZE(allowed_args), allowed_args, args);
    
    size_t path_len;
    const char *path = get_path_str(pos_args[0], &path_len);
    
    char path_buf[4096];
    if (path_len >= sizeof(path_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(path_buf, path, path_len);
    path_buf[path_len] = '\0';
    
    if (unlink(path_buf) != 0) {
        if (!(args[ARG_missing_ok].u_bool && errno == ENOENT)) {
            mp_raise_OSError(errno);
        }
    }
    
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_KW(path_unlink_obj, 1, path_unlink);

// Path.rename(target)
static mp_obj_t path_rename(mp_obj_t self_in, mp_obj_t target_in) {
    mp_obj_path_t *self = MP_OBJ_TO_PTR(self_in);
    size_t src_len, dst_len;
    const char *src = mp_obj_str_get_data(self->path_str, &src_len);
    const char *dst;
    
    if (mp_obj_is_type(target_in, &mp_type_Path)) {
        mp_obj_path_t *target = MP_OBJ_TO_PTR(target_in);
        dst = mp_obj_str_get_data(target->path_str, &dst_len);
    } else {
        dst = mp_obj_str_get_data(target_in, &dst_len);
    }
    
    char src_buf[4096], dst_buf[4096];
    if (src_len >= sizeof(src_buf) || dst_len >= sizeof(dst_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(src_buf, src, src_len); src_buf[src_len] = '\0';
    memcpy(dst_buf, dst, dst_len); dst_buf[dst_len] = '\0';
    
    if (rename(src_buf, dst_buf) != 0) {
        mp_raise_OSError(errno);
    }
    
    return path_new_from_str(self->base.type, dst, dst_len);
}
static MP_DEFINE_CONST_FUN_OBJ_2(path_rename_obj, path_rename);

// Path.iterdir()
static mp_obj_t path_iterdir(mp_obj_t self_in) {
    mp_obj_path_t *self = MP_OBJ_TO_PTR(self_in);
    size_t path_len;
    const char *path = mp_obj_str_get_data(self->path_str, &path_len);
    
    char path_buf[4096];
    if (path_len >= sizeof(path_buf)) {
        mp_raise_ValueError(MP_ERROR_TEXT("path too long"));
    }
    memcpy(path_buf, path, path_len);
    path_buf[path_len] = '\0';
    
    // Use os.listdir and yield Path objects
    mp_obj_t listdir = mp_call_function_1(
        mp_load_attr(mp_import_name(MP_QSTR_os, mp_const_none, MP_OBJ_NEW_SMALL_INT(0)), MP_QSTR_listdir),
        mp_obj_new_str(path_buf, path_len)
    );
    
    // Convert to list of Path objects
    mp_obj_t iter = mp_getiter(listdir, NULL);
    mp_obj_t item;
    mp_obj_list_t *result = MP_OBJ_TO_PTR(mp_obj_new_list(0, NULL));
    
    while ((item = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        mp_obj_t child = path_binary_op(MP_BINARY_OP_TRUE_DIVIDE, self_in, item);
        mp_obj_list_append(MP_OBJ_FROM_PTR(result), child);
    }
    
    return mp_getiter(MP_OBJ_FROM_PTR(result), NULL);
}
static MP_DEFINE_CONST_FUN_OBJ_1(path_iterdir_obj, path_iterdir);

// ============================================================================
// Path type locals dict (defined before attr function)
// ============================================================================

static const mp_rom_map_elem_t path_locals_dict_table[] = {
    // Methods only - properties handled by attr function
    { MP_ROM_QSTR(MP_QSTR_is_absolute), MP_ROM_PTR(&path_is_absolute_method_obj) },
    { MP_ROM_QSTR(MP_QSTR_joinpath), MP_ROM_PTR(&path_joinpath_obj) },
    { MP_ROM_QSTR(MP_QSTR_with_name), MP_ROM_PTR(&path_with_name_obj) },
    { MP_ROM_QSTR(MP_QSTR_with_suffix), MP_ROM_PTR(&path_with_suffix_obj) },
    
    // Filesystem
    { MP_ROM_QSTR(MP_QSTR_exists), MP_ROM_PTR(&path_exists_method_obj) },
    { MP_ROM_QSTR(MP_QSTR_is_file), MP_ROM_PTR(&path_is_file_method_obj) },
    { MP_ROM_QSTR(MP_QSTR_is_dir), MP_ROM_PTR(&path_is_dir_method_obj) },
    { MP_ROM_QSTR(MP_QSTR_cwd), MP_ROM_PTR(&path_cwd_classmethod_obj) },
    { MP_ROM_QSTR(MP_QSTR_resolve), MP_ROM_PTR(&path_resolve_obj) },
    { MP_ROM_QSTR(MP_QSTR_stat), MP_ROM_PTR(&path_stat_method_obj) },
    
    // I/O
    { MP_ROM_QSTR(MP_QSTR_read_text), MP_ROM_PTR(&path_read_text_obj) },
    { MP_ROM_QSTR(MP_QSTR_read_bytes), MP_ROM_PTR(&path_read_bytes_obj) },
    { MP_ROM_QSTR(MP_QSTR_write_text), MP_ROM_PTR(&path_write_text_obj) },
    { MP_ROM_QSTR(MP_QSTR_write_bytes), MP_ROM_PTR(&path_write_bytes_obj) },
    { MP_ROM_QSTR(MP_QSTR_mkdir), MP_ROM_PTR(&path_mkdir_obj) },
    { MP_ROM_QSTR(MP_QSTR_rmdir), MP_ROM_PTR(&path_rmdir_obj) },
    { MP_ROM_QSTR(MP_QSTR_unlink), MP_ROM_PTR(&path_unlink_obj) },
    { MP_ROM_QSTR(MP_QSTR_rename), MP_ROM_PTR(&path_rename_obj) },
    { MP_ROM_QSTR(MP_QSTR_iterdir), MP_ROM_PTR(&path_iterdir_obj) },
};
static MP_DEFINE_CONST_DICT(path_locals_dict, path_locals_dict_table);

// ============================================================================
// Path attr function (for property-like access)
// ============================================================================

static void path_attr(mp_obj_t self_in, qstr attr, mp_obj_t *dest) {
    if (dest[0] == MP_OBJ_NULL) {
        // Load attribute - check properties first
        if (attr == MP_QSTR_name) {
            dest[0] = path_name(self_in);
            return;
        }
        if (attr == MP_QSTR_parent) {
            dest[0] = path_parent(self_in);
            return;
        }
        if (attr == MP_QSTR_suffix) {
            dest[0] = path_suffix(self_in);
            return;
        }
        if (attr == MP_QSTR_stem) {
            dest[0] = path_stem_method(self_in);
            return;
        }
        if (attr == MP_QSTR_parts) {
            dest[0] = path_parts(self_in);
            return;
        }
        // Fall through to locals dict for methods
        mp_obj_path_t *self = MP_OBJ_TO_PTR(self_in);
        mp_map_elem_t *elem = mp_map_lookup((mp_map_t *)&path_locals_dict.map, MP_OBJ_NEW_QSTR(attr), MP_MAP_LOOKUP);
        if (elem != NULL) {
            mp_convert_member_lookup(self_in, self->base.type, elem->value, dest);
        }
    }
}

// ============================================================================
// Type definitions
// ============================================================================

MP_DEFINE_CONST_OBJ_TYPE(
    mp_type_Path,
    MP_QSTR_Path,
    MP_TYPE_FLAG_NONE,
    make_new, path_make_new,
    print, path_print,
    unary_op, path_unary_op,
    binary_op, path_binary_op,
    attr, path_attr,
    locals_dict, &path_locals_dict
);

MP_DEFINE_CONST_OBJ_TYPE(
    mp_type_PurePath,
    MP_QSTR_PurePath,
    MP_TYPE_FLAG_NONE,
    make_new, path_make_new,
    print, path_print,
    unary_op, path_unary_op,
    binary_op, path_binary_op,
    attr, path_attr,
    locals_dict, &path_locals_dict
);

MP_DEFINE_CONST_OBJ_TYPE(
    mp_type_PurePosixPath,
    MP_QSTR_PurePosixPath,
    MP_TYPE_FLAG_NONE,
    make_new, path_make_new,
    print, path_print,
    unary_op, path_unary_op,
    binary_op, path_binary_op,
    attr, path_attr,
    locals_dict, &path_locals_dict
);

MP_DEFINE_CONST_OBJ_TYPE(
    mp_type_PosixPath,
    MP_QSTR_PosixPath,
    MP_TYPE_FLAG_NONE,
    make_new, path_make_new,
    print, path_print,
    unary_op, path_unary_op,
    binary_op, path_binary_op,
    attr, path_attr,
    locals_dict, &path_locals_dict
);

// ============================================================================
// Module definition
// ============================================================================

static const mp_rom_map_elem_t pathlib_module_globals_table[] = {
    { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR_pathlib) },
    { MP_ROM_QSTR(MP_QSTR_Path), MP_ROM_PTR(&mp_type_Path) },
    { MP_ROM_QSTR(MP_QSTR_PurePath), MP_ROM_PTR(&mp_type_PurePath) },
    { MP_ROM_QSTR(MP_QSTR_PurePosixPath), MP_ROM_PTR(&mp_type_PurePosixPath) },
    { MP_ROM_QSTR(MP_QSTR_PosixPath), MP_ROM_PTR(&mp_type_PosixPath) },
    { MP_ROM_QSTR(MP_QSTR_PureWindowsPath), MP_ROM_PTR(&mp_type_PurePosixPath) },
    { MP_ROM_QSTR(MP_QSTR_WindowsPath), MP_ROM_PTR(&mp_type_PosixPath) },
};
static MP_DEFINE_CONST_DICT(pathlib_module_globals, pathlib_module_globals_table);

const mp_obj_module_t mp_module_pathlib = {
    .base = { &mp_type_module },
    .globals = (mp_obj_dict_t *)&pathlib_module_globals,
};

MP_REGISTER_MODULE(MP_QSTR_pathlib, mp_module_pathlib);
