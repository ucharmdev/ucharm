// args.zig - Core argument parsing logic in Zig
// This is the safe, fast core. The C bridge (modargs.c) handles MicroPython API.

const std = @import("std");

// ============================================================================
// Types
// ============================================================================

pub const ArgType = enum(u8) {
    string = 0,
    int = 1,
    float = 2,
    bool = 3,
};

pub const ParsedArg = extern struct {
    name: [*:0]const u8, // Null-terminated name (without --)
    value: [*:0]const u8, // Null-terminated value (or "1"/"0" for bool)
    arg_type: ArgType,
    is_positional: bool,
};

pub const ParseError = enum(u8) {
    none = 0,
    unknown_flag = 1,
    missing_value = 2,
    invalid_int = 3,
    invalid_float = 4,
};

pub const ParseResult = extern struct {
    args: [*]ParsedArg,
    count: usize,
    positional_start: usize, // Index where positional args begin
    error_code: ParseError,
    error_arg: [*:0]const u8, // Which arg caused the error
};

// ============================================================================
// String helpers (safe Zig implementations)
// ============================================================================

fn streql(a: [*:0]const u8, b: [*:0]const u8) bool {
    var i: usize = 0;
    while (a[i] != 0 and b[i] != 0) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return a[i] == b[i];
}

fn startsWith(str: [*:0]const u8, prefix: []const u8) bool {
    for (prefix, 0..) |c, i| {
        if (str[i] == 0 or str[i] != c) return false;
    }
    return true;
}

fn strlen(str: [*:0]const u8) usize {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    return i;
}

// ============================================================================
// Parsing functions (exported with C ABI)
// ============================================================================

/// Check if a string is a valid integer
export fn args_is_valid_int(str: [*:0]const u8) bool {
    var i: usize = 0;

    // Skip leading minus
    if (str[0] == '-') i = 1;

    // Must have at least one digit
    if (str[i] == 0) return false;

    while (str[i] != 0) : (i += 1) {
        if (str[i] < '0' or str[i] > '9') return false;
    }
    return true;
}

/// Check if a string is a valid float
export fn args_is_valid_float(str: [*:0]const u8) bool {
    var i: usize = 0;
    var has_dot = false;
    var has_digit = false;

    // Skip leading minus
    if (str[0] == '-') i = 1;

    while (str[i] != 0) : (i += 1) {
        if (str[i] >= '0' and str[i] <= '9') {
            has_digit = true;
        } else if (str[i] == '.' and !has_dot) {
            has_dot = true;
        } else {
            return false;
        }
    }
    return has_digit;
}

/// Parse an integer from string
export fn args_parse_int(str: [*:0]const u8) i64 {
    var result: i64 = 0;
    var i: usize = 0;
    var negative = false;

    if (str[0] == '-') {
        negative = true;
        i = 1;
    }

    while (str[i] != 0) : (i += 1) {
        if (str[i] >= '0' and str[i] <= '9') {
            result = result * 10 + @as(i64, str[i] - '0');
        }
    }

    return if (negative) -result else result;
}

/// Check if string starts with "--"
export fn args_is_long_flag(str: [*:0]const u8) bool {
    return str[0] == '-' and str[1] == '-' and str[2] != 0;
}

/// Check if string starts with "-" (but not "--")
export fn args_is_short_flag(str: [*:0]const u8) bool {
    return str[0] == '-' and str[1] != '-' and str[1] != 0;
}

/// Check if string is "--"
export fn args_is_dashdash(str: [*:0]const u8) bool {
    return str[0] == '-' and str[1] == '-' and str[2] == 0;
}

/// Get flag name without dashes (returns pointer into original string)
/// "--name" -> "name", "-n" -> "n"
export fn args_get_flag_name(str: [*:0]const u8) [*:0]const u8 {
    if (str[0] == '-' and str[1] == '-') {
        // Long flag: skip "--"
        return @ptrCast(str + 2);
    } else if (str[0] == '-') {
        // Short flag: skip "-"
        return @ptrCast(str + 1);
    }
    return str;
}

