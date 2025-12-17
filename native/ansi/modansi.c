/*
 * modansi - Native ANSI escape code module for ucharm
 * 
 * C bridge that wraps Zig core (ansi.zig) for MicroPython.
 * 
 * Usage in Python:
 *   import ansi
 *   ansi.fg("red")      # Named color
 *   ansi.fg("#ff5500")  # Hex color
 *   ansi.fg(196)        # 256-color index
 *   ansi.rgb(255, 100, 0)  # 24-bit RGB
 */

#include "../bridge/mpy_bridge.h"

// ============================================================================
// Zig Function Declarations
// ============================================================================

// Color types from Zig
typedef struct {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    bool valid;
} Color;

typedef struct {
    int16_t index;  // -1 if not found
    bool is_bright;
} ColorIndex;

// Zig functions
ZIG_EXTERN ColorIndex ansi_color_name_to_index(const char *name);
ZIG_EXTERN Color ansi_parse_hex_color(const char *hex);
ZIG_EXTERN bool ansi_is_hex_color(const char *str);
ZIG_EXTERN size_t ansi_fg_256(uint8_t index, char *buf);
ZIG_EXTERN size_t ansi_bg_256(uint8_t index, char *buf);
ZIG_EXTERN size_t ansi_fg_rgb(uint8_t r, uint8_t g, uint8_t b, char *buf);
ZIG_EXTERN size_t ansi_bg_rgb(uint8_t r, uint8_t g, uint8_t b, char *buf);
ZIG_EXTERN size_t ansi_fg_standard(uint8_t index, char *buf);
ZIG_EXTERN size_t ansi_bg_standard(uint8_t index, char *buf);

// ============================================================================
// Constants
// ============================================================================

#define ANSI_RESET "\x1b[0m"

// ============================================================================
// MicroPython Wrappers
// ============================================================================

// ansi.reset() -> str
MPY_FUNC_0(ansi, reset) {
    return mpy_new_str(ANSI_RESET);
}
MPY_FUNC_OBJ_0(ansi, reset);

// ansi.fg(color) -> str
// color can be: name ("red"), hex ("#ff5500"), or int (0-255)
MPY_FUNC_1(ansi, fg) {
    char buf[32];
    size_t len;
    
    if (mp_obj_is_int(arg0)) {
        int idx = mpy_int(arg0);
        if (idx >= 0 && idx < 16) {
            len = ansi_fg_standard((uint8_t)idx, buf);
        } else if (idx >= 0 && idx <= 255) {
            len = ansi_fg_256((uint8_t)idx, buf);
        } else {
            return mpy_new_str("");
        }
        return mpy_new_str_len(buf, len);
    }
    
    const char *str = mpy_str(arg0);
    
    if (ansi_is_hex_color(str)) {
        Color color = ansi_parse_hex_color(str);
        if (color.valid) {
            len = ansi_fg_rgb(color.r, color.g, color.b, buf);
            return mpy_new_str_len(buf, len);
        }
    } else {
        ColorIndex ci = ansi_color_name_to_index(str);
        if (ci.index >= 0) {
            len = ansi_fg_standard((uint8_t)ci.index, buf);
            return mpy_new_str_len(buf, len);
        }
    }
    
    return mpy_new_str("");
}
MPY_FUNC_OBJ_1(ansi, fg);

// ansi.bg(color) -> str
MPY_FUNC_1(ansi, bg) {
    char buf[32];
    size_t len;
    
    if (mp_obj_is_int(arg0)) {
        int idx = mpy_int(arg0);
        if (idx >= 0 && idx < 16) {
            len = ansi_bg_standard((uint8_t)idx, buf);
        } else if (idx >= 0 && idx <= 255) {
            len = ansi_bg_256((uint8_t)idx, buf);
        } else {
            return mpy_new_str("");
        }
        return mpy_new_str_len(buf, len);
    }
    
    const char *str = mpy_str(arg0);
    
    if (ansi_is_hex_color(str)) {
        Color color = ansi_parse_hex_color(str);
        if (color.valid) {
            len = ansi_bg_rgb(color.r, color.g, color.b, buf);
            return mpy_new_str_len(buf, len);
        }
    } else {
        ColorIndex ci = ansi_color_name_to_index(str);
        if (ci.index >= 0) {
            len = ansi_bg_standard((uint8_t)ci.index, buf);
            return mpy_new_str_len(buf, len);
        }
    }
    
    return mpy_new_str("");
}
MPY_FUNC_OBJ_1(ansi, bg);

// ansi.rgb(r, g, b, bg=False) -> str
MPY_FUNC_VAR(ansi, rgb, 3, 4) {
    uint8_t r = (uint8_t)mpy_int(args[0]);
    uint8_t g = (uint8_t)mpy_int(args[1]);
    uint8_t b = (uint8_t)mpy_int(args[2]);
    bool is_bg = n_args > 3 && mpy_to_bool(args[3]);
    
    char buf[32];
    size_t len;
    
    if (is_bg) {
        len = ansi_bg_rgb(r, g, b, buf);
    } else {
        len = ansi_fg_rgb(r, g, b, buf);
    }
    
    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_VAR(ansi, rgb, 3, 4);

// ============================================================================
// Style Functions
// ============================================================================

MPY_FUNC_0(ansi, bold) { return mpy_new_str("\x1b[1m"); }
MPY_FUNC_OBJ_0(ansi, bold);

MPY_FUNC_0(ansi, dim) { return mpy_new_str("\x1b[2m"); }
MPY_FUNC_OBJ_0(ansi, dim);

MPY_FUNC_0(ansi, italic) { return mpy_new_str("\x1b[3m"); }
MPY_FUNC_OBJ_0(ansi, italic);

MPY_FUNC_0(ansi, underline) { return mpy_new_str("\x1b[4m"); }
MPY_FUNC_OBJ_0(ansi, underline);

MPY_FUNC_0(ansi, blink) { return mpy_new_str("\x1b[5m"); }
MPY_FUNC_OBJ_0(ansi, blink);

MPY_FUNC_0(ansi, reverse) { return mpy_new_str("\x1b[7m"); }
MPY_FUNC_OBJ_0(ansi, reverse);

MPY_FUNC_0(ansi, hidden) { return mpy_new_str("\x1b[8m"); }
MPY_FUNC_OBJ_0(ansi, hidden);

MPY_FUNC_0(ansi, strikethrough) { return mpy_new_str("\x1b[9m"); }
MPY_FUNC_OBJ_0(ansi, strikethrough);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(ansi)
    MPY_MODULE_FUNC(ansi, reset)
    MPY_MODULE_FUNC(ansi, fg)
    MPY_MODULE_FUNC(ansi, bg)
    MPY_MODULE_FUNC(ansi, rgb)
    MPY_MODULE_FUNC(ansi, bold)
    MPY_MODULE_FUNC(ansi, dim)
    MPY_MODULE_FUNC(ansi, italic)
    MPY_MODULE_FUNC(ansi, underline)
    MPY_MODULE_FUNC(ansi, blink)
    MPY_MODULE_FUNC(ansi, reverse)
    MPY_MODULE_FUNC(ansi, hidden)
    MPY_MODULE_FUNC(ansi, strikethrough)
MPY_MODULE_END(ansi)
