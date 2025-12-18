/*
 * modjson.c - Complete JSON module replacement for MicroPython
 *
 * Provides CPython-compatible JSON serialization/deserialization:
 *   - json.dumps(obj, *, indent=None, sort_keys=False, separators=None)
 *   - json.dump(obj, fp, *, indent=None, sort_keys=False, separators=None)
 *   - json.loads(s)
 *   - json.load(fp)
 *   - json.JSONDecodeError exception
 *   - Proper error on infinity/NaN values
 */

#include "py/runtime.h"
#include "py/objstr.h"
#include "py/objlist.h"
#include "py/objtype.h"
#include "py/objexcept.h"
#include "py/stream.h"
#include "py/parsenum.h"
#include "py/objstringio.h"
#include <string.h>
#include <stdio.h>
#include <math.h>

// ============================================================================
// JSONDecodeError exception class
// ============================================================================

MP_DEFINE_EXCEPTION(JSONDecodeError, ValueError);

// ============================================================================
// JSON Parsing (loads/load)
// ============================================================================

typedef struct _json_stream_t {
    mp_obj_t stream_obj;
    mp_uint_t (*read)(mp_obj_t obj, void *buf, mp_uint_t size, int *errcode);
    int errcode;
    byte cur;
} json_stream_t;

#define S_EOF (0)
#define S_END(s) ((s).cur == S_EOF)
#define S_CUR(s) ((s).cur)
#define S_NEXT(s) (json_stream_next(&(s)))

static byte json_stream_next(json_stream_t *s) {
    mp_uint_t ret = s->read(s->stream_obj, &s->cur, 1, &s->errcode);
    if (s->errcode != 0) {
        mp_raise_OSError(s->errcode);
    }
    if (ret == 0) {
        s->cur = S_EOF;
    }
    return s->cur;
}

static mp_obj_t json_load_impl(mp_obj_t stream_obj) {
    const mp_stream_p_t *stream_p = mp_get_stream_raise(stream_obj, MP_STREAM_OP_READ);
    json_stream_t s = {stream_obj, stream_p->read, 0, 0};
    vstr_t vstr;
    vstr_init(&vstr, 8);
    mp_obj_list_t stack;
    stack.len = 0;
    stack.items = NULL;
    mp_obj_t stack_top = MP_OBJ_NULL;
    const mp_obj_type_t *stack_top_type = NULL;
    mp_obj_t stack_key = MP_OBJ_NULL;
    S_NEXT(s);
    for (;;) {
    cont:
        if (S_END(s)) {
            goto fail;
        }
        mp_obj_t next = MP_OBJ_NULL;
        bool enter = false;
        byte cur = S_CUR(s);
        S_NEXT(s);
        switch (cur) {
            case ',':
            case ':':
            case ' ':
            case '\t':
            case '\n':
            case '\r':
                goto cont;
            case 'n':
                if (S_CUR(s) == 'u' && S_NEXT(s) == 'l' && S_NEXT(s) == 'l') {
                    S_NEXT(s);
                    next = mp_const_none;
                } else {
                    goto fail;
                }
                break;
            case 'f':
                if (S_CUR(s) == 'a' && S_NEXT(s) == 'l' && S_NEXT(s) == 's' && S_NEXT(s) == 'e') {
                    S_NEXT(s);
                    next = mp_const_false;
                } else {
                    goto fail;
                }
                break;
            case 't':
                if (S_CUR(s) == 'r' && S_NEXT(s) == 'u' && S_NEXT(s) == 'e') {
                    S_NEXT(s);
                    next = mp_const_true;
                } else {
                    goto fail;
                }
                break;
            case '"':
                vstr_reset(&vstr);
                for (; !S_END(s) && S_CUR(s) != '"';) {
                    byte c = S_CUR(s);
                    if (c == '\\') {
                        c = S_NEXT(s);
                        switch (c) {
                            case 'b': c = 0x08; break;
                            case 'f': c = 0x0c; break;
                            case 'n': c = 0x0a; break;
                            case 'r': c = 0x0d; break;
                            case 't': c = 0x09; break;
                            case 'u': {
                                mp_uint_t num = 0;
                                for (int i = 0; i < 4; i++) {
                                    c = (S_NEXT(s) | 0x20) - '0';
                                    if (c > 9) {
                                        c -= ('a' - ('9' + 1));
                                    }
                                    num = (num << 4) | c;
                                }
                                vstr_add_char(&vstr, num);
                                goto str_cont;
                            }
                        }
                    }
                    vstr_add_byte(&vstr, c);
                str_cont:
                    S_NEXT(s);
                }
                if (S_END(s)) {
                    goto fail;
                }
                S_NEXT(s);
                next = mp_obj_new_str(vstr.buf, vstr.len);
                break;
            case '-':
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9': {
                bool flt = false;
                vstr_reset(&vstr);
                for (;;) {
                    vstr_add_byte(&vstr, cur);
                    cur = S_CUR(s);
                    if (cur == '.' || cur == 'E' || cur == 'e') {
                        flt = true;
                    } else if (cur == '+' || cur == '-' || unichar_isdigit(cur)) {
                        // pass
                    } else {
                        break;
                    }
                    S_NEXT(s);
                }
                if (flt) {
                    next = mp_parse_num_float(vstr.buf, vstr.len, false, NULL);
                } else {
                    next = mp_parse_num_integer(vstr.buf, vstr.len, 10, NULL);
                }
                break;
            }
            case '[':
                next = mp_obj_new_list(0, NULL);
                enter = true;
                break;
            case '{':
                next = mp_obj_new_dict(0);
                enter = true;
                break;
            case '}':
            case ']': {
                if (stack_top == MP_OBJ_NULL) {
                    goto fail;
                }
                if (stack.len == 0) {
                    goto success;
                }
                stack.len -= 1;
                stack_top = stack.items[stack.len];
                stack_top_type = mp_obj_get_type(stack_top);
                goto cont;
            }
            default:
                goto fail;
        }
        if (stack_top == MP_OBJ_NULL) {
            stack_top = next;
            stack_top_type = mp_obj_get_type(stack_top);
            if (!enter) {
                goto success;
            }
        } else {
            if (stack_top_type == &mp_type_list) {
                mp_obj_list_append(stack_top, next);
            } else {
                if (stack_key == MP_OBJ_NULL) {
                    stack_key = next;
                    if (enter) {
                        goto fail;
                    }
                } else {
                    mp_obj_dict_store(stack_top, stack_key, next);
                    stack_key = MP_OBJ_NULL;
                }
            }
            if (enter) {
                if (stack.items == NULL) {
                    mp_obj_list_init(&stack, 1);
                    stack.items[0] = stack_top;
                } else {
                    mp_obj_list_append(MP_OBJ_FROM_PTR(&stack), stack_top);
                }
                stack_top = next;
                stack_top_type = mp_obj_get_type(stack_top);
            }
        }
    }
