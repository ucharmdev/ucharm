// bridge.zig - Zig helpers for MicroPython bridge
//
// This module provides common utilities for writing Zig code that
// will be called from C/MicroPython.
//
// Usage:
//   const bridge = @import("bridge.zig");
//
//   export fn my_func(str: bridge.CStr) bool {
//       const slice = bridge.cstr_to_slice(str);
//       // ... work with slice
//       return true;
//   }

const std = @import("std");

// ============================================================================
// Types
// ============================================================================

/// Null-terminated C string pointer (immutable)
pub const CStr = [*:0]const u8;

/// Mutable null-terminated C string pointer
pub const CStrMut = [*:0]u8;

/// Result type for functions that can fail
pub fn Result(comptime T: type) type {
    return extern struct {
        value: T,
        success: bool,
        error_code: u8,
    };
}

// ============================================================================
// String Utilities
// ============================================================================

/// Convert C string to Zig slice
pub fn cstr_to_slice(str: CStr) []const u8 {
    var len: usize = 0;
    while (str[len] != 0) : (len += 1) {}
    return str[0..len];
}

/// Get length of C string
pub fn cstr_len(str: CStr) usize {
    var len: usize = 0;
    while (str[len] != 0) : (len += 1) {}
    return len;
}

/// Compare two C strings for equality
pub fn cstr_eql(a: CStr, b: CStr) bool {
    var i: usize = 0;
    while (a[i] != 0 and b[i] != 0) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return a[i] == b[i];
}

/// Check if C string starts with prefix
pub fn cstr_starts_with(str: CStr, prefix: []const u8) bool {
    for (prefix, 0..) |c, i| {
        if (str[i] == 0 or str[i] != c) return false;
    }
    return true;
}

/// Check if C string ends with suffix
pub fn cstr_ends_with(str: CStr, suffix: []const u8) bool {
    const len = cstr_len(str);
    if (len < suffix.len) return false;
    const start = len - suffix.len;
    for (suffix, 0..) |c, i| {
        if (str[start + i] != c) return false;
    }
    return true;
}

/// Advance pointer past prefix, returning pointer to rest of string
pub fn cstr_skip(str: CStr, n: usize) CStr {
    return @ptrCast(str + n);
}

// ============================================================================
// Number Parsing
// ============================================================================

/// Check if character is a digit
pub fn is_digit(c: u8) bool {
    return c >= '0' and c <= '9';
}

/// Check if character is whitespace
pub fn is_whitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r';
}

/// Check if string is a valid integer
pub fn is_valid_int(str: CStr) bool {
    var i: usize = 0;
    if (str[0] == '-' or str[0] == '+') i = 1;
    if (str[i] == 0) return false;
    while (str[i] != 0) : (i += 1) {
        if (!is_digit(str[i])) return false;
    }
    return true;
}

/// Check if string is a valid float
pub fn is_valid_float(str: CStr) bool {
    var i: usize = 0;
    var has_dot = false;
    var has_digit = false;

    if (str[0] == '-' or str[0] == '+') i = 1;

    while (str[i] != 0) : (i += 1) {
        if (is_digit(str[i])) {
            has_digit = true;
        } else if (str[i] == '.' and !has_dot) {
            has_dot = true;
        } else if (str[i] == 'e' or str[i] == 'E') {
            // Handle exponent
            i += 1;
            if (str[i] == '-' or str[i] == '+') i += 1;
            if (str[i] == 0 or !is_digit(str[i])) return false;
            while (str[i] != 0) : (i += 1) {
                if (!is_digit(str[i])) return false;
            }
            return has_digit;
        } else {
            return false;
        }
    }
    return has_digit;
}

/// Parse integer from string
pub fn parse_int(str: CStr) i64 {
    var result: i64 = 0;
    var i: usize = 0;
    var negative = false;

    if (str[0] == '-') {
        negative = true;
        i = 1;
    } else if (str[0] == '+') {
        i = 1;
    }

    while (str[i] != 0) : (i += 1) {
        if (is_digit(str[i])) {
            result = result * 10 + @as(i64, str[i] - '0');
        }
    }

    return if (negative) -result else result;
}

