/*
 * modcharm.c - Native UI components module for ucharm
 *
 * Provides UI display components:
 * - box(content, title, border, border_color, padding)
 * - rule(title, char, color, width)
 * - success/error/warning/info(message)
 * - progress(current, total, label, width)
 * - style(text, fg, bg, bold, dim, italic, underline, strikethrough)
 * - visible_len(text)
 *
 * Usage in Python:
 *   import charm
 *   charm.box("Hello!", title="Info", border="rounded")
 *   charm.success("Done!")
 *   charm.progress(50, 100, label="Loading")
 */

#include "../bridge/mpy_bridge.h"
#include <stdio.h>
#include <string.h>

// ============================================================================
// Zig Function Declarations
// ============================================================================

ZIG_EXTERN size_t charm_visible_len(const char *s);
ZIG_EXTERN const char *charm_box_char(uint8_t style, uint8_t position);
ZIG_EXTERN const char *charm_symbol_success(void);
ZIG_EXTERN const char *charm_symbol_error(void);
ZIG_EXTERN const char *charm_symbol_warning(void);
ZIG_EXTERN const char *charm_symbol_info(void);
ZIG_EXTERN const char *charm_symbol_bullet(void);
ZIG_EXTERN const char *charm_spinner_frame(uint32_t index);
ZIG_EXTERN uint32_t charm_spinner_frame_count(void);
ZIG_EXTERN size_t charm_progress_bar(uint32_t current, uint32_t total, uint32_t width, char *buf);
ZIG_EXTERN size_t charm_percent_str(uint32_t current, uint32_t total, char *buf);
ZIG_EXTERN int32_t charm_color_code(const char *name);
ZIG_EXTERN bool charm_parse_hex(const char *hex, uint8_t *r, uint8_t *g, uint8_t *b);
ZIG_EXTERN size_t charm_repeat(const char *pattern, uint32_t count, char *buf);
ZIG_EXTERN size_t charm_pad(const char *text, uint32_t width, uint8_t align_mode, char *buf);

// ============================================================================
// Helper: Build ANSI style string
// ============================================================================

static size_t build_style_code(char *buf, size_t buf_size,
                               const char *fg, const char *bg,
                               bool bold, bool dim, bool italic,
                               bool underline, bool strikethrough) {
    size_t pos = 0;
    bool has_codes = false;
    
    buf[pos++] = '\x1b';
    buf[pos++] = '[';
    
    if (bold) {
        buf[pos++] = '1';
        has_codes = true;
    }
    if (dim) {
        if (has_codes) buf[pos++] = ';';
        buf[pos++] = '2';
        has_codes = true;
    }
    if (italic) {
        if (has_codes) buf[pos++] = ';';
        buf[pos++] = '3';
        has_codes = true;
    }
    if (underline) {
        if (has_codes) buf[pos++] = ';';
        buf[pos++] = '4';
        has_codes = true;
    }
    if (strikethrough) {
        if (has_codes) buf[pos++] = ';';
        buf[pos++] = '9';
        has_codes = true;
    }
    
    // Foreground color
    if (fg && fg[0]) {
        int32_t code = charm_color_code(fg);
        if (code >= 0) {
            if (has_codes) buf[pos++] = ';';
            pos += snprintf(buf + pos, buf_size - pos, "%d", code);
            has_codes = true;
        } else if (fg[0] == '#') {
            uint8_t r, g, b;
            if (charm_parse_hex(fg, &r, &g, &b)) {
                if (has_codes) buf[pos++] = ';';
                pos += snprintf(buf + pos, buf_size - pos, "38;2;%d;%d;%d", r, g, b);
                has_codes = true;
            }
        }
    }
    
    // Background color
    if (bg && bg[0]) {
        int32_t code = charm_color_code(bg);
        if (code >= 0) {
            if (has_codes) buf[pos++] = ';';
            pos += snprintf(buf + pos, buf_size - pos, "%d", code + 10);
            has_codes = true;
        } else if (bg[0] == '#') {
            uint8_t r, g, b;
            if (charm_parse_hex(bg, &r, &g, &b)) {
                if (has_codes) buf[pos++] = ';';
                pos += snprintf(buf + pos, buf_size - pos, "48;2;%d;%d;%d", r, g, b);
                has_codes = true;
            }
        }
    }
    
    if (!has_codes) {
        return 0;
    }
    
    buf[pos++] = 'm';
    buf[pos] = '\0';
    return pos;
}

