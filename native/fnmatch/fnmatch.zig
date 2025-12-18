// fnmatch.zig - Native fnmatch module for ucharm
//
// This module provides Unix shell-style pattern matching:
// - fnmatch(name, pattern) - Test if name matches pattern
// - fnmatchcase(name, pattern) - Case-sensitive matching
// - filter(names, pattern) - Filter list by pattern
// - translate(pattern) - Convert pattern to regex

const std = @import("std");

// ============================================================================
// Pattern Matching Implementation
// ============================================================================

/// Match a name against a shell-style pattern
/// Supports: * (match everything), ? (match one char), [seq] (char class), [!seq] (negated)
pub fn fnmatch_impl(name: [*:0]const u8, pattern: [*:0]const u8, case_sensitive: bool) bool {
    var ni: usize = 0;
    var pi: usize = 0;

    while (pattern[pi] != 0) {
        const pc = pattern[pi];

        if (pc == '*') {
            // Skip consecutive stars
            while (pattern[pi] == '*') {
                pi += 1;
            }

            // Trailing * matches everything
            if (pattern[pi] == 0) {
                return true;
            }

            // Try to match rest of pattern at each position
            while (name[ni] != 0) {
                if (fnmatch_impl(name + ni, pattern + pi, case_sensitive)) {
                    return true;
                }
                ni += 1;
            }
            return fnmatch_impl(name + ni, pattern + pi, case_sensitive);
        } else if (pc == '?') {
            // Match any single character
            if (name[ni] == 0) {
                return false;
            }
            ni += 1;
            pi += 1;
        } else if (pc == '[') {
            // Character class - first check if there's a closing bracket
            var has_closing = false;
            var check_pi = pi + 1;
            while (pattern[check_pi] != 0) {
                if (pattern[check_pi] == ']') {
                    has_closing = true;
                    break;
                }
                check_pi += 1;
            }

            // If no closing bracket, treat '[' as literal
            if (!has_closing) {
                if (name[ni] == 0 or name[ni] != '[') {
                    return false;
                }
                ni += 1;
                pi += 1;
                continue;
            }

            if (name[ni] == 0) {
                return false;
            }

            pi += 1;
            const negated = pattern[pi] == '!' or pattern[pi] == '^';
            if (negated) {
                pi += 1;
            }

            var matched = false;
            const nc = if (case_sensitive) name[ni] else to_lower(name[ni]);

            while (pattern[pi] != 0 and pattern[pi] != ']') {
                const range_start = if (case_sensitive) pattern[pi] else to_lower(pattern[pi]);
                pi += 1;

                if (pattern[pi] == '-' and pattern[pi + 1] != ']' and pattern[pi + 1] != 0) {
                    pi += 1;
                    const range_end = if (case_sensitive) pattern[pi] else to_lower(pattern[pi]);
                    pi += 1;

                    if (nc >= range_start and nc <= range_end) {
                        matched = true;
                    }
                } else {
                    if (nc == range_start) {
                        matched = true;
                    }
                }
            }

            if (pattern[pi] == ']') {
                pi += 1;
            }

            if (matched == negated) {
                return false;
            }
            ni += 1;
        } else {
            // Literal character match
            if (name[ni] == 0) {
                return false;
            }

            const nc = if (case_sensitive) name[ni] else to_lower(name[ni]);
            const expected = if (case_sensitive) pc else to_lower(pc);

            if (nc != expected) {
                return false;
            }
            ni += 1;
            pi += 1;
        }
    }

    return name[ni] == 0;
}

fn to_lower(c: u8) u8 {
    if (c >= 'A' and c <= 'Z') {
        return c + 32;
    }
    return c;
}

// ============================================================================
// Translate Pattern to Regex
// ============================================================================

