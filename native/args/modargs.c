/*
 * modargs - Native argument parsing module for microcharm
 * 
 * C bridge that wraps Zig core (args.zig) for MicroPython.
 * All parsing logic is in Zig - this file only handles MicroPython API.
 * 
 * Usage in Python:
 *   import args
 *   opts = args.parse({'--name': str, '--count': int, '--verbose': bool})
 */

#include "../bridge/mpy_bridge.h"

#include <string.h>
#include <stdio.h>

// ============================================================================
// Zig Function Declarations
// ============================================================================

ZIG_EXTERN bool args_is_valid_int(const char *str);
ZIG_EXTERN bool args_is_valid_float(const char *str);
ZIG_EXTERN int64_t args_parse_int(const char *str);
ZIG_EXTERN bool args_is_long_flag(const char *str);
ZIG_EXTERN bool args_is_short_flag(const char *str);
ZIG_EXTERN bool args_is_dashdash(const char *str);
ZIG_EXTERN bool args_is_negative_number(const char *str);
ZIG_EXTERN const char *args_get_flag_name(const char *str);
ZIG_EXTERN bool args_streq(const char *a, const char *b);
ZIG_EXTERN size_t args_strlen(const char *str);
ZIG_EXTERN bool args_is_truthy(const char *str);
ZIG_EXTERN bool args_is_falsy(const char *str);
ZIG_EXTERN bool args_is_negated_flag(const char *name);
ZIG_EXTERN const char *args_get_negated_base(const char *name);

// ============================================================================
// Helper: Get sys.argv
// ============================================================================

static mp_obj_t get_sys_argv(void) {
    mp_obj_t sys_module = mp_import_name(MP_QSTR_sys, mp_const_none, MP_OBJ_NEW_SMALL_INT(0));
    mp_obj_t argv = mp_load_attr(sys_module, MP_QSTR_argv);
    return argv;
}

// ============================================================================
// args.raw() -> list
// ============================================================================

MPY_FUNC_0(args, raw) {
    return get_sys_argv();
}
MPY_FUNC_OBJ_0(args, raw);

// ============================================================================
// args.get(index, default=None) -> str
// ============================================================================

MPY_FUNC_VAR(args, get, 1, 2) {
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    
    int idx = mpy_int(args[0]);
    
    // Handle negative indices
    if (idx < 0) {
        idx = (int)len + idx;
    }
    
    if (idx >= 0 && (size_t)idx < len) {
        return items[idx];
    }
    
    // Return default if provided, else None
    return (n_args > 1) ? args[1] : mpy_none();
}
MPY_FUNC_OBJ_VAR(args, get, 1, 2);

// ============================================================================
// args.count() -> int
// ============================================================================

MPY_FUNC_0(args, count) {
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    return mpy_new_int(len);
}
MPY_FUNC_OBJ_0(args, count);

// ============================================================================
// args.has(flag) -> bool
// ============================================================================

MPY_FUNC_1(args, has) {
    const char *flag = mpy_str(arg0);
    
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    
    for (size_t i = 0; i < len; i++) {
        const char *arg = mpy_str(items[i]);
        if (args_streq(arg, flag)) {
            return mpy_bool(true);
        }
    }
    return mpy_bool(false);
}
MPY_FUNC_OBJ_1(args, has);

// ============================================================================
// args.value(flag, default=None) -> str
// ============================================================================

MPY_FUNC_VAR(args, value, 1, 2) {
    const char *flag = mpy_str(args[0]);
    size_t flag_len = args_strlen(flag);
    
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    
    for (size_t i = 0; i < len; i++) {
        const char *arg = mpy_str(items[i]);
        
        // Check for exact match with next arg as value
        if (args_streq(arg, flag) && i + 1 < len) {
            return items[i + 1];
        }
        
        // Handle --flag=value syntax
        if (strncmp(arg, flag, flag_len) == 0 && arg[flag_len] == '=') {
            return mpy_new_str(arg + flag_len + 1);
        }
    }
    
    return (n_args > 1) ? args[1] : mpy_none();
}
MPY_FUNC_OBJ_VAR(args, value, 1, 2);

// ============================================================================
// args.int_value(flag, default=0) -> int
// ============================================================================

