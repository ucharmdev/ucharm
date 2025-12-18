// input.zig - Core input utilities for ucharm
//
// This module provides helper functions for the input C bridge (modinput.c)
// Most of the terminal interaction is done directly in C for efficiency.

const std = @import("std");

// ============================================================================
// String Helpers (for use by C bridge)
// ============================================================================

/// Get string length
pub export fn input_strlen(str: [*:0]const u8) usize {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    return i;
}

/// Compare two strings for equality
pub export fn input_streq(a: [*:0]const u8, b: [*:0]const u8) bool {
    var i: usize = 0;
    while (a[i] != 0 and b[i] != 0) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return a[i] == b[i];
}

/// Check if string starts with a prefix
pub export fn input_starts_with(str: [*:0]const u8, prefix: [*:0]const u8) bool {
    var i: usize = 0;
    while (prefix[i] != 0) : (i += 1) {
        if (str[i] == 0 or str[i] != prefix[i]) return false;
    }
    return true;
}

/// Clamp integer to range
pub export fn input_clamp(value: i32, min_val: i32, max_val: i32) i32 {
    if (value < min_val) return min_val;
    if (value > max_val) return max_val;
    return value;
}

/// Wrap index around (for circular navigation)
pub export fn input_wrap_index(value: i32, count: i32) i32 {
    if (count <= 0) return 0;
    var result = @mod(value, count);
    if (result < 0) result += count;
    return result;
}

// ============================================================================
// Tests
// ============================================================================

test "strlen" {
    try std.testing.expectEqual(@as(usize, 5), input_strlen("hello"));
    try std.testing.expectEqual(@as(usize, 0), input_strlen(""));
}

test "streq" {
    try std.testing.expect(input_streq("hello", "hello"));
    try std.testing.expect(!input_streq("hello", "world"));
    try std.testing.expect(!input_streq("hello", "hell"));
}

test "starts_with" {
    try std.testing.expect(input_starts_with("hello world", "hello"));
    try std.testing.expect(!input_starts_with("hello", "world"));
    try std.testing.expect(input_starts_with("hello", ""));
}

test "clamp" {
    try std.testing.expectEqual(@as(i32, 5), input_clamp(5, 0, 10));
    try std.testing.expectEqual(@as(i32, 0), input_clamp(-5, 0, 10));
    try std.testing.expectEqual(@as(i32, 10), input_clamp(15, 0, 10));
}

test "wrap_index" {
    try std.testing.expectEqual(@as(i32, 0), input_wrap_index(0, 5));
    try std.testing.expectEqual(@as(i32, 1), input_wrap_index(1, 5));
    try std.testing.expectEqual(@as(i32, 0), input_wrap_index(5, 5));
}
