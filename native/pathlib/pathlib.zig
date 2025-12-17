const std = @import("std");
const fs = std.fs;
const mem = std.mem;

// Pathlib module - provides path manipulation and filesystem operations

/// Get the basename (final component) of a path
pub export fn path_basename(
    path: [*]const u8,
    path_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const p = path[0..path_len];

    // Handle special cases
    if (p.len == 0) return 0;
    if (mem.eql(u8, p, ".")) return 0;

    // Find last separator
    var last_sep: ?usize = null;
    for (p, 0..) |c, i| {
        if (c == '/') last_sep = i;
    }

    const name = if (last_sep) |idx| p[idx + 1 ..] else p;

    if (name.len > output_len) return -1;
    @memcpy(output[0..name.len], name);
    return @intCast(name.len);
}

/// Get the directory name of a path
pub export fn path_dirname(
    path: [*]const u8,
    path_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const p = path[0..path_len];

    // Handle special cases
    if (p.len == 0) {
        if (output_len >= 1) {
            output[0] = '.';
            return 1;
        }
        return -1;
    }

    // Remove trailing slashes
    var end = p.len;
    while (end > 1 and p[end - 1] == '/') {
        end -= 1;
    }

    // Find last separator
    var last_sep: ?usize = null;
    for (p[0..end], 0..) |c, i| {
        if (c == '/') last_sep = i;
    }

    if (last_sep) |idx| {
        if (idx == 0) {
            // Root
            if (output_len >= 1) {
                output[0] = '/';
                return 1;
            }
            return -1;
        }
        if (idx > output_len) return -1;
        @memcpy(output[0..idx], p[0..idx]);
        return @intCast(idx);
    }

    // No separator, return "."
    if (output_len >= 1) {
        output[0] = '.';
        return 1;
    }
    return -1;
}

/// Get the file extension (suffix)
pub export fn path_extname(
    path: [*]const u8,
    path_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    // Get basename first
    var name_buf: [4096]u8 = undefined;
    const name_len = path_basename(path, path_len, &name_buf, name_buf.len);
    if (name_len <= 0) return 0;

    const name = name_buf[0..@intCast(name_len)];

    // Handle special case ".."
    if (mem.eql(u8, name, "..")) return 0;

    // Find last dot
    var last_dot: ?usize = null;
    for (name, 0..) |c, i| {
        if (c == '.') last_dot = i;
    }

    if (last_dot) |idx| {
        if (idx == 0) return 0; // Hidden file like ".bashrc"
        const ext = name[idx..];
        if (ext.len > output_len) return -1;
        @memcpy(output[0..ext.len], ext);
        return @intCast(ext.len);
    }

    return 0;
}

/// Get the stem (name without suffix)
pub export fn path_stem(
    path: [*]const u8,
    path_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    // Get basename first
    var name_buf: [4096]u8 = undefined;
    const name_len = path_basename(path, path_len, &name_buf, name_buf.len);
    if (name_len <= 0) return 0;

    const name = name_buf[0..@intCast(name_len)];

    // Handle special case ".."
    if (mem.eql(u8, name, "..")) {
        if (output_len >= 2) {
            @memcpy(output[0..2], "..");
            return 2;
        }
        return -1;
    }

    // Find last dot
    var last_dot: ?usize = null;
    for (name, 0..) |c, i| {
        if (c == '.') last_dot = i;
    }

    if (last_dot) |idx| {
        if (idx == 0) {
            // Hidden file, no extension
            if (name.len > output_len) return -1;
            @memcpy(output[0..name.len], name);
            return @intCast(name.len);
        }
        const stem = name[0..idx];
        if (stem.len > output_len) return -1;
        @memcpy(output[0..stem.len], stem);
        return @intCast(stem.len);
    }

    // No extension
    if (name.len > output_len) return -1;
    @memcpy(output[0..name.len], name);
    return @intCast(name.len);
}

/// Check if path is absolute
pub export fn path_is_absolute(path: [*]const u8, path_len: usize) i32 {
    if (path_len == 0) return 0;
    return if (path[0] == '/') 1 else 0;
}

