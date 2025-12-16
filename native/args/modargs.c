/*
 * modargs - Native argument parsing module for microcharm
 * 
 * This is the thin C bridge that wraps the Zig core (args.zig) for MicroPython.
 * All parsing logic is in Zig - this file only handles MicroPython API.
 * 
 * Usage in Python:
 *   import args
 *   opts = args.parse({'--name': str, '--count': int, '--verbose': bool})
 */

#include "py/runtime.h"
#include "py/obj.h"
#include "py/objstr.h"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// ============================================================================
// Zig function declarations (implemented in args.zig, exported with C ABI)
// ============================================================================

extern bool args_is_valid_int(const char *str);
extern bool args_is_valid_float(const char *str);
extern int64_t args_parse_int(const char *str);
extern bool args_is_long_flag(const char *str);
extern bool args_is_short_flag(const char *str);
extern bool args_is_dashdash(const char *str);
extern bool args_is_negative_number(const char *str);
extern const char *args_get_flag_name(const char *str);
extern bool args_streq(const char *a, const char *b);
extern size_t args_strlen(const char *str);
extern bool args_is_truthy(const char *str);
extern bool args_is_falsy(const char *str);
extern bool args_is_negated_flag(const char *name);
extern const char *args_get_negated_base(const char *name);

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
// Returns raw sys.argv as a list
// ============================================================================

static mp_obj_t mod_args_raw(void) {
    return get_sys_argv();
}
static MP_DEFINE_CONST_FUN_OBJ_0(mod_args_raw_obj, mod_args_raw);

// ============================================================================
// args.get(index, default=None) -> str
// Get argument by index with optional default
// ============================================================================

static mp_obj_t mod_args_get(size_t n_args, const mp_obj_t *args_in) {
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    
    int idx = mp_obj_get_int(args_in[0]);
    
    // Handle negative indices
    if (idx < 0) {
        idx = (int)len + idx;
    }
    
    if (idx >= 0 && (size_t)idx < len) {
        return items[idx];
    }
    
    // Return default if provided, else None
    if (n_args > 1) {
        return args_in[1];
    }
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_args_get_obj, 1, 2, mod_args_get);

// ============================================================================
// args.count() -> int
// Return number of arguments
// ============================================================================

static mp_obj_t mod_args_count(void) {
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    return MP_OBJ_NEW_SMALL_INT(len);
}
static MP_DEFINE_CONST_FUN_OBJ_0(mod_args_count_obj, mod_args_count);

// ============================================================================
// args.has(flag) -> bool  
// Check if a flag exists (e.g., args.has('--verbose'))
// ============================================================================

static mp_obj_t mod_args_has(mp_obj_t flag_obj) {
    const char *flag = mp_obj_str_get_str(flag_obj);
    
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    
    for (size_t i = 0; i < len; i++) {
        const char *arg = mp_obj_str_get_str(items[i]);
        if (args_streq(arg, flag)) {
            return mp_const_true;
        }
    }
    return mp_const_false;
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_args_has_obj, mod_args_has);

// ============================================================================
// args.value(flag, default=None) -> str
// Get the value after a flag (e.g., args.value('--name') for --name World)
// ============================================================================

static mp_obj_t mod_args_value(size_t n_args, const mp_obj_t *args_in) {
    const char *flag = mp_obj_str_get_str(args_in[0]);
    size_t flag_len = args_strlen(flag);
    
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    
    for (size_t i = 0; i < len; i++) {
        const char *arg = mp_obj_str_get_str(items[i]);
        
        // Check for exact match with next arg as value
        if (args_streq(arg, flag) && i + 1 < len) {
            return items[i + 1];
        }
        
        // Handle --flag=value syntax
        if (strncmp(arg, flag, flag_len) == 0 && arg[flag_len] == '=') {
            return mp_obj_new_str(arg + flag_len + 1, strlen(arg + flag_len + 1));
        }
    }
    
    // Return default if provided
    if (n_args > 1) {
        return args_in[1];
    }
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_args_value_obj, 1, 2, mod_args_value);

// ============================================================================
// args.int_value(flag, default=0) -> int
// Get integer value after a flag
// ============================================================================

static mp_obj_t mod_args_int_value(size_t n_args, const mp_obj_t *args_in) {
    mp_obj_t val_args[2] = { args_in[0], mp_const_none };
    mp_obj_t val = mod_args_value(2, val_args);
    
    if (val == mp_const_none) {
        if (n_args > 1) {
            return args_in[1];
        }
        return MP_OBJ_NEW_SMALL_INT(0);
    }
    
    const char *str = mp_obj_str_get_str(val);
    if (args_is_valid_int(str)) {
        return mp_obj_new_int(args_parse_int(str));
    }
    
    // Invalid integer - return default
    if (n_args > 1) {
        return args_in[1];
    }
    return MP_OBJ_NEW_SMALL_INT(0);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_args_int_value_obj, 1, 2, mod_args_int_value);

