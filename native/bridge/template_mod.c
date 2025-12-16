/*
 * template_mod.c - Template for MicroPython C bridge
 *
 * Copy this file to your module directory and rename it.
 * Replace "template" with your module name.
 *
 * Example: For a "math" module:
 *   1. Copy this to native/math/modmath.c
 *   2. Replace all "template" with "math"
 *   3. Add extern declarations for your Zig functions
 *   4. Wrap each function with MicroPython API
 */

#include "../bridge/mpy_bridge.h"

// ============================================================================
// Zig Function Declarations
// ============================================================================

// Declare your Zig functions here (implemented in template.zig)
ZIG_EXTERN int64_t template_add(int64_t a, int64_t b);
ZIG_EXTERN bool template_is_positive(int64_t n);
ZIG_EXTERN size_t template_strlen(const char *str);
ZIG_EXTERN bool template_streq(const char *a, const char *b);

// ============================================================================
// MicroPython Wrappers
// ============================================================================

// template.add(a, b) -> int
MPY_FUNC_2(template, add) {
    int64_t a = mpy_int(arg0);
    int64_t b = mpy_int(arg1);
    return mpy_new_int64(template_add(a, b));
}
MPY_FUNC_OBJ_2(template, add);

// template.is_positive(n) -> bool
MPY_FUNC_1(template, is_positive) {
    int64_t n = mpy_int(arg0);
    return mpy_bool(template_is_positive(n));
}
MPY_FUNC_OBJ_1(template, is_positive);

// template.strlen(s) -> int
MPY_FUNC_1(template, strlen) {
    const char *s = mpy_str(arg0);
    return mpy_new_int(template_strlen(s));
}
MPY_FUNC_OBJ_1(template, strlen);

// template.streq(a, b) -> bool
MPY_FUNC_2(template, streq) {
    const char *a = mpy_str(arg0);
    const char *b = mpy_str(arg1);
    return mpy_bool(template_streq(a, b));
}
MPY_FUNC_OBJ_2(template, streq);

// Example: Function with optional argument
// template.greet(name, greeting="Hello") -> str
MPY_FUNC_VAR(template, greet, 1, 2) {
    const char *name = mpy_str(args[0]);
    const char *greeting = (n_args > 1) ? mpy_str(args[1]) : "Hello";
    
    // Build greeting string (simple example)
    static char buf[256];
    snprintf(buf, sizeof(buf), "%s, %s!", greeting, name);
    return mpy_new_str(buf);
}
MPY_FUNC_OBJ_VAR(template, greet, 1, 2);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(template)
    MPY_MODULE_FUNC(template, add)
    MPY_MODULE_FUNC(template, is_positive)
    MPY_MODULE_FUNC(template, strlen)
    MPY_MODULE_FUNC(template, streq)
    MPY_MODULE_FUNC(template, greet)
    // Add constants if needed:
    // MPY_MODULE_INT(VERSION, 1)
MPY_MODULE_END(template)