MPY_FUNC_VAR(args, int_value, 1, 2) {
    mp_obj_t val_args[2] = { args[0], mpy_none() };
    mp_obj_t val = mod_args_value(2, val_args);
    
    if (val == mpy_none()) {
        return (n_args > 1) ? args[1] : mpy_new_int(0);
    }
    
    const char *str = mpy_str(val);
    if (args_is_valid_int(str)) {
        return mpy_new_int64(args_parse_int(str));
    }
    
    return (n_args > 1) ? args[1] : mpy_new_int(0);
}
MPY_FUNC_OBJ_VAR(args, int_value, 1, 2);

// ============================================================================
// args.positional() -> list
// ============================================================================

MPY_FUNC_0(args, positional) {
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    
    mp_obj_t result = mpy_new_list();
    int after_dashdash = 0;
    int skip_next = 0;
    
    // Start from index 1 to skip script name
    for (size_t i = 1; i < len; i++) {
        if (skip_next) {
            skip_next = 0;
            continue;
        }
        
        const char *arg = mpy_str(items[i]);
        
        // After --, everything is positional
        if (after_dashdash) {
            mpy_list_append(result, items[i]);
            continue;
        }
        
        // Check for --
        if (args_is_dashdash(arg)) {
            after_dashdash = 1;
            continue;
        }
        
        // Skip flags and their values
        if (args_is_long_flag(arg)) {
            if (strchr(arg, '=') == NULL) {
                if (i + 1 < len) {
                    const char *next = mpy_str(items[i + 1]);
                    if (!args_is_long_flag(next) && !args_is_short_flag(next)) {
                        skip_next = 1;
                    }
                }
            }
            continue;
        }
        
        if (args_is_short_flag(arg) && !args_is_negative_number(arg)) {
            if (i + 1 < len) {
                const char *next = mpy_str(items[i + 1]);
                if (!args_is_long_flag(next) && !args_is_short_flag(next)) {
                    skip_next = 1;
                }
            }
            continue;
        }
        
        // It's a positional argument
        mpy_list_append(result, items[i]);
    }
    
    return result;
}
MPY_FUNC_OBJ_0(args, positional);

// ============================================================================
// args.parse(spec) -> dict
// ============================================================================

