/*
 * modansi - Native ANSI escape code module for microcharm
 * 
 * Provides fast ANSI code generation:
 *   - ansi.fg(color) -> str (foreground color code)
 *   - ansi.bg(color) -> str (background color code)
 *   - ansi.rgb(r, g, b, bg=False) -> str (24-bit color)
 *   - ansi.style(...) -> str (styled text with auto-reset)
 *   - ansi.bold() / dim() / italic() / underline() / strikethrough()
 *   - ansi.reset() -> str
 */

#include "py/runtime.h"
#include "py/obj.h"

#include <string.h>
#include <stdio.h>

// ANSI escape codes
#define ESC "\x1b["
#define RESET "\x1b[0m"

// Standard colors (foreground codes)
static const char *fg_codes[] = {
    "30", "31", "32", "33", "34", "35", "36", "37",  // standard
    "90", "91", "92", "93", "94", "95", "96", "97",  // bright
};

// Standard colors (background codes)
static const char *bg_codes[] = {
    "40", "41", "42", "43", "44", "45", "46", "47",  // standard
    "100", "101", "102", "103", "104", "105", "106", "107",  // bright
};

// Color name lookup (returns -1 if not found)
static int color_name_to_index(const char *name, size_t len) {
    if (len == 5 && memcmp(name, "black", 5) == 0) return 0;
    if (len == 3 && memcmp(name, "red", 3) == 0) return 1;
    if (len == 5 && memcmp(name, "green", 5) == 0) return 2;
    if (len == 6 && memcmp(name, "yellow", 6) == 0) return 3;
    if (len == 4 && memcmp(name, "blue", 4) == 0) return 4;
    if (len == 7 && memcmp(name, "magenta", 7) == 0) return 5;
    if (len == 4 && memcmp(name, "cyan", 4) == 0) return 6;
    if (len == 5 && memcmp(name, "white", 5) == 0) return 7;
    if (len == 4 && (memcmp(name, "gray", 4) == 0 || memcmp(name, "grey", 4) == 0)) return 8;
    
    // Bright variants
    if (len > 7 && memcmp(name, "bright_", 7) == 0) {
        int base = color_name_to_index(name + 7, len - 7);
        if (base >= 0 && base < 8) return base + 8;
    }
    return -1;
}

// Parse hex color (#RGB or #RRGGBB)
static int parse_hex_color(const char *hex, size_t len, int *r, int *g, int *b) {
    if (len < 1 || hex[0] != '#') return 0;
    hex++; len--;
    
    #define HEX_DIGIT(c) ((c) >= 'a' ? (c) - 'a' + 10 : (c) >= 'A' ? (c) - 'A' + 10 : (c) - '0')
    
    if (len == 3) {
        *r = HEX_DIGIT(hex[0]) * 17;
        *g = HEX_DIGIT(hex[1]) * 17;
        *b = HEX_DIGIT(hex[2]) * 17;
        return 1;
    } else if (len == 6) {
        *r = HEX_DIGIT(hex[0]) * 16 + HEX_DIGIT(hex[1]);
        *g = HEX_DIGIT(hex[2]) * 16 + HEX_DIGIT(hex[3]);
        *b = HEX_DIGIT(hex[4]) * 16 + HEX_DIGIT(hex[5]);
        return 1;
    }
    return 0;
    #undef HEX_DIGIT
}

// ansi.reset() -> str
static mp_obj_t ansi_reset(void) {
    return mp_obj_new_str(RESET, 4);
}
static MP_DEFINE_CONST_FUN_OBJ_0(ansi_reset_obj, ansi_reset);

// ansi.fg(color) -> str
static mp_obj_t ansi_fg(mp_obj_t color_obj) {
    char buf[32];
    int len;
    
    if (mp_obj_is_int(color_obj)) {
        int idx = mp_obj_get_int(color_obj);
        if (idx >= 0 && idx < 16) {
            len = snprintf(buf, sizeof(buf), ESC "%sm", fg_codes[idx]);
        } else if (idx >= 0 && idx <= 255) {
            len = snprintf(buf, sizeof(buf), ESC "38;5;%dm", idx);
        } else {
            return mp_obj_new_str("", 0);
        }
        return mp_obj_new_str(buf, len);
    }
    
    size_t slen;
    const char *str = mp_obj_str_get_data(color_obj, &slen);
    
    if (slen > 0 && str[0] == '#') {
        int r, g, b;
        if (parse_hex_color(str, slen, &r, &g, &b)) {
            len = snprintf(buf, sizeof(buf), ESC "38;2;%d;%d;%dm", r, g, b);
            return mp_obj_new_str(buf, len);
        }
    } else {
        int idx = color_name_to_index(str, slen);
        if (idx >= 0) {
            len = snprintf(buf, sizeof(buf), ESC "%sm", fg_codes[idx]);
            return mp_obj_new_str(buf, len);
        }
    }
    
    return mp_obj_new_str("", 0);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ansi_fg_obj, ansi_fg);

