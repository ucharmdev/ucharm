// path.zig - Path manipulation operations
// Provides C-ABI compatible functions for path handling

const std = @import("std");

// ============================================================================
// Path Component Extraction
// ============================================================================

/// Get the base name (file name) from a path.
/// "/foo/bar/baz.txt" -> "baz.txt"
pub export fn path_basename(path: [*:0]const u8, buf: [*]u8, buf_len: usize) usize {
    const path_slice = std.mem.span(path);
    const base = std.fs.path.basename(path_slice);
    return copyToBuf(base, buf, buf_len);
}

/// Get the directory name from a path.
/// "/foo/bar/baz.txt" -> "/foo/bar"
pub export fn path_dirname(path: [*:0]const u8, buf: [*]u8, buf_len: usize) usize {
    const path_slice = std.mem.span(path);
    if (std.fs.path.dirname(path_slice)) |dir| {
        return copyToBuf(dir, buf, buf_len);
    }
    // Return "." for paths without directory
    return copyToBuf(".", buf, buf_len);
}

/// Get the file extension (including the dot).
/// "file.txt" -> ".txt", "file" -> ""
pub export fn path_extname(path: [*:0]const u8, buf: [*]u8, buf_len: usize) usize {
    const path_slice = std.mem.span(path);
    const ext = std.fs.path.extension(path_slice);
    return copyToBuf(ext, buf, buf_len);
}

/// Get the file name without extension.
/// "file.txt" -> "file", "archive.tar.gz" -> "archive.tar"
pub export fn path_stem(path: [*:0]const u8, buf: [*]u8, buf_len: usize) usize {
    const path_slice = std.mem.span(path);
    const base = std.fs.path.basename(path_slice);
    const stem = std.fs.path.stem(base);
    return copyToBuf(stem, buf, buf_len);
}

// ============================================================================
// Path Joining
// ============================================================================

/// Join two path components.
/// ("foo", "bar") -> "foo/bar"
pub export fn path_join(a: [*:0]const u8, b: [*:0]const u8, buf: [*]u8, buf_len: usize) usize {
    const a_slice = std.mem.span(a);
    const b_slice = std.mem.span(b);

    // Handle empty cases
    if (a_slice.len == 0) return copyToBuf(b_slice, buf, buf_len);
    if (b_slice.len == 0) return copyToBuf(a_slice, buf, buf_len);

    // If b is absolute, just return b
    if (std.fs.path.isAbsolute(b_slice)) {
        return copyToBuf(b_slice, buf, buf_len);
    }

    // Calculate required length
    const needs_sep = a_slice[a_slice.len - 1] != '/';
    const total_len = a_slice.len + (if (needs_sep) @as(usize, 1) else 0) + b_slice.len;

    if (total_len > buf_len) {
        return 0; // Buffer too small
    }

    // Copy first part
    @memcpy(buf[0..a_slice.len], a_slice);
    var pos = a_slice.len;

    // Add separator if needed
    if (needs_sep) {
        buf[pos] = '/';
        pos += 1;
    }

    // Copy second part
    @memcpy(buf[pos .. pos + b_slice.len], b_slice);

    return total_len;
}

/// Join three path components.
pub export fn path_join3(a: [*:0]const u8, b: [*:0]const u8, c: [*:0]const u8, buf: [*]u8, buf_len: usize) usize {
    // Use a temporary buffer for intermediate result
    const S = struct {
        var temp: [4096]u8 = undefined;
    };

    const first_len = path_join(a, b, &S.temp, S.temp.len);
    if (first_len == 0) return 0;

    S.temp[first_len] = 0; // Null terminate for next call
    return path_join(@ptrCast(&S.temp), c, buf, buf_len);
}

// ============================================================================
// Path Checks
// ============================================================================

/// Check if path is absolute.
pub export fn path_is_absolute(path: [*:0]const u8) bool {
    const path_slice = std.mem.span(path);
    return std.fs.path.isAbsolute(path_slice);
}

/// Check if path is relative.
pub export fn path_is_relative(path: [*:0]const u8) bool {
    return !path_is_absolute(path);
}

/// Check if path has an extension.
pub export fn path_has_extension(path: [*:0]const u8) bool {
    const path_slice = std.mem.span(path);
    const ext = std.fs.path.extension(path_slice);
    return ext.len > 0;
}

/// Check if path ends with a specific extension (case-sensitive).
/// Extension should include the dot: ".txt"
pub export fn path_has_ext(path: [*:0]const u8, ext: [*:0]const u8) bool {
    const path_slice = std.mem.span(path);
    const ext_slice = std.mem.span(ext);
    const path_ext = std.fs.path.extension(path_slice);
    return std.mem.eql(u8, path_ext, ext_slice);
}

// ============================================================================
// Path Normalization
// ============================================================================

