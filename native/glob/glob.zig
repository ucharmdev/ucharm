const std = @import("std");
const fs = std.fs;
const mem = std.mem;

// Glob pattern matching and file finding
// Provides glob() and fnmatch() functionality

/// Match a pattern against a string (fnmatch-style)
/// Supports: * (any chars), ? (single char), [seq] (character class)
/// Returns 1 if matches, 0 if not
pub export fn glob_fnmatch(
    pattern: [*]const u8,
    pattern_len: usize,
    name: [*]const u8,
    name_len: usize,
) i32 {
    const pat = pattern[0..pattern_len];
    const str = name[0..name_len];

    if (fnmatch_impl(pat, str)) {
        return 1;
    }
    return 0;
}

/// Internal fnmatch implementation
fn fnmatch_impl(pattern: []const u8, string: []const u8) bool {
    var pi: usize = 0; // pattern index
    var si: usize = 0; // string index
    var star_pi: ?usize = null; // position after last *
    var star_si: usize = 0; // string position at last *

    while (si < string.len or pi < pattern.len) {
        if (pi < pattern.len) {
            const pc = pattern[pi];

            if (pc == '*') {
                // Store position for backtracking
                star_pi = pi + 1;
                star_si = si;
                pi += 1;
                continue;
            }

            if (si < string.len) {
                const sc = string[si];

                if (pc == '?') {
                    // ? matches any single character
                    pi += 1;
                    si += 1;
                    continue;
                }

                if (pc == '[') {
                    // Character class
                    if (matchCharClass(pattern[pi..], sc)) |advance| {
                        pi += advance;
                        si += 1;
                        continue;
                    }
                    // No match, try backtrack
                } else if (pc == sc) {
                    // Exact match
                    pi += 1;
                    si += 1;
                    continue;
                }
            }
        }

        // Try to backtrack to last *
        if (star_pi) |spi| {
            pi = spi;
            star_si += 1;
            si = star_si;
            if (si <= string.len) {
                continue;
            }
        }

        return false;
    }

    return true;
}

/// Match a character class [seq] or [!seq]
/// Returns number of chars consumed from pattern, or null if no match
fn matchCharClass(pattern: []const u8, char: u8) ?usize {
    if (pattern.len < 2 or pattern[0] != '[') return null;

    var i: usize = 1;
    var negate = false;
    var matched = false;

    // Check for negation
    if (i < pattern.len and (pattern[i] == '!' or pattern[i] == '^')) {
        negate = true;
        i += 1;
    }

    // Empty class
    if (i >= pattern.len) return null;

    // Find closing bracket
    const start = i;
    while (i < pattern.len) {
        if (pattern[i] == ']' and i > start) {
            // Found end of class
            break;
        }

        // Check for range (e.g., a-z)
        if (i + 2 < pattern.len and pattern[i + 1] == '-' and pattern[i + 2] != ']') {
            const range_start = pattern[i];
            const range_end = pattern[i + 2];
            if (char >= range_start and char <= range_end) {
                matched = true;
            }
            i += 3;
        } else {
            if (pattern[i] == char) {
                matched = true;
            }
            i += 1;
        }
    }

    // Must find closing bracket
    if (i >= pattern.len or pattern[i] != ']') return null;

    if (negate) matched = !matched;

    if (matched) {
        return i + 1; // Include the ]
    }
    return null;
}

// ============================================================================
// Glob file iteration - uses callbacks for MicroPython integration
// ============================================================================

/// Callback type for glob results
pub const GlobCallback = *const fn (path: [*]const u8, path_len: usize, user_data: ?*anyopaque) callconv(.c) i32;