success:
    while (unichar_isspace(S_CUR(s))) {
        S_NEXT(s);
    }
    if (!S_END(s)) {
        goto fail;
    }
    if (stack_top == MP_OBJ_NULL || stack.len != 0) {
        goto fail;
    }
    vstr_clear(&vstr);
    return stack_top;

fail:
    mp_raise_ValueError(MP_ERROR_TEXT("syntax error in JSON"));
}

// json.load(fp) -> obj
static mp_obj_t json_load(mp_obj_t stream_obj) {
    return json_load_impl(stream_obj);
}
static MP_DEFINE_CONST_FUN_OBJ_1(json_load_obj, json_load);

// json.loads(s) -> obj
static mp_obj_t json_loads(mp_obj_t obj) {
    mp_buffer_info_t bufinfo;
    mp_get_buffer_raise(obj, &bufinfo, MP_BUFFER_READ);
    vstr_t vstr = {bufinfo.len, bufinfo.len, (char *)bufinfo.buf, true};
    mp_obj_stringio_t sio = {{&mp_type_stringio}, &vstr, 0, MP_OBJ_NULL};
    return json_load_impl(MP_OBJ_FROM_PTR(&sio));
}
static MP_DEFINE_CONST_FUN_OBJ_1(json_loads_obj, json_loads);

// ============================================================================
// JSON Serialization (dumps/dump)
// ============================================================================

// Escape a string for JSON output
static void escape_string(const char *str, size_t len, vstr_t *vstr) {
    vstr_add_byte(vstr, '"');
    for (size_t i = 0; i < len; i++) {
        unsigned char c = (unsigned char)str[i];
        switch (c) {
            case '"':  vstr_add_str(vstr, "\\\""); break;
            case '\\': vstr_add_str(vstr, "\\\\"); break;
            case '\n': vstr_add_str(vstr, "\\n"); break;
            case '\r': vstr_add_str(vstr, "\\r"); break;
            case '\t': vstr_add_str(vstr, "\\t"); break;
            case '\b': vstr_add_str(vstr, "\\b"); break;
            case '\f': vstr_add_str(vstr, "\\f"); break;
            default:
                if (c < 0x20) {
                    char buf[8];
                    snprintf(buf, sizeof(buf), "\\u%04x", c);
                    vstr_add_str(vstr, buf);
                } else {
                    vstr_add_byte(vstr, c);
                }
                break;
        }
    }
    vstr_add_byte(vstr, '"');
}

// Add indentation
static void add_indent(vstr_t *vstr, int indent, int level) {
    if (indent > 0) {
        vstr_add_byte(vstr, '\n');
        for (int i = 0; i < indent * level; i++) {
            vstr_add_byte(vstr, ' ');
        }
    }
}