/// Normalize a path (resolve . and .., remove duplicate slashes).
/// Note: Does not resolve symlinks, just cleans up the path string.
pub export fn path_normalize(path: [*:0]const u8, buf: [*]u8, buf_len: usize) usize {
    const path_slice = std.mem.span(path);

    // Simple normalization: handle . and .. and duplicate slashes
    var out_pos: usize = 0;
    var i: usize = 0;
    const is_abs = path_slice.len > 0 and path_slice[0] == '/';

    if (is_abs and buf_len > 0) {
        buf[0] = '/';
        out_pos = 1;
    }

    while (i < path_slice.len) {
        // Skip leading slashes
        while (i < path_slice.len and path_slice[i] == '/') : (i += 1) {}
        if (i >= path_slice.len) break;

        // Find end of component
        const start = i;
        while (i < path_slice.len and path_slice[i] != '/') : (i += 1) {}
        const component = path_slice[start..i];

        // Handle . and ..
        if (std.mem.eql(u8, component, ".")) {
            continue;
        } else if (std.mem.eql(u8, component, "..")) {
            // Go up one directory
            if (out_pos > (if (is_abs) @as(usize, 1) else 0)) {
                // Find previous slash
                out_pos -= 1;
                while (out_pos > (if (is_abs) @as(usize, 1) else 0) and buf[out_pos - 1] != '/') {
                    out_pos -= 1;
                }
            }
        } else {
            // Regular component
            if (out_pos > 0 and buf[out_pos - 1] != '/') {
                if (out_pos >= buf_len) return 0;
                buf[out_pos] = '/';
                out_pos += 1;
            }
            if (out_pos + component.len > buf_len) return 0;
            @memcpy(buf[out_pos .. out_pos + component.len], component);
            out_pos += component.len;
        }
    }

    // Handle empty result
    if (out_pos == 0) {
        if (buf_len > 0) {
            buf[0] = '.';
            return 1;
        }
        return 0;
    }

    return out_pos;
}

// ============================================================================
// Path Splitting
// ============================================================================

/// Get the number of components in a path.
/// "/foo/bar/baz" -> 3
pub export fn path_component_count(path: [*:0]const u8) usize {
    const path_slice = std.mem.span(path);
    if (path_slice.len == 0) return 0;

    var count: usize = 0;
    var in_component = false;

    for (path_slice) |c| {
        if (c == '/') {
            in_component = false;
        } else {
            if (!in_component) {
                count += 1;
                in_component = true;
            }
        }
    }

    return count;
}

/// Get a specific component by index.
/// "/foo/bar/baz", 1 -> "bar"
pub export fn path_component(path: [*:0]const u8, index: usize, buf: [*]u8, buf_len: usize) usize {
    const path_slice = std.mem.span(path);
    if (path_slice.len == 0) return 0;

    var count: usize = 0;
    var start: usize = 0;
    var i: usize = 0;

    while (i < path_slice.len) {
        // Skip slashes
        while (i < path_slice.len and path_slice[i] == '/') : (i += 1) {}
        if (i >= path_slice.len) break;

        start = i;

        // Find end of component
        while (i < path_slice.len and path_slice[i] != '/') : (i += 1) {}

        if (count == index) {
            return copyToBuf(path_slice[start..i], buf, buf_len);
        }
        count += 1;
    }

    return 0; // Index out of bounds
}

// ============================================================================
// Relative Path Calculation
// ============================================================================

/// Calculate relative path from one path to another.
/// ("/a/b/c", "/a/b/d/e") -> "../d/e"
pub export fn path_relative(from: [*:0]const u8, to: [*:0]const u8, buf: [*]u8, buf_len: usize) usize {
    const from_slice = std.mem.span(from);
    const to_slice = std.mem.span(to);

    // Find common prefix
    var common_len: usize = 0;
    var last_sep: usize = 0;
    const min_len = @min(from_slice.len, to_slice.len);

    for (0..min_len) |i| {
        if (from_slice[i] != to_slice[i]) break;
        common_len = i + 1;
        if (from_slice[i] == '/') last_sep = i + 1;
    }

    // Adjust to last separator
    if (common_len > 0 and common_len < min_len) {
        common_len = last_sep;
    }

    // Count directories to go up from 'from'
    var up_count: usize = 0;
    for (from_slice[common_len..]) |c| {
        if (c == '/') up_count += 1;
    }
    // If from doesn't end with /, count the last component
    if (from_slice.len > common_len and from_slice[from_slice.len - 1] != '/') {
        up_count += 1;
    }

    // Build result
    var pos: usize = 0;

    // Add "../" for each directory to go up
    for (0..up_count) |_| {
        if (pos + 3 > buf_len) return 0;
        buf[pos] = '.';
        buf[pos + 1] = '.';
        buf[pos + 2] = '/';
        pos += 3;
    }

    // Add remaining path from 'to'
    const remaining = to_slice[common_len..];
    if (remaining.len > 0) {
        // Skip leading slash
        const start: usize = if (remaining[0] == '/') 1 else 0;
        const to_copy = remaining[start..];
        if (pos + to_copy.len > buf_len) return 0;
        @memcpy(buf[pos .. pos + to_copy.len], to_copy);
        pos += to_copy.len;
    }

    // Handle empty result
    if (pos == 0) {
        if (buf_len > 0) {
            buf[0] = '.';
            return 1;
        }
        return 0;
    }

    // Remove trailing slash if present
    if (pos > 0 and buf[pos - 1] == '/') {
        pos -= 1;
    }

    return pos;
}

// ============================================================================
// Helper Functions
// ============================================================================

fn copyToBuf(src: []const u8, buf: [*]u8, buf_len: usize) usize {
    const copy_len = @min(src.len, buf_len);
    if (copy_len > 0) {
        @memcpy(buf[0..copy_len], src[0..copy_len]);
    }
    return copy_len;
}