// ansi.bg(color) -> str
static mp_obj_t ansi_bg(mp_obj_t color_obj) {
    char buf[32];
    int len;
    
    if (mp_obj_is_int(color_obj)) {
        int idx = mp_obj_get_int(color_obj);
        if (idx >= 0 && idx < 16) {
            len = snprintf(buf, sizeof(buf), ESC "%sm", bg_codes[idx]);
        } else if (idx >= 0 && idx <= 255) {
            len = snprintf(buf, sizeof(buf), ESC "48;5;%dm", idx);
        } else {
            return mp_obj_new_str("", 0);
        }
        return mp_obj_new_str(buf, len);
    }
    
    size_t slen;
    const char *str = mp_obj_str_get_data(color_obj, &slen);
    
    if (slen > 0 && str[0] == '#') {
        int r, g, b;
        if (parse_hex_color(str, slen, &r, &g, &b)) {
            len = snprintf(buf, sizeof(buf), ESC "48;2;%d;%d;%dm", r, g, b);
            return mp_obj_new_str(buf, len);
        }
    } else {
        int idx = color_name_to_index(str, slen);
        if (idx >= 0) {
            len = snprintf(buf, sizeof(buf), ESC "%sm", bg_codes[idx]);
            return mp_obj_new_str(buf, len);
        }
    }
    
    return mp_obj_new_str("", 0);
}
static MP_DEFINE_CONST_FUN_OBJ_1(ansi_bg_obj, ansi_bg);

// ansi.rgb(r, g, b, bg=False) -> str
static mp_obj_t ansi_rgb(size_t n_args, const mp_obj_t *args) {
    int r = mp_obj_get_int(args[0]);
    int g = mp_obj_get_int(args[1]);
    int b = mp_obj_get_int(args[2]);
    int is_bg = n_args > 3 && mp_obj_is_true(args[3]);
    
    char buf[32];
    int len;
    if (is_bg) {
        len = snprintf(buf, sizeof(buf), ESC "48;2;%d;%d;%dm", r, g, b);
    } else {
        len = snprintf(buf, sizeof(buf), ESC "38;2;%d;%d;%dm", r, g, b);
    }
    return mp_obj_new_str(buf, len);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(ansi_rgb_obj, 3, 4, ansi_rgb);

// Style functions
static mp_obj_t ansi_bold(void) { return mp_obj_new_str(ESC "1m", 4); }
static MP_DEFINE_CONST_FUN_OBJ_0(ansi_bold_obj, ansi_bold);

static mp_obj_t ansi_dim(void) { return mp_obj_new_str(ESC "2m", 4); }
static MP_DEFINE_CONST_FUN_OBJ_0(ansi_dim_obj, ansi_dim);

static mp_obj_t ansi_italic(void) { return mp_obj_new_str(ESC "3m", 4); }
static MP_DEFINE_CONST_FUN_OBJ_0(ansi_italic_obj, ansi_italic);

static mp_obj_t ansi_underline(void) { return mp_obj_new_str(ESC "4m", 4); }
static MP_DEFINE_CONST_FUN_OBJ_0(ansi_underline_obj, ansi_underline);

static mp_obj_t ansi_blink(void) { return mp_obj_new_str(ESC "5m", 4); }
static MP_DEFINE_CONST_FUN_OBJ_0(ansi_blink_obj, ansi_blink);

static mp_obj_t ansi_reverse(void) { return mp_obj_new_str(ESC "7m", 4); }
static MP_DEFINE_CONST_FUN_OBJ_0(ansi_reverse_obj, ansi_reverse);

static mp_obj_t ansi_hidden(void) { return mp_obj_new_str(ESC "8m", 4); }
static MP_DEFINE_CONST_FUN_OBJ_0(ansi_hidden_obj, ansi_hidden);

static mp_obj_t ansi_strikethrough(void) { return mp_obj_new_str(ESC "9m", 4); }
static MP_DEFINE_CONST_FUN_OBJ_0(ansi_strikethrough_obj, ansi_strikethrough);

// Module globals table
static const mp_rom_map_elem_t ansi_module_globals_table[] = {
    { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR_ansi) },
    { MP_ROM_QSTR(MP_QSTR_reset), MP_ROM_PTR(&ansi_reset_obj) },
    { MP_ROM_QSTR(MP_QSTR_fg), MP_ROM_PTR(&ansi_fg_obj) },
    { MP_ROM_QSTR(MP_QSTR_bg), MP_ROM_PTR(&ansi_bg_obj) },
    { MP_ROM_QSTR(MP_QSTR_rgb), MP_ROM_PTR(&ansi_rgb_obj) },
    { MP_ROM_QSTR(MP_QSTR_bold), MP_ROM_PTR(&ansi_bold_obj) },
    { MP_ROM_QSTR(MP_QSTR_dim), MP_ROM_PTR(&ansi_dim_obj) },
    { MP_ROM_QSTR(MP_QSTR_italic), MP_ROM_PTR(&ansi_italic_obj) },
    { MP_ROM_QSTR(MP_QSTR_underline), MP_ROM_PTR(&ansi_underline_obj) },
    { MP_ROM_QSTR(MP_QSTR_blink), MP_ROM_PTR(&ansi_blink_obj) },
    { MP_ROM_QSTR(MP_QSTR_reverse), MP_ROM_PTR(&ansi_reverse_obj) },
    { MP_ROM_QSTR(MP_QSTR_hidden), MP_ROM_PTR(&ansi_hidden_obj) },
    { MP_ROM_QSTR(MP_QSTR_strikethrough), MP_ROM_PTR(&ansi_strikethrough_obj) },
    // Constants
    { MP_ROM_QSTR(MP_QSTR_RESET), MP_ROM_QSTR(MP_QSTR_) },  // Will need string constant
};
static MP_DEFINE_CONST_DICT(ansi_module_globals, ansi_module_globals_table);

// Module definition
const mp_obj_module_t mp_module_ansi = {
    .base = { &mp_type_module },
    .globals = (mp_obj_dict_t *)&ansi_module_globals,
};

// Register the module
MP_REGISTER_MODULE(MP_QSTR_ansi, mp_module_ansi);
