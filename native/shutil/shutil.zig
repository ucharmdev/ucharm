const std = @import("std");
const fs = std.fs;

// Shutil module - provides high-level file operations
// using Zig's standard library

/// Copy a file from src to dst
/// Returns 0 on success, -1 on error
pub export fn shutil_copy(
    src: [*]const u8,
    src_len: usize,
    dst: [*]const u8,
    dst_len: usize,
) i32 {
    const src_path = src[0..src_len];
    const dst_path = dst[0..dst_len];

    // Open source file
    const src_file = fs.cwd().openFile(src_path, .{}) catch return -1;
    defer src_file.close();

    // Create destination file
    const dst_file = fs.cwd().createFile(dst_path, .{}) catch return -1;
    defer dst_file.close();

    // Copy contents
    var buf: [8192]u8 = undefined;
    while (true) {
        const bytes_read = src_file.read(&buf) catch return -1;
        if (bytes_read == 0) break;
        _ = dst_file.writeAll(buf[0..bytes_read]) catch return -1;
    }

    return 0;
}

/// Copy file with metadata (permissions) - same as copy for now
/// Returns 0 on success, -1 on error
pub export fn shutil_copy2(
    src: [*]const u8,
    src_len: usize,
    dst: [*]const u8,
    dst_len: usize,
) i32 {
    return shutil_copy(src, src_len, dst, dst_len);
}

/// Move/rename a file or directory
/// Returns 0 on success, -1 on error
pub export fn shutil_move(
    src: [*]const u8,
    src_len: usize,
    dst: [*]const u8,
    dst_len: usize,
) i32 {
    const src_path = src[0..src_len];
    const dst_path = dst[0..dst_len];

    // Try rename first (fast, same filesystem)
    fs.cwd().rename(src_path, dst_path) catch {
        // If rename fails (cross-filesystem), try copy + delete
        // First check if it's a directory
        const stat = fs.cwd().statFile(src_path) catch return -1;

        if (stat.kind == .directory) {
            // For directories, we'd need recursive copy - complex
            // For now, just fail
            return -1;
        }

        // Copy the file
        if (shutil_copy(src, src_len, dst, dst_len) < 0) return -1;

        // Delete the source
        fs.cwd().deleteFile(src_path) catch {
            // Try to clean up the copy
            fs.cwd().deleteFile(dst_path) catch {};
            return -1;
        };
    };

    return 0;
}

/// Remove a directory tree recursively
/// Returns 0 on success, -1 on error
pub export fn shutil_rmtree(
    path: [*]const u8,
    path_len: usize,
) i32 {
    const p = path[0..path_len];
    fs.cwd().deleteTree(p) catch return -1;
    return 0;
}

/// Create a directory and all parent directories
/// Returns 0 on success, -1 on error
pub export fn shutil_makedirs(
    path: [*]const u8,
    path_len: usize,
) i32 {
    const p = path[0..path_len];
    fs.cwd().makePath(p) catch return -1;
    return 0;
}

/// Check if a path exists
/// Returns 1 if exists, 0 if not
pub export fn shutil_exists(
    path: [*]const u8,
    path_len: usize,
) i32 {
    const p = path[0..path_len];

    _ = fs.cwd().statFile(p) catch {
        // Try as directory
        var dir = fs.cwd().openDir(p, .{}) catch return 0;
        dir.close();
        return 1;
    };

    return 1;
}

/// Check if path is a file
/// Returns 1 if file, 0 if not
pub export fn shutil_isfile(
    path: [*]const u8,
    path_len: usize,
) i32 {
    const p = path[0..path_len];

    const stat = fs.cwd().statFile(p) catch return 0;
    if (stat.kind == .file) {
        return 1;
    }
    return 0;
}

/// Check if path is a directory
/// Returns 1 if directory, 0 if not
pub export fn shutil_isdir(
    path: [*]const u8,
    path_len: usize,
) i32 {
    const p = path[0..path_len];

    var dir = fs.cwd().openDir(p, .{}) catch return 0;
    dir.close();
    return 1;
}

/// Get file size in bytes
/// Returns size on success, -1 on error
pub export fn shutil_getsize(
    path: [*]const u8,
    path_len: usize,
) i64 {
    const p = path[0..path_len];

    const stat = fs.cwd().statFile(p) catch return -1;
    return @intCast(stat.size);
}

/// Copy directory tree recursively
/// Returns 0 on success, -1 on error
pub export fn shutil_copytree(
    src: [*]const u8,
    src_len: usize,
    dst: [*]const u8,
    dst_len: usize,
) i32 {
    const src_path = src[0..src_len];
    const dst_path = dst[0..dst_len];

    copyTreeImpl(src_path, dst_path) catch return -1;
    return 0;
}

fn copyTreeImpl(src_path: []const u8, dst_path: []const u8) !void {
    // Create destination directory
    fs.cwd().makePath(dst_path) catch {};

    // Open source directory
    var src_dir = try fs.cwd().openDir(src_path, .{ .iterate = true });
    defer src_dir.close();

    // Iterate and copy
    var iter = src_dir.iterate();
    while (try iter.next()) |entry| {
        var src_buf: [4096]u8 = undefined;
        var dst_buf: [4096]u8 = undefined;

        const src_full = try std.fmt.bufPrint(&src_buf, "{s}/{s}", .{ src_path, entry.name });
        const dst_full = try std.fmt.bufPrint(&dst_buf, "{s}/{s}", .{ dst_path, entry.name });

        switch (entry.kind) {
            .file => {
                // Copy file manually
                const src_file = fs.cwd().openFile(src_full, .{}) catch continue;
                defer src_file.close();

                const dst_file = fs.cwd().createFile(dst_full, .{}) catch continue;
                defer dst_file.close();

                var buf: [8192]u8 = undefined;
                while (true) {
                    const bytes_read = src_file.read(&buf) catch break;
                    if (bytes_read == 0) break;
                    _ = dst_file.writeAll(buf[0..bytes_read]) catch break;
                }
            },
            .directory => {
                // Recurse
                try copyTreeImpl(src_full, dst_full);
            },
            else => {
                // Skip symlinks and special files for now
            },
        }
    }
}