// ============================================================================
// Boolean Parsing
// ============================================================================

/// Check if string is a truthy value (true, yes, 1, on)
pub fn is_truthy(str: CStr) bool {
    const lower = to_lower_first(str);
    if (cstr_eql(str, "1")) return true;
    if (lower == 't' and cstr_starts_with(cstr_skip(str, 1), "rue")) return true;
    if (lower == 'y' and cstr_starts_with(cstr_skip(str, 1), "es")) return true;
    if (lower == 'o' and cstr_starts_with(cstr_skip(str, 1), "n") and str[2] == 0) return true;
    return false;
}

/// Check if string is a falsy value (false, no, 0, off)
pub fn is_falsy(str: CStr) bool {
    const lower = to_lower_first(str);
    if (cstr_eql(str, "0")) return true;
    if (lower == 'f' and cstr_starts_with(cstr_skip(str, 1), "alse")) return true;
    if (lower == 'n' and cstr_starts_with(cstr_skip(str, 1), "o") and str[2] == 0) return true;
    if (lower == 'o' and cstr_starts_with(cstr_skip(str, 1), "ff") and str[3] == 0) return true;
    return false;
}

fn to_lower_first(str: CStr) u8 {
    const c = str[0];
    if (c >= 'A' and c <= 'Z') return c + 32;
    return c;
}

// ============================================================================
// Export Helpers
// ============================================================================

/// Wrapper to export a function with C calling convention
/// Usage: pub const my_export = exportFn("prefix_", myFunction);
pub fn exportFn(comptime prefix: []const u8, comptime func: anytype) @TypeOf(func) {
    _ = prefix; // Used in @export which happens at comptime
    return func;
}

// ============================================================================
// Tests
// ============================================================================

test "cstr_to_slice" {
    const str: CStr = "hello";
    const slice = cstr_to_slice(str);
    try std.testing.expectEqualStrings("hello", slice);
}

test "cstr_eql" {
    try std.testing.expect(cstr_eql("hello", "hello"));
    try std.testing.expect(!cstr_eql("hello", "world"));
    try std.testing.expect(!cstr_eql("hello", "hell"));
}

test "cstr_starts_with" {
    try std.testing.expect(cstr_starts_with("--flag", "--"));
    try std.testing.expect(!cstr_starts_with("-f", "--"));
}

test "is_valid_int" {
    try std.testing.expect(is_valid_int("123"));
    try std.testing.expect(is_valid_int("-456"));
    try std.testing.expect(is_valid_int("+789"));
    try std.testing.expect(!is_valid_int(""));
    try std.testing.expect(!is_valid_int("abc"));
    try std.testing.expect(!is_valid_int("12.34"));
}

test "is_valid_float" {
    try std.testing.expect(is_valid_float("123"));
    try std.testing.expect(is_valid_float("12.34"));
    try std.testing.expect(is_valid_float("-12.34"));
    try std.testing.expect(is_valid_float("1e10"));
    try std.testing.expect(is_valid_float("1.5e-3"));
    try std.testing.expect(!is_valid_float(""));
    try std.testing.expect(!is_valid_float("abc"));
}

test "parse_int" {
    try std.testing.expectEqual(@as(i64, 123), parse_int("123"));
    try std.testing.expectEqual(@as(i64, -456), parse_int("-456"));
    try std.testing.expectEqual(@as(i64, 0), parse_int("0"));
}

test "truthy_falsy" {
    try std.testing.expect(is_truthy("true"));
    try std.testing.expect(is_truthy("True"));
    try std.testing.expect(is_truthy("1"));
    try std.testing.expect(is_truthy("yes"));
    try std.testing.expect(is_truthy("on"));

    try std.testing.expect(is_falsy("false"));
    try std.testing.expect(is_falsy("False"));
    try std.testing.expect(is_falsy("0"));
    try std.testing.expect(is_falsy("no"));
    try std.testing.expect(is_falsy("off"));
}