MPY_FUNC_1(args, parse) {
    mp_obj_t argv = get_sys_argv();
    size_t argc;
    mp_obj_t *argv_items;
    mp_obj_list_get(argv, &argc, &argv_items);
    
    mp_obj_t result = mpy_new_dict();
    mp_obj_t positional = mpy_new_list();
    
    mp_map_t *spec_map = mp_obj_dict_get_map(arg0);
    
    // Build alias map (short -> long)
    mp_obj_t aliases = mpy_new_dict();
    for (size_t i = 0; i < spec_map->alloc; i++) {
        if (mp_map_slot_is_filled(spec_map, i)) {
            mp_obj_t key = spec_map->table[i].key;
            mp_obj_t val = spec_map->table[i].value;
            if (mp_obj_is_str(val)) {
                mpy_dict_store(aliases, key, val);
            }
        }
    }
    mp_map_t *alias_map = mp_obj_dict_get_map(aliases);
    
    // Parse arguments
    int after_dashdash = 0;
    
    for (size_t i = 1; i < argc; i++) {
        const char *arg = mpy_str(argv_items[i]);
        
        if (after_dashdash) {
            mpy_list_append(positional, argv_items[i]);
            continue;
        }
        
        if (args_is_dashdash(arg)) {
            after_dashdash = 1;
            continue;
        }
        
        if (args_is_long_flag(arg) || (args_is_short_flag(arg) && !args_is_negative_number(arg))) {
            mp_obj_t flag_key = argv_items[i];
            
            // Handle --flag=value syntax
            const char *eq = strchr(arg, '=');
            char flag_buf[128];
            const char *value_str = NULL;
            
            if (eq != NULL) {
                size_t flag_len = eq - arg;
                if (flag_len < sizeof(flag_buf)) {
                    memcpy(flag_buf, arg, flag_len);
                    flag_buf[flag_len] = '\0';
                    flag_key = mpy_new_str(flag_buf);
                    value_str = eq + 1;
                }
            }
            
            // Resolve alias
            mp_map_elem_t *alias_elem = mp_map_lookup(alias_map, flag_key, MP_MAP_LOOKUP);
            if (alias_elem != NULL) {
                flag_key = alias_elem->value;
            }
            
            // Look up in spec
            mp_map_elem_t *spec_elem = mp_map_lookup(spec_map, flag_key, MP_MAP_LOOKUP);
            if (spec_elem == NULL) {
                // Check for --no-flag (boolean negation)
                const char *flag_name = args_get_flag_name(mpy_str(flag_key));
                if (args_is_negated_flag(flag_name)) {
                    const char *base = args_get_negated_base(flag_name);
                    char full_flag[128];
                    snprintf(full_flag, sizeof(full_flag), "--%s", base);
                    mp_obj_t base_key = mpy_new_str(full_flag);
                    spec_elem = mp_map_lookup(spec_map, base_key, MP_MAP_LOOKUP);
                    if (spec_elem != NULL) {
                        mpy_dict_store_str(result, base, mpy_bool(false));
                        continue;
                    }
                }
                continue;
            }
            
            mp_obj_t type_obj = spec_elem->value;
            const char *clean_name = args_get_flag_name(mpy_str(flag_key));
            mp_obj_t name_key = mpy_new_str(clean_name);
            
            // Handle tuple (type, default) format
            if (mp_obj_is_type(type_obj, &mp_type_tuple)) {
                size_t tuple_len;
                mp_obj_t *tuple_items;
                mp_obj_tuple_get(type_obj, &tuple_len, &tuple_items);
                if (tuple_len >= 1) {
                    type_obj = tuple_items[0];
                }
            }
            
            // Check type and get value
            if (type_obj == (mp_obj_t)&mp_type_bool) {
                mpy_dict_store(result, name_key, mpy_bool(true));
            } else {
                mp_obj_t value;
                if (value_str != NULL) {
                    value = mpy_new_str(value_str);
                } else if (i + 1 < argc) {
                    i++;
                    value = argv_items[i];
                } else {
                    continue;
                }
                
                if (type_obj == (mp_obj_t)&mp_type_int) {
                    const char *vs = mpy_str(value);
                    if (args_is_valid_int(vs)) {
                        mpy_dict_store(result, name_key, mpy_new_int64(args_parse_int(vs)));
                    }
                } else if (type_obj == (mp_obj_t)&mp_type_str) {
                    mpy_dict_store(result, name_key, value);
                } else {
                    mpy_dict_store(result, name_key, value);
                }
            }
        } else {
            mpy_list_append(positional, argv_items[i]);
        }
    }
    
    // Apply defaults from spec
    for (size_t i = 0; i < spec_map->alloc; i++) {
        if (mp_map_slot_is_filled(spec_map, i)) {
            mp_obj_t key = spec_map->table[i].key;
            mp_obj_t val = spec_map->table[i].value;
            
            if (mp_obj_is_str(val)) continue;
            
            const char *key_str = mpy_str(key);
            if (!args_is_long_flag(key_str) && !args_is_short_flag(key_str)) continue;
            
            const char *clean_name = args_get_flag_name(key_str);
            mp_obj_t name_key = mpy_new_str(clean_name);
            
            mp_map_t *result_map = mp_obj_dict_get_map(result);
            mp_map_elem_t *existing = mp_map_lookup(result_map, name_key, MP_MAP_LOOKUP);
            if (existing != NULL) continue;
            
            if (mp_obj_is_type(val, &mp_type_tuple)) {
                size_t tuple_len;
                mp_obj_t *tuple_items;
                mp_obj_tuple_get(val, &tuple_len, &tuple_items);
                if (tuple_len >= 2) {
                    mpy_dict_store(result, name_key, tuple_items[1]);
                } else if (tuple_len == 1 && tuple_items[0] == (mp_obj_t)&mp_type_bool) {
                    mpy_dict_store(result, name_key, mpy_bool(false));
                }
            } else if (val == (mp_obj_t)&mp_type_bool) {
                mpy_dict_store(result, name_key, mpy_bool(false));
            }
        }
    }
    
    mpy_dict_store_str(result, "_", positional);
    
    return result;
}
MPY_FUNC_OBJ_1(args, parse);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(args)
    MPY_MODULE_FUNC(args, raw)
    MPY_MODULE_FUNC(args, get)
    MPY_MODULE_FUNC(args, count)
    MPY_MODULE_FUNC(args, has)
    MPY_MODULE_FUNC(args, value)
    MPY_MODULE_FUNC(args, int_value)
    MPY_MODULE_FUNC(args, positional)
    MPY_MODULE_FUNC(args, parse)
MPY_MODULE_END(args)