/// Glob files matching a pattern in a directory
/// Returns number of matches found, or -1 on error
pub export fn glob_glob(
    dir_path: [*]const u8,
    dir_path_len: usize,
    pattern: [*]const u8,
    pattern_len: usize,
    callback: GlobCallback,
    user_data: ?*anyopaque,
) i32 {
    const dir_str = dir_path[0..dir_path_len];
    const pat = pattern[0..pattern_len];

    // Open the directory
    var dir = fs.cwd().openDir(dir_str, .{ .iterate = true }) catch {
        return -1;
    };
    defer dir.close();

    var count: i32 = 0;

    // Iterate directory
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (fnmatch_impl(pat, entry.name)) {
            // Build full path
            var path_buf: [4096]u8 = undefined;
            const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_str, entry.name }) catch continue;

            // Call the callback
            const result = callback(full_path.ptr, full_path.len, user_data);
            if (result < 0) {
                // Callback requested stop
                break;
            }
            count += 1;
        }
    }

    return count;
}

/// Recursive glob with ** support
pub export fn glob_rglob(
    dir_path: [*]const u8,
    dir_path_len: usize,
    pattern: [*]const u8,
    pattern_len: usize,
    callback: GlobCallback,
    user_data: ?*anyopaque,
) i32 {
    const dir_str = dir_path[0..dir_path_len];
    const pat = pattern[0..pattern_len];

    var count: i32 = 0;
    rglobImpl(dir_str, pat, callback, user_data, &count) catch {
        return -1;
    };

    return count;
}

fn rglobImpl(
    dir_path: []const u8,
    pattern: []const u8,
    callback: GlobCallback,
    user_data: ?*anyopaque,
    count: *i32,
) !void {
    var dir = fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return;
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        var path_buf: [4096]u8 = undefined;
        const full_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.name });

        // Check if this entry matches the pattern
        if (fnmatch_impl(pattern, entry.name)) {
            const result = callback(full_path.ptr, full_path.len, user_data);
            if (result < 0) return;
            count.* += 1;
        }

        // Recurse into directories
        if (entry.kind == .directory) {
            // Skip hidden directories
            if (entry.name.len > 0 and entry.name[0] != '.') {
                rglobImpl(full_path, pattern, callback, user_data, count) catch continue;
            }
        }
    }
}

/// Check if a path matches a glob pattern (with ** support for recursive matching)
pub export fn glob_match_path(
    pattern: [*]const u8,
    pattern_len: usize,
    path: [*]const u8,
    path_len: usize,
) i32 {
    const pat = pattern[0..pattern_len];
    const pth = path[0..path_len];

    if (matchPath(pat, pth)) {
        return 1;
    }
    return 0;
}

/// Match a path against a pattern with ** support
fn matchPath(pattern: []const u8, path: []const u8) bool {
    // Split pattern by /
    var pat_iter = mem.splitSequence(u8, pattern, "/");
    var path_iter = mem.splitSequence(u8, path, "/");

    return matchPathParts(&pat_iter, &path_iter);
}

fn matchPathParts(
    pat_iter: *mem.SplitIterator(u8, .sequence),
    path_iter: *mem.SplitIterator(u8, .sequence),
) bool {
    while (pat_iter.next()) |pat_part| {
        if (mem.eql(u8, pat_part, "**")) {
            // ** matches zero or more directories
            // Try matching rest of pattern at each position
            var saved_path = path_iter.*;
            var saved_pat = pat_iter.*;

            // Try matching here (** = 0 dirs)
            if (matchPathParts(&saved_pat, &saved_path)) {
                return true;
            }

            // Try skipping one path component at a time
            while (path_iter.next()) |_| {
                saved_path = path_iter.*;
                saved_pat = pat_iter.*;
                if (matchPathParts(&saved_pat, &saved_path)) {
                    return true;
                }
            }

            return false;
        }

        // Regular pattern part - must match next path part
        const path_part = path_iter.next() orelse return false;

        if (!fnmatch_impl(pat_part, path_part)) {
            return false;
        }
    }

    // Pattern exhausted - path must also be exhausted
    return path_iter.next() == null;
}