// ============================================================================
// args.positional() -> list
// Get all positional arguments (non-flag arguments)
// ============================================================================

static mp_obj_t mod_args_positional(void) {
    mp_obj_t argv = get_sys_argv();
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(argv, &len, &items);
    
    mp_obj_t result = mp_obj_new_list(0, NULL);
    int after_dashdash = 0;
    int skip_next = 0;
    
    // Start from index 1 to skip script name
    for (size_t i = 1; i < len; i++) {
        if (skip_next) {
            skip_next = 0;
            continue;
        }
        
        const char *arg = mp_obj_str_get_str(items[i]);
        
        // After --, everything is positional
        if (after_dashdash) {
            mp_obj_list_append(result, items[i]);
            continue;
        }
        
        // Check for --
        if (args_is_dashdash(arg)) {
            after_dashdash = 1;
            continue;
        }
        
        // Skip flags and their values
        if (args_is_long_flag(arg)) {
            // Check if it has = in it
            if (strchr(arg, '=') == NULL) {
                // Might have a value after it - skip next if it's not a flag
                if (i + 1 < len) {
                    const char *next = mp_obj_str_get_str(items[i + 1]);
                    if (!args_is_long_flag(next) && !args_is_short_flag(next)) {
                        skip_next = 1;
                    }
                }
            }
            continue;
        }
        
        if (args_is_short_flag(arg) && !args_is_negative_number(arg)) {
            // Short flag might have value after
            if (i + 1 < len) {
                const char *next = mp_obj_str_get_str(items[i + 1]);
                if (!args_is_long_flag(next) && !args_is_short_flag(next)) {
                    skip_next = 1;
                }
            }
            continue;
        }
        
        // It's a positional argument
        mp_obj_list_append(result, items[i]);
    }
    
    return result;
}
static MP_DEFINE_CONST_FUN_OBJ_0(mod_args_positional_obj, mod_args_positional);

// ============================================================================
// args.parse(spec) -> dict
// Parse arguments according to a specification dict
// 
// spec format:
//   {'--name': str, '--count': int, '--verbose': bool, '-n': '--name'}
// 
// Returns dict with clean names (no dashes):
//   {'name': 'World', 'count': 5, 'verbose': True, '_': ['file1', 'file2']}
// ============================================================================

