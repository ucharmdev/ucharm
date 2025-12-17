/*
 * modbase64 - Native base64 encoding/decoding module for ucharm
 * 
 * This module bridges Zig's base64 implementation to MicroPython.
 * 
 * Usage in Python:
 *   import base64
 *   encoded = base64.b64encode(b"Hello")  # -> b"SGVsbG8="
 *   decoded = base64.b64decode(b"SGVsbG8=")  # -> b"Hello"
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// External Zig functions
extern int base64_encode(const char *input, size_t input_len, char *output, size_t output_len);
extern size_t base64_encode_len(size_t input_len);
extern int base64_decode(const char *input, size_t input_len, char *output, size_t output_len);
extern size_t base64_decode_len(size_t input_len);
extern int base64_urlsafe_encode(const char *input, size_t input_len, char *output, size_t output_len);
extern int base64_urlsafe_decode(const char *input, size_t input_len, char *output, size_t output_len);

// ============================================================================
// Standard Base64
// ============================================================================

// base64.b64encode(data: bytes) -> bytes
MPY_FUNC_1(base64, b64encode) {
    size_t input_len;
    const char *input = mpy_bytes_len(arg0, &input_len);
    
    size_t output_len = base64_encode_len(input_len);
    char *output = mpy_alloc(output_len + 1);
    
    int result = base64_encode(input, input_len, output, output_len);
    if (result < 0) {
        mpy_free(output, output_len + 1);
        mp_raise_ValueError(MP_ERROR_TEXT("base64 encoding failed"));
    }
    
    mp_obj_t ret = mpy_new_bytes(output, result);
    mpy_free(output, output_len + 1);
    return ret;
}
MPY_FUNC_OBJ_1(base64, b64encode);

// base64.b64decode(data: bytes) -> bytes
MPY_FUNC_1(base64, b64decode) {
    size_t input_len;
    const char *input = mpy_bytes_len(arg0, &input_len);
    
    size_t output_len = base64_decode_len(input_len);
    char *output = mpy_alloc(output_len + 1);
    
    int result = base64_decode(input, input_len, output, output_len);
    if (result < 0) {
        mpy_free(output, output_len + 1);
        mp_raise_ValueError(MP_ERROR_TEXT("invalid base64 input"));
    }
    
    mp_obj_t ret = mpy_new_bytes(output, result);
    mpy_free(output, output_len + 1);
    return ret;
}
MPY_FUNC_OBJ_1(base64, b64decode);

// ============================================================================
// URL-Safe Base64
// ============================================================================

// base64.urlsafe_b64encode(data: bytes) -> bytes
MPY_FUNC_1(base64, urlsafe_b64encode) {
    size_t input_len;
    const char *input = mpy_bytes_len(arg0, &input_len);
    
    size_t output_len = base64_encode_len(input_len);
    char *output = mpy_alloc(output_len + 1);
    
    int result = base64_urlsafe_encode(input, input_len, output, output_len);
    if (result < 0) {
        mpy_free(output, output_len + 1);
        mp_raise_ValueError(MP_ERROR_TEXT("base64 encoding failed"));
    }
    
    mp_obj_t ret = mpy_new_bytes(output, result);
    mpy_free(output, output_len + 1);
    return ret;
}
MPY_FUNC_OBJ_1(base64, urlsafe_b64encode);

// base64.urlsafe_b64decode(data: bytes) -> bytes
MPY_FUNC_1(base64, urlsafe_b64decode) {
    size_t input_len;
    const char *input = mpy_bytes_len(arg0, &input_len);
    
    size_t output_len = base64_decode_len(input_len);
    char *output = mpy_alloc(output_len + 1);
    
    int result = base64_urlsafe_decode(input, input_len, output, output_len);
    if (result < 0) {
        mpy_free(output, output_len + 1);
        mp_raise_ValueError(MP_ERROR_TEXT("invalid base64 input"));
    }
    
    mp_obj_t ret = mpy_new_bytes(output, result);
    mpy_free(output, output_len + 1);
    return ret;
}
MPY_FUNC_OBJ_1(base64, urlsafe_b64decode);

// ============================================================================
// Convenience wrappers that accept strings
// ============================================================================

// base64.encodebytes(data: bytes) -> bytes (with newlines every 76 chars)
// For simplicity, this just calls b64encode without newlines
MPY_FUNC_1(base64, encodebytes) {
    return mod_base64_b64encode(arg0);
}
MPY_FUNC_OBJ_1(base64, encodebytes);

// base64.decodebytes(data: bytes) -> bytes
MPY_FUNC_1(base64, decodebytes) {
    return mod_base64_b64decode(arg0);
}
MPY_FUNC_OBJ_1(base64, decodebytes);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(base64)
    MPY_MODULE_FUNC(base64, b64encode)
    MPY_MODULE_FUNC(base64, b64decode)
    MPY_MODULE_FUNC(base64, urlsafe_b64encode)
    MPY_MODULE_FUNC(base64, urlsafe_b64decode)
    MPY_MODULE_FUNC(base64, encodebytes)
    MPY_MODULE_FUNC(base64, decodebytes)
MPY_MODULE_END(base64)