// ============================================================================
// charm.visible_len(text) -> int
// Calculate visible length of text, ignoring ANSI escape sequences.
// ============================================================================

MPY_FUNC_1(charm, visible_len) {
    const char *text = mpy_str(arg0);
    return mpy_new_int(charm_visible_len(text));
}
MPY_FUNC_OBJ_1(charm, visible_len);

// ============================================================================
// charm.style(text, fg, bg, bold, dim, italic, underline, strikethrough) -> str
// Apply ANSI styling to text and return the styled string.
// ============================================================================

// Using keyword arguments pattern from logging module
static mp_obj_t charm_style_func(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_text, MP_ARG_REQUIRED | MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_fg, MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_bg, MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_bold, MP_ARG_BOOL, {.u_bool = false} },
        { MP_QSTR_dim, MP_ARG_BOOL, {.u_bool = false} },
        { MP_QSTR_italic, MP_ARG_BOOL, {.u_bool = false} },
        { MP_QSTR_underline, MP_ARG_BOOL, {.u_bool = false} },
        { MP_QSTR_strikethrough, MP_ARG_BOOL, {.u_bool = false} },
    };
    
    mp_arg_val_t args[8];
    mp_arg_parse_all(n_args, pos_args, kw_args, 8, allowed_args, args);
    
    const char *text = mpy_str(args[0].u_obj);
    const char *fg = (args[1].u_obj != mp_const_none) ? mpy_str(args[1].u_obj) : NULL;
    const char *bg = (args[2].u_obj != mp_const_none) ? mpy_str(args[2].u_obj) : NULL;
    bool bold = args[3].u_bool;
    bool dim = args[4].u_bool;
    bool italic = args[5].u_bool;
    bool underline = args[6].u_bool;
    bool strikethrough = args[7].u_bool;
    
    // Build style code
    char style_buf[64];
    size_t style_len = build_style_code(style_buf, sizeof(style_buf),
                                         fg, bg, bold, dim, italic,
                                         underline, strikethrough);
    
    if (style_len == 0) {
        // No styling, return text as-is
        return args[0].u_obj;
    }
    
    // Build result: style + text + reset
    size_t text_len = strlen(text);
    size_t result_len = style_len + text_len + 4; // +4 for \x1b[0m
    char *result = mpy_alloc(result_len + 1);
    
    memcpy(result, style_buf, style_len);
    memcpy(result + style_len, text, text_len);
    memcpy(result + style_len + text_len, "\x1b[0m", 4);
    result[result_len] = '\0';
    
    mp_obj_t ret = mpy_new_str_len(result, result_len);
    mpy_free(result, result_len + 1);
    return ret;
}
MP_DEFINE_CONST_FUN_OBJ_KW(charm_style_obj, 1, charm_style_func);

// ============================================================================
// charm.box(content, title, border, border_color, padding) -> None
// Draw a box around content with optional title and styling.
// ============================================================================

// Helper to find max visible length across lines
static size_t max_line_visible_len(const char *content) {
    size_t max_len = 0;
    const char *line_start = content;
    const char *p = content;
    
    while (*p) {
        if (*p == '\n') {
            // Calculate visible length of this line
            size_t line_len = p - line_start;
            char line_buf[1024];
            if (line_len < sizeof(line_buf)) {
                memcpy(line_buf, line_start, line_len);
                line_buf[line_len] = '\0';
                size_t vis_len = charm_visible_len(line_buf);
                if (vis_len > max_len) max_len = vis_len;
            }
            line_start = p + 1;
        }
        p++;
    }
    
    // Handle last line (or only line if no newlines)
    if (line_start < p) {
        size_t vis_len = charm_visible_len(line_start);
        if (vis_len > max_len) max_len = vis_len;
    }
    
    return max_len;
}

