/*
 * modtextwrap - Native text wrapping module for microcharm
 * 
 * This module bridges Zig's textwrap implementation to MicroPython.
 * 
 * Usage in Python:
 *   import textwrap
 *   textwrap.wrap("long text", width=40)
 *   textwrap.dedent("    indented")
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// External Zig functions
extern int textwrap_wrap(const char *text, size_t text_len, size_t width,
                         void (*callback)(const char *, size_t, void *),
                         void *user_data);
extern int textwrap_common_indent(const char *text, size_t text_len,
                                  char *output, size_t output_len);
extern int textwrap_dedent(const char *text, size_t text_len,
                           char *output, size_t output_len);
extern int textwrap_indent(const char *text, size_t text_len,
                           const char *prefix, size_t prefix_len,
                           char *output, size_t output_len);
extern int textwrap_shorten(const char *text, size_t text_len, size_t width,
                            const char *placeholder, size_t placeholder_len,
                            char *output, size_t output_len);

// Callback context for wrap
typedef struct {
    mp_obj_t list;
} wrap_context_t;

static void wrap_callback(const char *line, size_t line_len, void *user_data) {
    wrap_context_t *ctx = (wrap_context_t *)user_data;
    mp_obj_t line_obj = mp_obj_new_str(line, line_len);
    mp_obj_list_append(ctx->list, line_obj);
}

// ============================================================================
// textwrap functions
// ============================================================================

// textwrap.wrap(text, width=70) -> list of lines
MPY_FUNC_VAR(textwrap, wrap, 1, 2) {
    size_t text_len;
    const char *text = mpy_str_len(args[0], &text_len);
    
    int width = 70;  // Default
    if (n_args >= 2) {
        width = mpy_int(args[1]);
    }
    
    wrap_context_t ctx;
    ctx.list = mp_obj_new_list(0, NULL);
    
    textwrap_wrap(text, text_len, width, wrap_callback, &ctx);
    
    return ctx.list;
}
MPY_FUNC_OBJ_VAR(textwrap, wrap, 1, 2);

// textwrap.fill(text, width=70) -> str
MPY_FUNC_VAR(textwrap, fill, 1, 2) {
    size_t text_len;
    const char *text = mpy_str_len(args[0], &text_len);
    
    int width = 70;  // Default
    if (n_args >= 2) {
        width = mpy_int(args[1]);
    }
    
    // Get wrapped lines
    wrap_context_t ctx;
    ctx.list = mp_obj_new_list(0, NULL);
    textwrap_wrap(text, text_len, width, wrap_callback, &ctx);
    
    // Join with newlines
    size_t list_len;
    mp_obj_t *items;
    mp_obj_get_array(ctx.list, &list_len, &items);
    
    if (list_len == 0) {
        return mpy_new_str("");
    }
    
    // Calculate total length
    size_t total_len = 0;
    for (size_t i = 0; i < list_len; i++) {
        size_t line_len;
        mpy_str_len(items[i], &line_len);
        total_len += line_len;
        if (i < list_len - 1) total_len++;  // newline
    }
    
    // Build result
    char *result = m_malloc(total_len + 1);
    size_t pos = 0;
    for (size_t i = 0; i < list_len; i++) {
        size_t line_len;
        const char *line = mpy_str_len(items[i], &line_len);
        memcpy(result + pos, line, line_len);
        pos += line_len;
        if (i < list_len - 1) {
            result[pos++] = '\n';
        }
    }
    result[pos] = '\0';
    
    mp_obj_t ret = mpy_new_str_len(result, total_len);
    mpy_free(result, total_len + 1);
    return ret;
}
MPY_FUNC_OBJ_VAR(textwrap, fill, 1, 2);

// textwrap.dedent(text) -> str
MPY_FUNC_1(textwrap, dedent) {
    size_t text_len;
    const char *text = mpy_str_len(arg0, &text_len);
    
    // Allocate output buffer (same size as input should be enough)
    size_t output_len = text_len + 1;
    char *output = mpy_alloc(output_len);
    
    int result_len = textwrap_dedent(text, text_len, output, output_len);
    if (result_len < 0) {
        mpy_free(output, output_len);
        return arg0;  // Return original on error
    }
    
    mp_obj_t ret = mpy_new_str_len(output, result_len);
    mpy_free(output, output_len);
    return ret;
}
MPY_FUNC_OBJ_1(textwrap, dedent);

// textwrap.indent(text, prefix) -> str
MPY_FUNC_2(textwrap, indent) {
    size_t text_len, prefix_len;
    const char *text = mpy_str_len(arg0, &text_len);
    const char *prefix = mpy_str_len(arg1, &prefix_len);
    
    // Count lines to estimate output size
    size_t line_count = 1;
    for (size_t i = 0; i < text_len; i++) {
        if (text[i] == '\n') line_count++;
    }
    
    // Allocate output buffer
    size_t output_len = text_len + (line_count * prefix_len) + 1;
    char *output = mpy_alloc(output_len);
    
    int result_len = textwrap_indent(text, text_len, prefix, prefix_len, output, output_len);
    if (result_len < 0) {
        mpy_free(output, output_len);
        return arg0;  // Return original on error
    }
    
    mp_obj_t ret = mpy_new_str_len(output, result_len);
    mpy_free(output, output_len);
    return ret;
}
MPY_FUNC_OBJ_2(textwrap, indent);

// textwrap.shorten(text, width, placeholder="...") -> str
MPY_FUNC_VAR(textwrap, shorten, 2, 3) {
    size_t text_len;
    const char *text = mpy_str_len(args[0], &text_len);
    int width = mpy_int(args[1]);
    
    const char *placeholder = "...";
    size_t placeholder_len = 3;
    if (n_args >= 3) {
        placeholder = mpy_str_len(args[2], &placeholder_len);
    }
    
    // Allocate output buffer
    size_t output_len = width + 1;
    char *output = mpy_alloc(output_len);
    
    int result_len = textwrap_shorten(text, text_len, width, 
                                       placeholder, placeholder_len,
                                       output, output_len);
    
    mp_obj_t ret = mpy_new_str_len(output, result_len);
    mpy_free(output, output_len);
    return ret;
}
MPY_FUNC_OBJ_VAR(textwrap, shorten, 2, 3);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(textwrap)
    MPY_MODULE_FUNC(textwrap, wrap)
    MPY_MODULE_FUNC(textwrap, fill)
    MPY_MODULE_FUNC(textwrap, dedent)
    MPY_MODULE_FUNC(textwrap, indent)
    MPY_MODULE_FUNC(textwrap, shorten)
MPY_MODULE_END(textwrap)