/// Translate shell pattern to regex pattern
/// Writes to provided buffer, returns length written
pub fn translate_impl(pattern: [*:0]const u8, buf: [*]u8, buf_size: usize) usize {
    var pi: usize = 0;
    var bi: usize = 0;

    // Start with anchor
    if (bi < buf_size) {
        buf[bi] = '(';
        bi += 1;
    }
    if (bi < buf_size) {
        buf[bi] = '?';
        bi += 1;
    }
    if (bi < buf_size) {
        buf[bi] = 's';
        bi += 1;
    }
    if (bi < buf_size) {
        buf[bi] = ')';
        bi += 1;
    }

    while (pattern[pi] != 0 and bi + 5 < buf_size) {
        const c = pattern[pi];

        if (c == '*') {
            buf[bi] = '.';
            bi += 1;
            buf[bi] = '*';
            bi += 1;
        } else if (c == '?') {
            buf[bi] = '.';
            bi += 1;
        } else if (c == '[') {
            buf[bi] = '[';
            bi += 1;
            pi += 1;

            if (pattern[pi] == '!') {
                buf[bi] = '^';
                bi += 1;
                pi += 1;
            } else if (pattern[pi] == '^') {
                buf[bi] = '\\';
                bi += 1;
                buf[bi] = '^';
                bi += 1;
                pi += 1;
            }

            while (pattern[pi] != 0 and pattern[pi] != ']' and bi + 2 < buf_size) {
                buf[bi] = pattern[pi];
                bi += 1;
                pi += 1;
            }

            if (pattern[pi] == ']') {
                buf[bi] = ']';
                bi += 1;
            }
        } else if (c == '.' or c == '+' or c == '^' or c == '$' or
            c == '(' or c == ')' or c == '{' or c == '}' or
            c == '|' or c == '\\')
        {
            // Escape regex special characters
            buf[bi] = '\\';
            bi += 1;
            buf[bi] = c;
            bi += 1;
        } else {
            buf[bi] = c;
            bi += 1;
        }

        pi += 1;
    }

    // End anchor
    if (bi < buf_size) {
        buf[bi] = '\\';
        bi += 1;
    }
    if (bi < buf_size) {
        buf[bi] = 'Z';
        bi += 1;
    }

    if (bi < buf_size) {
        buf[bi] = 0;
    }

    return bi;
}

// ============================================================================
// Exported Functions (C ABI)
// ============================================================================

/// Match name against pattern (case-sensitive on Unix, like CPython)
pub export fn fnmatch_fnmatch(name: [*:0]const u8, pattern: [*:0]const u8) bool {
    return fnmatch_impl(name, pattern, true);
}

/// Match name against pattern (case-sensitive)
pub export fn fnmatch_fnmatchcase(name: [*:0]const u8, pattern: [*:0]const u8) bool {
    return fnmatch_impl(name, pattern, true);
}

/// Translate pattern to regex, write to buffer
pub export fn fnmatch_translate(pattern: [*:0]const u8, buf: [*]u8, buf_size: usize) usize {
    return translate_impl(pattern, buf, buf_size);
}

// ============================================================================
// Tests
// ============================================================================

test "fnmatch basic" {
    try std.testing.expect(fnmatch_fnmatch("hello.txt", "*.txt"));
    try std.testing.expect(fnmatch_fnmatch("hello.txt", "hello.*"));
    try std.testing.expect(fnmatch_fnmatch("hello.txt", "h*o.txt"));
    try std.testing.expect(!fnmatch_fnmatch("hello.txt", "*.py"));
}

test "fnmatch question mark" {
    try std.testing.expect(fnmatch_fnmatch("hello", "hell?"));
    try std.testing.expect(fnmatch_fnmatch("hello", "h?llo"));
    try std.testing.expect(!fnmatch_fnmatch("hello", "h?lo"));
}

test "fnmatch character class" {
    try std.testing.expect(fnmatch_fnmatch("hello", "[gh]ello"));
    try std.testing.expect(fnmatch_fnmatch("hello", "[a-z]ello"));
    // Case-sensitive fnmatch: [A-Z] does NOT match lowercase
    try std.testing.expect(!fnmatch_fnmatch("hello", "[A-Z]ello"));
    try std.testing.expect(!fnmatch_fnmatchcase("hello", "[A-Z]ello"));
}

test "fnmatch negated class" {
    try std.testing.expect(fnmatch_fnmatch("hello", "[!abc]ello"));
    try std.testing.expect(!fnmatch_fnmatch("hello", "[!h]ello"));
}

test "fnmatchcase" {
    try std.testing.expect(fnmatch_fnmatchcase("Hello", "Hello"));
    try std.testing.expect(!fnmatch_fnmatchcase("Hello", "hello"));
    try std.testing.expect(!fnmatch_fnmatch("Hello", "hello")); // case-sensitive on Unix
}
