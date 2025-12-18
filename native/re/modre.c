/*
 * modre.c - Extension to MicroPython's re module
 *
 * Adds missing CPython-compatible functions:
 *   - re.findall(pattern, string) -> list of matches
 *   - re.split(pattern, string, maxsplit=0) -> list of strings
 *
 * Uses MP_REGISTER_MODULE_DELEGATION to extend the built-in re module.
 */

#include "py/runtime.h"
#include "py/objstr.h"

// re.findall(pattern, string) -> list
// Returns all non-overlapping matches of pattern in string
static mp_obj_t re_ext_findall(mp_obj_t pattern_in, mp_obj_t string_in) {
    // Get re module and compile function
    mp_obj_t re_mod = mp_import_name(MP_QSTR_re, mp_const_none, MP_OBJ_NEW_SMALL_INT(0));
    mp_obj_t compile_func = mp_load_attr(re_mod, MP_QSTR_compile);
    
    // Compile pattern if needed
    mp_obj_t compiled;
    mp_obj_t dest[2];
    mp_load_method_maybe(pattern_in, MP_QSTR_search, dest);
    if (dest[0] != MP_OBJ_NULL) {
        compiled = pattern_in;  // Already compiled
    } else {
        compiled = mp_call_function_1(compile_func, pattern_in);
    }
    
    // Get search method from compiled pattern
    mp_obj_t search_method[2];
    mp_load_method(compiled, MP_QSTR_search, search_method);
    
    // Get string data for position tracking
    size_t str_len;
    const char *str_data = mp_obj_str_get_data(string_in, &str_len);
    const mp_obj_type_t *str_type = mp_obj_get_type(string_in);
    
    mp_obj_t results = mp_obj_new_list(0, NULL);
    size_t pos = 0;
    
    while (pos <= str_len) {
        // Create substring from current position
        mp_obj_t substr = mp_obj_new_str_of_type(str_type, (const byte *)(str_data + pos), str_len - pos);
        
        // Call compiled.search(substr)
        mp_obj_t call_args[3] = {search_method[0], search_method[1], substr};
        mp_obj_t match = mp_call_method_n_kw(1, 0, call_args);
        
        if (match == mp_const_none) {
            break;
        }
        
        // Get match.group(0)
        mp_obj_t group_method[2];
        mp_load_method(match, MP_QSTR_group, group_method);
        mp_obj_t group_args[3] = {group_method[0], group_method[1], MP_OBJ_NEW_SMALL_INT(0)};
        mp_obj_t matched = mp_call_method_n_kw(1, 0, group_args);
        
        // Check for capture groups via groups() method
        mp_obj_t groups_dest[2];
        mp_load_method_maybe(match, MP_QSTR_groups, groups_dest);
        
        if (groups_dest[0] != MP_OBJ_NULL) {
            mp_obj_t groups_result = mp_call_method_n_kw(0, 0, groups_dest);
            if (groups_result != mp_const_empty_tuple) {
                mp_obj_tuple_t *groups = MP_OBJ_TO_PTR(groups_result);
                if (groups->len == 1) {
                    mp_obj_list_append(results, groups->items[0]);
                } else if (groups->len > 1) {
                    mp_obj_list_append(results, groups_result);
                } else {
                    mp_obj_list_append(results, matched);
                }
            } else {
                mp_obj_list_append(results, matched);
            }
        } else {
            mp_obj_list_append(results, matched);
        }
        
        // Get end position via end(0)
        mp_obj_t end_method[2];
        mp_load_method(match, MP_QSTR_end, end_method);
        mp_obj_t end_args[3] = {end_method[0], end_method[1], MP_OBJ_NEW_SMALL_INT(0)};
        mp_obj_t end_obj = mp_call_method_n_kw(1, 0, end_args);
        mp_int_t end_pos = mp_obj_get_int(end_obj);
        
        // Advance position (at least 1 to avoid infinite loop)
        pos += (end_pos > 0) ? (size_t)end_pos : 1;
    }
    
    return results;
}
static MP_DEFINE_CONST_FUN_OBJ_2(re_ext_findall_obj, re_ext_findall);

// re.split(pattern, string, maxsplit=0) -> list
// Split string by occurrences of pattern
static mp_obj_t re_ext_split(size_t n_args, const mp_obj_t *args) {
    mp_obj_t pattern_in = args[0];
    mp_obj_t string_in = args[1];
    mp_int_t maxsplit = 0;
    if (n_args > 2) {
        maxsplit = mp_obj_get_int(args[2]);
    }
    
    // Get re module and compile function
    mp_obj_t re_mod = mp_import_name(MP_QSTR_re, mp_const_none, MP_OBJ_NEW_SMALL_INT(0));
    mp_obj_t compile_func = mp_load_attr(re_mod, MP_QSTR_compile);
    
    // Always compile the pattern - strings have a split method too which confuses detection
    // If it's already compiled, compile() just returns it (actually it will fail, so check type)
    mp_obj_t compiled;
    if (mp_obj_is_str(pattern_in)) {
        compiled = mp_call_function_1(compile_func, pattern_in);
    } else {
        compiled = pattern_in;  // Assume already compiled
    }
    
    // Get split method from compiled pattern
    mp_obj_t split_method[2];
    mp_load_method(compiled, MP_QSTR_split, split_method);
    
    // Call compiled.split(string, maxsplit)
    if (maxsplit > 0) {
        mp_obj_t call_args[4] = {split_method[0], split_method[1], string_in, MP_OBJ_NEW_SMALL_INT(maxsplit)};
        return mp_call_method_n_kw(2, 0, call_args);
    } else {
        mp_obj_t call_args[3] = {split_method[0], split_method[1], string_in};
        return mp_call_method_n_kw(1, 0, call_args);
    }
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(re_ext_split_obj, 2, 3, re_ext_split);

// Delegation handler for re module attribute lookup
// Note: not static because it's referenced by the generated module delegation code
void re_ext_attr(mp_obj_t self_in, qstr attr, mp_obj_t *dest) {
    (void)self_in;
    if (attr == MP_QSTR_findall) {
        dest[0] = MP_OBJ_FROM_PTR(&re_ext_findall_obj);
    } else if (attr == MP_QSTR_split) {
        dest[0] = MP_OBJ_FROM_PTR(&re_ext_split_obj);
    }
    // If we don't handle it, dest stays NULL and built-in re handles it
}

// Declare external reference to mp_module_re
extern const mp_obj_module_t mp_module_re;

// Register as delegate/extension to the re module
MP_REGISTER_MODULE_DELEGATION(mp_module_re, re_ext_attr);