static mp_obj_t charm_box_func(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_content, MP_ARG_REQUIRED | MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_title, MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_border, MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_border_color, MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_padding, MP_ARG_INT, {.u_int = 1} },
    };
    
    mp_arg_val_t args[5];
    mp_arg_parse_all(n_args, pos_args, kw_args, 5, allowed_args, args);
    
    const char *content = mpy_str(args[0].u_obj);
    const char *title = (args[1].u_obj != mp_const_none) ? mpy_str(args[1].u_obj) : NULL;
    const char *border_str = (args[2].u_obj != mp_const_none) ? mpy_str(args[2].u_obj) : "rounded";
    const char *border_color = (args[3].u_obj != mp_const_none) ? mpy_str(args[3].u_obj) : NULL;
    int padding = args[4].u_int;
    
    // Determine border style
    uint8_t border_style = 0;
    if (strcmp(border_str, "square") == 0) border_style = 1;
    else if (strcmp(border_str, "double") == 0) border_style = 2;
    else if (strcmp(border_str, "heavy") == 0) border_style = 3;
    else if (strcmp(border_str, "none") == 0) border_style = 4;
    
    // Get box characters
    const char *tl = charm_box_char(border_style, 0);
    const char *tr = charm_box_char(border_style, 1);
    const char *bl = charm_box_char(border_style, 2);
    const char *br = charm_box_char(border_style, 3);
    const char *h = charm_box_char(border_style, 4);
    const char *v = charm_box_char(border_style, 5);
    
    // Calculate dimensions - find max line width
    size_t max_content_width = max_line_visible_len(content);
    size_t title_len = title ? strlen(title) : 0;
    size_t title_vis = title ? (title_len + 4) : 0; // " title "
    size_t content_width = (max_content_width > title_vis - 2) ? max_content_width : (title_vis > 2 ? title_vis - 2 : 0);
    size_t inner_width = content_width + padding * 2;
    
    // Build color codes if needed
    char color_start[64] = "";
    char color_end[8] = "";
    if (border_color) {
        build_style_code(color_start, sizeof(color_start), border_color, NULL, false, false, false, false, false);
        strcpy(color_end, "\x1b[0m");
    }
    
    // Print top border
    char repeat_buf[256];
    if (title) {
        printf("%s%s%s", color_start, tl, h);
        printf("%s", color_end);
        printf("\x1b[1m %s \x1b[0m", title);
        size_t remaining = inner_width - title_len - 3;
        charm_repeat(h, remaining, repeat_buf);
        printf("%s%s%s%s\n", color_start, repeat_buf, tr, color_end);
    } else {
        charm_repeat(h, inner_width, repeat_buf);
        printf("%s%s%s%s%s\n", color_start, tl, repeat_buf, tr, color_end);
    }
    
    // Print content lines
    char pad_spaces[64];
    charm_repeat(" ", padding, pad_spaces);
    
    const char *line_start = content;
    const char *p = content;
    
    while (*p) {
        if (*p == '\n') {
            // Print this line
            size_t line_len = p - line_start;
            char line_buf[1024];
            if (line_len < sizeof(line_buf)) {
                memcpy(line_buf, line_start, line_len);
                line_buf[line_len] = '\0';
                
                char pad_buf[1024];
                charm_pad(line_buf, content_width, 0, pad_buf);
                
                printf("%s%s%s%s%s%s%s%s%s\n", 
                       color_start, v, color_end,
                       pad_spaces, pad_buf, pad_spaces,
                       color_start, v, color_end);
            }
            line_start = p + 1;
        }
        p++;
    }
    
    // Handle last line (or only line if no newlines)
    if (line_start <= p) {
        char pad_buf[1024];
        charm_pad(line_start, content_width, 0, pad_buf);
        
        printf("%s%s%s%s%s%s%s%s%s\n", 
               color_start, v, color_end,
               pad_spaces, pad_buf, pad_spaces,
               color_start, v, color_end);
    }
    
    // Print bottom border
    charm_repeat(h, inner_width, repeat_buf);
    printf("%s%s%s%s%s\n", color_start, bl, repeat_buf, br, color_end);
    
    return mpy_none();
}
MP_DEFINE_CONST_FUN_OBJ_KW(charm_box_obj, 1, charm_box_func);