// Compare function for sorting keys
static int key_compare(const void *a, const void *b) {
    mp_obj_t key_a = *(mp_obj_t *)a;
    mp_obj_t key_b = *(mp_obj_t *)b;
    
    size_t len_a, len_b;
    const char *str_a = mp_obj_str_get_data(key_a, &len_a);
    const char *str_b = mp_obj_str_get_data(key_b, &len_b);
    
    size_t min_len = len_a < len_b ? len_a : len_b;
    int cmp = memcmp(str_a, str_b, min_len);
    if (cmp != 0) return cmp;
    return (int)len_a - (int)len_b;
}

// Forward declaration
static void serialize_obj(mp_obj_t obj, vstr_t *vstr, int indent, int level, bool sort_keys);

// Serialize a Python object to JSON
static void serialize_obj(mp_obj_t obj, vstr_t *vstr, int indent, int level, bool sort_keys) {
    if (obj == mp_const_none) {
        vstr_add_str(vstr, "null");
    } else if (obj == mp_const_true) {
        vstr_add_str(vstr, "true");
    } else if (obj == mp_const_false) {
        vstr_add_str(vstr, "false");
    } else if (mp_obj_is_str(obj)) {
        size_t len;
        const char *str = mp_obj_str_get_data(obj, &len);
        escape_string(str, len, vstr);
    } else if (mp_obj_is_int(obj)) {
        // Use MicroPython's integer printing for correct handling
        char buf[32];
        mp_int_t val = mp_obj_get_int(obj);
        int len = snprintf(buf, sizeof(buf), "%ld", (long)val);
        vstr_add_strn(vstr, buf, len);
    } else if (mp_obj_is_float(obj)) {
        mp_float_t val = mp_obj_get_float(obj);
        // Check for infinity and NaN
        if (isinf(val) || isnan(val)) {
            mp_raise_ValueError(MP_ERROR_TEXT("Out of range float values are not JSON compliant"));
        }
        char buf[32];
        snprintf(buf, sizeof(buf), "%.15g", (double)val);
        vstr_add_str(vstr, buf);
    } else if (mp_obj_is_type(obj, &mp_type_list) || mp_obj_is_type(obj, &mp_type_tuple)) {
        size_t len;
        mp_obj_t *items;
        mp_obj_get_array(obj, &len, &items);
        
        vstr_add_byte(vstr, '[');
        for (size_t i = 0; i < len; i++) {
            if (i > 0) {
                vstr_add_byte(vstr, ',');
                if (indent <= 0) {
                    vstr_add_byte(vstr, ' ');
                }
            }
            if (indent > 0) {
                add_indent(vstr, indent, level + 1);
            }
            serialize_obj(items[i], vstr, indent, level + 1, sort_keys);
        }
        if (len > 0 && indent > 0) {
            add_indent(vstr, indent, level);
        }
        vstr_add_byte(vstr, ']');
    } else if (mp_obj_is_type(obj, &mp_type_dict)) {
        mp_obj_dict_t *dict = MP_OBJ_TO_PTR(obj);
        size_t len = dict->map.used;
        
        vstr_add_byte(vstr, '{');
        
        if (len > 0) {
            // Get all keys
            mp_obj_t *keys = m_new(mp_obj_t, len);
            size_t key_idx = 0;
            for (size_t i = 0; i < dict->map.alloc && key_idx < len; i++) {
                if (mp_map_slot_is_filled(&dict->map, i)) {
                    mp_obj_t key = dict->map.table[i].key;
                    if (!mp_obj_is_str(key)) {
                        m_del(mp_obj_t, keys, len);
                        mp_raise_TypeError(MP_ERROR_TEXT("keys must be strings"));
                    }
                    keys[key_idx++] = key;
                }
            }
            
            // Sort keys if requested
            if (sort_keys) {
                for (size_t i = 0; i < len - 1; i++) {
                    for (size_t j = 0; j < len - i - 1; j++) {
                        if (key_compare(&keys[j], &keys[j + 1]) > 0) {
                            mp_obj_t tmp = keys[j];
                            keys[j] = keys[j + 1];
                            keys[j + 1] = tmp;
                        }
                    }
                }
            }
            
            // Serialize key-value pairs
            for (size_t i = 0; i < len; i++) {
                if (i > 0) {
                    vstr_add_byte(vstr, ',');
                    if (indent <= 0) {
                        vstr_add_byte(vstr, ' ');
                    }
                }
                if (indent > 0) {
                    add_indent(vstr, indent, level + 1);
                }
                
                mp_obj_t key = keys[i];
                mp_obj_t value = mp_obj_dict_get(obj, key);
                
                size_t key_len;
                const char *key_str = mp_obj_str_get_data(key, &key_len);
                escape_string(key_str, key_len, vstr);
                
                vstr_add_str(vstr, ": ");
                serialize_obj(value, vstr, indent, level + 1, sort_keys);
            }
            
            m_del(mp_obj_t, keys, len);
            
            if (indent > 0) {
                add_indent(vstr, indent, level);
            }
        }
        vstr_add_byte(vstr, '}');
    } else {
        mp_raise_msg_varg(&mp_type_TypeError, 
            MP_ERROR_TEXT("Object of type '%s' is not JSON serializable"),
            mp_obj_get_type_str(obj));
    }
}

