const std = @import("std");

// Base64 encoding/decoding using Zig's standard library
// This provides a native implementation for MicroPython

const base64_standard = std.base64.standard;
const base64_url = std.base64.url_safe;

/// Encode bytes to base64 string
/// Returns the number of bytes written to output
pub export fn base64_encode(
    input: [*]const u8,
    input_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const input_slice = input[0..input_len];
    const output_slice = output[0..output_len];

    const encoded = base64_standard.Encoder.encode(output_slice, input_slice);
    return @intCast(encoded.len);
}

/// Calculate the encoded length for a given input length
pub export fn base64_encode_len(input_len: usize) usize {
    return base64_standard.Encoder.calcSize(input_len);
}

/// Decode base64 string to bytes
/// Returns the number of bytes written to output, or -1 on error
pub export fn base64_decode(
    input: [*]const u8,
    input_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const input_slice = input[0..input_len];
    const output_slice = output[0..output_len];

    // Calculate the exact decoded size first
    const decoded_size = base64_standard.Decoder.calcSizeForSlice(input_slice) catch {
        return -1;
    };

    if (decoded_size > output_len) {
        return -1;
    }

    // Decode writes directly to buffer (returns void)
    base64_standard.Decoder.decode(output_slice[0..decoded_size], input_slice) catch {
        return -1;
    };

    return @intCast(decoded_size);
}

/// Calculate the maximum decoded length for a given input length
pub export fn base64_decode_len(input_len: usize) usize {
    return base64_standard.Decoder.calcSizeUpperBound(input_len) catch {
        return input_len; // Fallback: worst case is same size
    };
}

/// Encode bytes to URL-safe base64 (uses - and _ instead of + and /)
pub export fn base64_urlsafe_encode(
    input: [*]const u8,
    input_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const input_slice = input[0..input_len];
    const output_slice = output[0..output_len];

    const encoded = base64_url.Encoder.encode(output_slice, input_slice);
    return @intCast(encoded.len);
}

/// Decode URL-safe base64 string to bytes
pub export fn base64_urlsafe_decode(
    input: [*]const u8,
    input_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const input_slice = input[0..input_len];
    const output_slice = output[0..output_len];

    // Calculate the exact decoded size first
    const decoded_size = base64_url.Decoder.calcSizeForSlice(input_slice) catch {
        return -1;
    };

    if (decoded_size > output_len) {
        return -1;
    }

    // Decode writes directly to buffer (returns void)
    base64_url.Decoder.decode(output_slice[0..decoded_size], input_slice) catch {
        return -1;
    };

    return @intCast(decoded_size);
}