// ============================================================================
// charm.rule(title=None, char='─', color=None, width=None) -> None
// Print a horizontal rule with optional centered title.
// ============================================================================

static mp_obj_t charm_rule_func(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_title, MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_char, MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_color, MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_width, MP_ARG_INT, {.u_int = 80} },
    };
    
    mp_arg_val_t args[4];
    mp_arg_parse_all(n_args, pos_args, kw_args, 4, allowed_args, args);
    
    const char *title = (args[0].u_obj != mp_const_none) ? mpy_str(args[0].u_obj) : NULL;
    const char *ch = (args[1].u_obj != mp_const_none) ? mpy_str(args[1].u_obj) : "─";
    const char *color = (args[2].u_obj != mp_const_none) ? mpy_str(args[2].u_obj) : NULL;
    int width = args[3].u_int;
    
    char color_start[64] = "";
    char color_end[8] = "";
    if (color) {
        build_style_code(color_start, sizeof(color_start), color, NULL, false, false, false, false, false);
        strcpy(color_end, "\x1b[0m");
    }
    
    char repeat_buf[512];
    
    if (title) {
        size_t title_len = strlen(title);
        int side = (width - title_len - 2) / 2;
        if (side < 0) side = 0;
        
        charm_repeat(ch, side, repeat_buf);
        printf("%s%s%s %s ", color_start, repeat_buf, color_end, title);
        
        int remaining = width - side - title_len - 2;
        if (remaining < 0) remaining = 0;
        charm_repeat(ch, remaining, repeat_buf);
        printf("%s%s%s\n", color_start, repeat_buf, color_end);
    } else {
        charm_repeat(ch, width, repeat_buf);
        printf("%s%s%s\n", color_start, repeat_buf, color_end);
    }
    
    return mpy_none();
}
MP_DEFINE_CONST_FUN_OBJ_KW(charm_rule_obj, 0, charm_rule_func);

// ============================================================================
// charm.success(message) -> None
// Print a success message with a green checkmark symbol.
// ============================================================================

MPY_FUNC_1(charm, success) {
    const char *msg = mpy_str(arg0);
    printf("\x1b[1;32m%s \x1b[0m%s\n", charm_symbol_success(), msg);
    return mpy_none();
}
MPY_FUNC_OBJ_1(charm, success);

// ============================================================================
// charm.error(message) -> None
// Print an error message with a red cross symbol.
// ============================================================================

MPY_FUNC_1(charm, error) {
    const char *msg = mpy_str(arg0);
    printf("\x1b[1;31m%s \x1b[0m%s\n", charm_symbol_error(), msg);
    return mpy_none();
}
MPY_FUNC_OBJ_1(charm, error);

// ============================================================================
// charm.warning(message) -> None
// Print a warning message with a yellow warning symbol.
// ============================================================================

MPY_FUNC_1(charm, warning) {
    const char *msg = mpy_str(arg0);
    printf("\x1b[1;33m%s \x1b[0m%s\n", charm_symbol_warning(), msg);
    return mpy_none();
}
MPY_FUNC_OBJ_1(charm, warning);

// ============================================================================
// charm.info(message) -> None
// Print an info message with a blue info symbol.
// ============================================================================

MPY_FUNC_1(charm, info) {
    const char *msg = mpy_str(arg0);
    printf("\x1b[1;34m%s \x1b[0m%s\n", charm_symbol_info(), msg);
    return mpy_none();
}
MPY_FUNC_OBJ_1(charm, info);