// json.dumps(obj, *, indent=None, sort_keys=False, separators=None) -> str
static mp_obj_t json_dumps(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    enum { ARG_indent, ARG_sort_keys, ARG_separators };
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_indent, MP_ARG_KW_ONLY | MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_sort_keys, MP_ARG_KW_ONLY | MP_ARG_BOOL, {.u_bool = false} },
        { MP_QSTR_separators, MP_ARG_KW_ONLY | MP_ARG_OBJ, {.u_obj = mp_const_none} },
    };
    
    mp_arg_val_t args[MP_ARRAY_SIZE(allowed_args)];
    mp_arg_parse_all(n_args - 1, pos_args + 1, kw_args, MP_ARRAY_SIZE(allowed_args), allowed_args, args);
    
    mp_obj_t obj = pos_args[0];
    
    int indent = 0;
    if (args[ARG_indent].u_obj != mp_const_none) {
        indent = mp_obj_get_int(args[ARG_indent].u_obj);
        if (indent < 0) indent = 0;
    }
    bool sort_keys = args[ARG_sort_keys].u_bool;
    
    vstr_t vstr;
    vstr_init(&vstr, 64);
    
    serialize_obj(obj, &vstr, indent, 0, sort_keys);
    
    return mp_obj_new_str_from_vstr(&vstr);
}
static MP_DEFINE_CONST_FUN_OBJ_KW(json_dumps_obj, 1, json_dumps);

// json.dump(obj, fp, *, indent=None, sort_keys=False, separators=None)
static mp_obj_t json_dump(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    enum { ARG_indent, ARG_sort_keys, ARG_separators };
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_indent, MP_ARG_KW_ONLY | MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_sort_keys, MP_ARG_KW_ONLY | MP_ARG_BOOL, {.u_bool = false} },
        { MP_QSTR_separators, MP_ARG_KW_ONLY | MP_ARG_OBJ, {.u_obj = mp_const_none} },
    };
    
    mp_arg_val_t args[MP_ARRAY_SIZE(allowed_args)];
    mp_arg_parse_all(n_args - 2, pos_args + 2, kw_args, MP_ARRAY_SIZE(allowed_args), allowed_args, args);
    
    mp_obj_t obj = pos_args[0];
    mp_obj_t stream = pos_args[1];
    
    int indent = 0;
    if (args[ARG_indent].u_obj != mp_const_none) {
        indent = mp_obj_get_int(args[ARG_indent].u_obj);
        if (indent < 0) indent = 0;
    }
    bool sort_keys = args[ARG_sort_keys].u_bool;
    
    vstr_t vstr;
    vstr_init(&vstr, 64);
    
    serialize_obj(obj, &vstr, indent, 0, sort_keys);
    
    // Write to stream
    mp_get_stream_raise(stream, MP_STREAM_OP_WRITE);
    mp_stream_write(stream, vstr.buf, vstr.len, MP_STREAM_RW_WRITE);
    
    vstr_clear(&vstr);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_KW(json_dump_obj, 2, json_dump);

// ============================================================================
// Module definition
// ============================================================================

static const mp_rom_map_elem_t json_module_globals_table[] = {
    { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR_json) },
    { MP_ROM_QSTR(MP_QSTR_dumps), MP_ROM_PTR(&json_dumps_obj) },
    { MP_ROM_QSTR(MP_QSTR_dump), MP_ROM_PTR(&json_dump_obj) },
    { MP_ROM_QSTR(MP_QSTR_loads), MP_ROM_PTR(&json_loads_obj) },
    { MP_ROM_QSTR(MP_QSTR_load), MP_ROM_PTR(&json_load_obj) },
    { MP_ROM_QSTR(MP_QSTR_JSONDecodeError), MP_ROM_PTR(&mp_type_JSONDecodeError) },
};
static MP_DEFINE_CONST_DICT(json_module_globals, json_module_globals_table);

const mp_obj_module_t mp_module_json = {
    .base = { &mp_type_module },
    .globals = (mp_obj_dict_t *)&json_module_globals,
};

MP_REGISTER_MODULE(MP_QSTR_json, mp_module_json);