/// Join two paths
pub export fn path_join(
    path1: [*]const u8,
    path1_len: usize,
    path2: [*]const u8,
    path2_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const p1 = path1[0..path1_len];
    const p2 = path2[0..path2_len];

    // If path2 is absolute, return it
    if (path2_len > 0 and path2[0] == '/') {
        if (p2.len > output_len) return -1;
        @memcpy(output[0..p2.len], p2);
        return @intCast(p2.len);
    }

    // If path1 is empty, return path2
    if (path1_len == 0) {
        if (p2.len > output_len) return -1;
        @memcpy(output[0..p2.len], p2);
        return @intCast(p2.len);
    }

    // Check if we need a separator
    const need_sep = p1[p1.len - 1] != '/';
    const total_len = p1.len + (if (need_sep) @as(usize, 1) else 0) + p2.len;

    if (total_len > output_len) return -1;

    var pos: usize = 0;
    @memcpy(output[0..p1.len], p1);
    pos = p1.len;

    if (need_sep) {
        output[pos] = '/';
        pos += 1;
    }

    @memcpy(output[pos..][0..p2.len], p2);

    return @intCast(total_len);
}

/// Normalize a path (remove . and ..)
pub export fn path_normalize(
    path: [*]const u8,
    path_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const p = path[0..path_len];

    if (p.len == 0) {
        if (output_len >= 1) {
            output[0] = '.';
            return 1;
        }
        return -1;
    }

    var parts: [256][]const u8 = undefined;
    var part_count: usize = 0;
    const is_abs = p[0] == '/';

    // Split by /
    var iter = mem.splitSequence(u8, p, "/");
    while (iter.next()) |part| {
        if (part.len == 0 or mem.eql(u8, part, ".")) {
            continue;
        }
        if (mem.eql(u8, part, "..")) {
            if (part_count > 0 and !mem.eql(u8, parts[part_count - 1], "..")) {
                part_count -= 1;
            } else if (!is_abs) {
                parts[part_count] = part;
                part_count += 1;
            }
        } else {
            parts[part_count] = part;
            part_count += 1;
        }
    }

    // Reconstruct path
    var pos: usize = 0;

    if (is_abs) {
        if (pos >= output_len) return -1;
        output[pos] = '/';
        pos += 1;
    }

    for (parts[0..part_count], 0..) |part, i| {
        if (i > 0) {
            if (pos >= output_len) return -1;
            output[pos] = '/';
            pos += 1;
        }
        if (pos + part.len > output_len) return -1;
        @memcpy(output[pos..][0..part.len], part);
        pos += part.len;
    }

    if (pos == 0) {
        output[0] = '.';
        return 1;
    }

    return @intCast(pos);
}

// ============================================================================
// Filesystem operations
// ============================================================================

/// Check if path exists
pub export fn path_exists(path: [*]const u8, path_len: usize) i32 {
    const p = path[0..path_len];

    // Try as file
    _ = fs.cwd().statFile(p) catch {
        // Try as directory
        var dir = fs.cwd().openDir(p, .{}) catch return 0;
        dir.close();
        return 1;
    };

    return 1;
}

/// Check if path is a file
pub export fn path_is_file(path: [*]const u8, path_len: usize) i32 {
    const p = path[0..path_len];

    const stat = fs.cwd().statFile(p) catch return 0;
    return if (stat.kind == .file) 1 else 0;
}

/// Check if path is a directory
pub export fn path_is_dir(path: [*]const u8, path_len: usize) i32 {
    const p = path[0..path_len];

    var dir = fs.cwd().openDir(p, .{}) catch return 0;
    dir.close();
    return 1;
}

/// Get file size
pub export fn path_getsize(path: [*]const u8, path_len: usize) i64 {
    const p = path[0..path_len];

    const stat = fs.cwd().statFile(p) catch return -1;
    return @intCast(stat.size);
}

/// Get current working directory
pub export fn path_getcwd(output: [*]u8, output_len: usize) i32 {
    const cwd = fs.cwd().realpathAlloc(std.heap.page_allocator, ".") catch return -1;
    defer std.heap.page_allocator.free(cwd);

    if (cwd.len > output_len) return -1;
    @memcpy(output[0..cwd.len], cwd);
    return @intCast(cwd.len);
}