// ============================================================================
// charm.progress(current, total, label=None, width=40, color=None) -> None
// Display an animated progress bar with percentage.
// ============================================================================

static mp_obj_t charm_progress_func(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_current, MP_ARG_REQUIRED | MP_ARG_INT, {.u_int = 0} },
        { MP_QSTR_total, MP_ARG_REQUIRED | MP_ARG_INT, {.u_int = 0} },
        { MP_QSTR_label, MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_width, MP_ARG_INT, {.u_int = 40} },
        { MP_QSTR_color, MP_ARG_OBJ, {.u_obj = mp_const_none} },
    };
    
    mp_arg_val_t args[5];
    mp_arg_parse_all(n_args, pos_args, kw_args, 5, allowed_args, args);
    
    uint32_t current = args[0].u_int;
    uint32_t total = args[1].u_int;
    const char *label = (args[2].u_obj != mp_const_none) ? mpy_str(args[2].u_obj) : NULL;
    uint32_t width = args[3].u_int;
    const char *color = (args[4].u_obj != mp_const_none) ? mpy_str(args[4].u_obj) : NULL;
    
    char bar_buf[256];
    char percent_buf[16];
    
    charm_progress_bar(current, total, width, bar_buf);
    charm_percent_str(current, total, percent_buf);
    
    // Build color codes if needed
    char color_start[64] = "";
    char color_end[8] = "";
    if (color) {
        build_style_code(color_start, sizeof(color_start), color, NULL, false, false, false, false, false);
        strcpy(color_end, "\x1b[0m");
    }
    
    // Use \r to overwrite line (for animation), no newline
    if (label) {
        printf("\r%s%s%s%s %s", label, color_start, bar_buf, color_end, percent_buf);
    } else {
        printf("\r%s%s%s %s", color_start, bar_buf, color_end, percent_buf);
    }
    fflush(stdout);
    
    return mpy_none();
}
MP_DEFINE_CONST_FUN_OBJ_KW(charm_progress_obj, 2, charm_progress_func);

// ============================================================================
// charm.spinner_frame(index) -> str
// Get a spinner animation frame by index (cycles through frames).
// ============================================================================

MPY_FUNC_1(charm, spinner_frame) {
    uint32_t index = mpy_int(arg0);
    return mpy_new_str(charm_spinner_frame(index));
}
MPY_FUNC_OBJ_1(charm, spinner_frame);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(charm)
    MPY_MODULE_FUNC(charm, visible_len)
    { MP_ROM_QSTR(MP_QSTR_style), MP_ROM_PTR(&charm_style_obj) },
    { MP_ROM_QSTR(MP_QSTR_box), MP_ROM_PTR(&charm_box_obj) },
    { MP_ROM_QSTR(MP_QSTR_rule), MP_ROM_PTR(&charm_rule_obj) },
    MPY_MODULE_FUNC(charm, success)
    MPY_MODULE_FUNC(charm, error)
    MPY_MODULE_FUNC(charm, warning)
    MPY_MODULE_FUNC(charm, info)
    { MP_ROM_QSTR(MP_QSTR_progress), MP_ROM_PTR(&charm_progress_obj) },
    MPY_MODULE_FUNC(charm, spinner_frame)
    
    // Constants
    MPY_MODULE_INT(BORDER_ROUNDED, 0)
    MPY_MODULE_INT(BORDER_SQUARE, 1)
    MPY_MODULE_INT(BORDER_DOUBLE, 2)
    MPY_MODULE_INT(BORDER_HEAVY, 3)
    MPY_MODULE_INT(BORDER_NONE, 4)
    MPY_MODULE_INT(ALIGN_LEFT, 0)
    MPY_MODULE_INT(ALIGN_RIGHT, 1)
    MPY_MODULE_INT(ALIGN_CENTER, 2)
MPY_MODULE_END(charm)