/// Check if this looks like a negative number (not a flag)
export fn args_is_negative_number(str: [*:0]const u8) bool {
    if (str[0] != '-') return false;
    if (str[1] == 0) return false;
    // Check if second char is a digit
    return str[1] >= '0' and str[1] <= '9';
}

/// Compare two strings for equality
export fn args_streq(a: [*:0]const u8, b: [*:0]const u8) bool {
    return streql(a, b);
}

/// Get string length
export fn args_strlen(str: [*:0]const u8) usize {
    return strlen(str);
}

// ============================================================================
// Boolean parsing
// ============================================================================

/// Check if string represents a truthy value
export fn args_is_truthy(str: [*:0]const u8) bool {
    // true, yes, 1, on
    if (streql(str, "true") or streql(str, "True") or streql(str, "TRUE")) return true;
    if (streql(str, "yes") or streql(str, "Yes") or streql(str, "YES")) return true;
    if (streql(str, "1")) return true;
    if (streql(str, "on") or streql(str, "On") or streql(str, "ON")) return true;
    return false;
}

/// Check if string represents a falsy value
export fn args_is_falsy(str: [*:0]const u8) bool {
    // false, no, 0, off
    if (streql(str, "false") or streql(str, "False") or streql(str, "FALSE")) return true;
    if (streql(str, "no") or streql(str, "No") or streql(str, "NO")) return true;
    if (streql(str, "0")) return true;
    if (streql(str, "off") or streql(str, "Off") or streql(str, "OFF")) return true;
    return false;
}

/// Check if flag name starts with "no-" (for boolean negation)
export fn args_is_negated_flag(name: [*:0]const u8) bool {
    return name[0] == 'n' and name[1] == 'o' and name[2] == '-' and name[3] != 0;
}

/// Get the base name of a negated flag ("no-verbose" -> "verbose")
export fn args_get_negated_base(name: [*:0]const u8) [*:0]const u8 {
    if (args_is_negated_flag(name)) {
        return @ptrCast(name + 3);
    }
    return name;
}

// ============================================================================
// Tests
// ============================================================================

test "is_valid_int" {
    try std.testing.expect(args_is_valid_int("123"));
    try std.testing.expect(args_is_valid_int("-456"));
    try std.testing.expect(args_is_valid_int("0"));
    try std.testing.expect(!args_is_valid_int(""));
    try std.testing.expect(!args_is_valid_int("abc"));
    try std.testing.expect(!args_is_valid_int("12.34"));
}

test "is_valid_float" {
    try std.testing.expect(args_is_valid_float("123"));
    try std.testing.expect(args_is_valid_float("12.34"));
    try std.testing.expect(args_is_valid_float("-12.34"));
    try std.testing.expect(args_is_valid_float(".5"));
    try std.testing.expect(!args_is_valid_float(""));
    try std.testing.expect(!args_is_valid_float("abc"));
}

test "parse_int" {
    try std.testing.expectEqual(@as(i64, 123), args_parse_int("123"));
    try std.testing.expectEqual(@as(i64, -456), args_parse_int("-456"));
    try std.testing.expectEqual(@as(i64, 0), args_parse_int("0"));
}

test "flag detection" {
    try std.testing.expect(args_is_long_flag("--name"));
    try std.testing.expect(!args_is_long_flag("-n"));
    try std.testing.expect(!args_is_long_flag("name"));

    try std.testing.expect(args_is_short_flag("-n"));
    try std.testing.expect(!args_is_short_flag("--name"));
    try std.testing.expect(!args_is_short_flag("name"));
}

test "negated flags" {
    try std.testing.expect(args_is_negated_flag("no-verbose"));
    try std.testing.expect(!args_is_negated_flag("verbose"));
    try std.testing.expect(!args_is_negated_flag("no"));
}
