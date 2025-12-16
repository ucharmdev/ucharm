// template.zig - Template for a new Zig module
//
// Copy this file to your module directory and rename it.
// Replace "template" with your module name.
//
// Example: For a "math" module:
//   1. Create native/math/
//   2. Copy this to native/math/math.zig
//   3. Replace all "template" with "math"
//   4. Implement your functions

const std = @import("std");

// Bridge utilities (imported via build.zig)
// If you don't need bridge utilities, you can remove this import
const bridge = @import("bridge");

// ============================================================================
// Module Implementation
// ============================================================================

// Add your Zig functions here.
// Keep them pure and safe - no allocations if possible.

fn example_add(a: i64, b: i64) i64 {
    return a + b;
}

fn example_is_positive(n: i64) bool {
    return n > 0;
}

fn example_greet(name: bridge.CStr) bridge.CStr {
    // Note: For returning strings, you'd typically need a buffer
    // or return a pointer into the input string.
    // This is just an example that returns the input.
    _ = name;
    return "Hello!";
}

// ============================================================================
// Exported Functions (C ABI)
// ============================================================================

// These functions are callable from C. Use the `export` keyword
// and ensure all types are C-compatible.

/// Add two integers
export fn template_add(a: i64, b: i64) i64 {
    return example_add(a, b);
}

/// Check if number is positive
export fn template_is_positive(n: i64) bool {
    return example_is_positive(n);
}

/// Get string length
export fn template_strlen(str: bridge.CStr) usize {
    return bridge.cstr_len(str);
}

/// Compare two strings
export fn template_streq(a: bridge.CStr, b: bridge.CStr) bool {
    return bridge.cstr_eql(a, b);
}

// ============================================================================
// Tests
// ============================================================================

test "add" {
    try std.testing.expectEqual(@as(i64, 5), template_add(2, 3));
    try std.testing.expectEqual(@as(i64, -1), template_add(2, -3));
}

test "is_positive" {
    try std.testing.expect(template_is_positive(5));
    try std.testing.expect(!template_is_positive(-5));
    try std.testing.expect(!template_is_positive(0));
}

test "strlen" {
    try std.testing.expectEqual(@as(usize, 5), template_strlen("hello"));
    try std.testing.expectEqual(@as(usize, 0), template_strlen(""));
}