static mp_obj_t mod_args_parse(mp_obj_t spec_obj) {
    // Get argv
    mp_obj_t argv = get_sys_argv();
    size_t argc;
    mp_obj_t *argv_items;
    mp_obj_list_get(argv, &argc, &argv_items);
    
    // Result dict
    mp_obj_t result = mp_obj_new_dict(0);
    mp_obj_t positional = mp_obj_new_list(0, NULL);
    
    // Get spec dict
    mp_map_t *spec_map = mp_obj_dict_get_map(spec_obj);
    
    // Build alias map (short -> long)
    mp_obj_t aliases = mp_obj_new_dict(0);
    for (size_t i = 0; i < spec_map->alloc; i++) {
        if (mp_map_slot_is_filled(spec_map, i)) {
            mp_obj_t key = spec_map->table[i].key;
            mp_obj_t val = spec_map->table[i].value;
            
            // If value is a string, it's an alias
            if (mp_obj_is_str(val)) {
                mp_obj_dict_store(aliases, key, val);
            }
        }
    }
    mp_map_t *alias_map = mp_obj_dict_get_map(aliases);
    
    // Parse arguments
    int after_dashdash = 0;
    
    for (size_t i = 1; i < argc; i++) {
        const char *arg = mp_obj_str_get_str(argv_items[i]);
        
        // After --, everything is positional
        if (after_dashdash) {
            mp_obj_list_append(positional, argv_items[i]);
            continue;
        }
        
        // Check for --
        if (args_is_dashdash(arg)) {
            after_dashdash = 1;
            continue;
        }
        
        // Handle flags
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
                    flag_key = mp_obj_new_str(flag_buf, flag_len);
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
                const char *flag_name = args_get_flag_name(mp_obj_str_get_str(flag_key));
                if (args_is_negated_flag(flag_name)) {
                    const char *base = args_get_negated_base(flag_name);
                    char full_flag[128];
                    snprintf(full_flag, sizeof(full_flag), "--%s", base);
                    mp_obj_t base_key = mp_obj_new_str(full_flag, strlen(full_flag));
                    spec_elem = mp_map_lookup(spec_map, base_key, MP_MAP_LOOKUP);
                    if (spec_elem != NULL) {
                        // It's a negated boolean
                        mp_obj_dict_store(result, mp_obj_new_str(base, strlen(base)), mp_const_false);
                        continue;
                    }
                }
                // Unknown flag - skip
                continue;
            }
            
            mp_obj_t type_obj = spec_elem->value;
            const char *clean_name = args_get_flag_name(mp_obj_str_get_str(flag_key));
            mp_obj_t name_key = mp_obj_new_str(clean_name, strlen(clean_name));
            
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
                // Boolean flag - presence means true
                mp_obj_dict_store(result, name_key, mp_const_true);
            } else {
                // Get value
                mp_obj_t value;
                if (value_str != NULL) {
                    value = mp_obj_new_str(value_str, strlen(value_str));
                } else if (i + 1 < argc) {
                    i++;
                    value = argv_items[i];
                } else {
                    continue; // No value available
                }
                
                // Convert type
                if (type_obj == (mp_obj_t)&mp_type_int) {
                    const char *vs = mp_obj_str_get_str(value);
                    if (args_is_valid_int(vs)) {
                        mp_obj_dict_store(result, name_key, mp_obj_new_int(args_parse_int(vs)));
                    }
                } else if (type_obj == (mp_obj_t)&mp_type_str) {
                    mp_obj_dict_store(result, name_key, value);
                } else {
                    // Unknown type, store as string
                    mp_obj_dict_store(result, name_key, value);
                }
            }
        } else {
            // Positional argument
            mp_obj_list_append(positional, argv_items[i]);
        }
    }
    
    // Apply defaults from spec
    for (size_t i = 0; i < spec_map->alloc; i++) {
        if (mp_map_slot_is_filled(spec_map, i)) {
            mp_obj_t key = spec_map->table[i].key;
            mp_obj_t val = spec_map->table[i].value;
            
            // Skip aliases
            if (mp_obj_is_str(val)) continue;
            
            const char *key_str = mp_obj_str_get_str(key);
            if (!args_is_long_flag(key_str) && !args_is_short_flag(key_str)) continue;
            
            const char *clean_name = args_get_flag_name(key_str);
            mp_obj_t name_key = mp_obj_new_str(clean_name, strlen(clean_name));
            
            // Check if already set
            mp_map_t *result_map = mp_obj_dict_get_map(result);
            mp_map_elem_t *existing = mp_map_lookup(result_map, name_key, MP_MAP_LOOKUP);
            if (existing != NULL) continue;
            
            // Apply default
            if (mp_obj_is_type(val, &mp_type_tuple)) {
                size_t tuple_len;
                mp_obj_t *tuple_items;
                mp_obj_tuple_get(val, &tuple_len, &tuple_items);
                if (tuple_len >= 2) {
                    mp_obj_dict_store(result, name_key, tuple_items[1]);
                } else if (tuple_len == 1 && tuple_items[0] == (mp_obj_t)&mp_type_bool) {
                    mp_obj_dict_store(result, name_key, mp_const_false);
                }
            } else if (val == (mp_obj_t)&mp_type_bool) {
                mp_obj_dict_store(result, name_key, mp_const_false);
            }
        }
    }
    
    // Add positional args as '_'
    mp_obj_dict_store(result, mp_obj_new_str("_", 1), positional);
    
    return result;
}
static MP_DEFINE_CONST_FUN_OBJ_1(mod_args_parse_obj, mod_args_parse);

// ============================================================================
// Module definition
// ============================================================================

static const mp_rom_map_elem_t args_module_globals_table[] = {
    { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR_args) },
    { MP_ROM_QSTR(MP_QSTR_raw), MP_ROM_PTR(&mod_args_raw_obj) },
    { MP_ROM_QSTR(MP_QSTR_get), MP_ROM_PTR(&mod_args_get_obj) },
    { MP_ROM_QSTR(MP_QSTR_count), MP_ROM_PTR(&mod_args_count_obj) },
    { MP_ROM_QSTR(MP_QSTR_has), MP_ROM_PTR(&mod_args_has_obj) },
    { MP_ROM_QSTR(MP_QSTR_value), MP_ROM_PTR(&mod_args_value_obj) },
    { MP_ROM_QSTR(MP_QSTR_int_value), MP_ROM_PTR(&mod_args_int_value_obj) },
    { MP_ROM_QSTR(MP_QSTR_positional), MP_ROM_PTR(&mod_args_positional_obj) },
    { MP_ROM_QSTR(MP_QSTR_parse), MP_ROM_PTR(&mod_args_parse_obj) },
};
static MP_DEFINE_CONST_DICT(args_module_globals, args_module_globals_table);

const mp_obj_module_t mp_module_args = {
    .base = { &mp_type_module },
    .globals = (mp_obj_dict_t *)&args_module_globals,
};

MP_REGISTER_MODULE(MP_QSTR_args, mp_module_args);
