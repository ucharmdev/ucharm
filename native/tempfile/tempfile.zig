const std = @import("std");
const fs = std.fs;
const posix = std.posix;

// Tempfile module - provides temporary file and directory operations
// using Zig's standard library

/// Get the system's temporary directory path
/// Returns the length written to output, or -1 on error
pub export fn tempfile_gettempdir(output: [*]u8, output_len: usize) i32 {
    // Try environment variables first
    const env_vars = [_][]const u8{ "TMPDIR", "TEMP", "TMP" };

    for (env_vars) |env_var| {
        if (posix.getenv(env_var)) |value| {
            if (value.len <= output_len) {
                @memcpy(output[0..value.len], value);
                return @intCast(value.len);
            }
        }
    }

    // Fall back to /tmp
    const default_tmp = "/tmp";
    if (default_tmp.len <= output_len) {
        @memcpy(output[0..default_tmp.len], default_tmp);
        return @intCast(default_tmp.len);
    }

    return -1;
}

/// Generate a unique filename
/// Returns the length written to output, or -1 on error
pub export fn tempfile_mktemp(
    prefix: [*]const u8,
    prefix_len: usize,
    suffix: [*]const u8,
    suffix_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const pfx = prefix[0..prefix_len];
    const sfx = suffix[0..suffix_len];

    // Get temp directory
    var tmpdir_buf: [4096]u8 = undefined;
    const tmpdir_len = tempfile_gettempdir(&tmpdir_buf, tmpdir_buf.len);
    if (tmpdir_len < 0) return -1;

    const tmpdir = tmpdir_buf[0..@intCast(tmpdir_len)];

    // Generate random component
    var random_buf: [8]u8 = undefined;
    std.crypto.random.bytes(&random_buf);

    // Format as hex
    var hex_buf: [16]u8 = undefined;
    _ = std.fmt.bufPrint(&hex_buf, "{x:0>16}", .{std.mem.readInt(u64, &random_buf, .little)}) catch return -1;

    // Build the path
    const result = std.fmt.bufPrint(output[0..output_len], "{s}/{s}{s}{s}", .{
        tmpdir,
        pfx,
        hex_buf[0..8],
        sfx,
    }) catch return -1;

    return @intCast(result.len);
}

/// Create a temporary file and return its path
/// The file is created with exclusive access
/// Returns the length written to output, or -1 on error
pub export fn tempfile_mkstemp(
    prefix: [*]const u8,
    prefix_len: usize,
    suffix: [*]const u8,
    suffix_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    // Generate a temp filename
    const path_len = tempfile_mktemp(prefix, prefix_len, suffix, suffix_len, output, output_len);
    if (path_len < 0) return -1;

    const path = output[0..@intCast(path_len)];

    // Try to create the file exclusively
    const file = fs.cwd().createFile(path, .{
        .exclusive = true,
        .mode = 0o600, // rw------- permissions
    }) catch {
        // If failed, try again with different random
        const retry_len = tempfile_mktemp(prefix, prefix_len, suffix, suffix_len, output, output_len);
        if (retry_len < 0) return -1;

        const retry_path = output[0..@intCast(retry_len)];
        _ = fs.cwd().createFile(retry_path, .{
            .exclusive = true,
            .mode = 0o600,
        }) catch return -1;

        return retry_len;
    };
    file.close();

    return path_len;
}

/// Create a temporary directory and return its path
/// Returns the length written to output, or -1 on error
pub export fn tempfile_mkdtemp(
    prefix: [*]const u8,
    prefix_len: usize,
    suffix: [*]const u8,
    suffix_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    // Generate a temp path
    const path_len = tempfile_mktemp(prefix, prefix_len, suffix, suffix_len, output, output_len);
    if (path_len < 0) return -1;

    const path = output[0..@intCast(path_len)];

    // Create the directory
    fs.cwd().makeDir(path) catch {
        // If failed, try again with different random
        const retry_len = tempfile_mktemp(prefix, prefix_len, suffix, suffix_len, output, output_len);
        if (retry_len < 0) return -1;

        const retry_path = output[0..@intCast(retry_len)];
        fs.cwd().makeDir(retry_path) catch return -1;

        return retry_len;
    };

    return path_len;
}

/// Delete a file
/// Returns 0 on success, -1 on error
pub export fn tempfile_unlink(path: [*]const u8, path_len: usize) i32 {
    const p = path[0..path_len];
    fs.cwd().deleteFile(p) catch return -1;
    return 0;
}

/// Delete a directory (must be empty)
/// Returns 0 on success, -1 on error
pub export fn tempfile_rmdir(path: [*]const u8, path_len: usize) i32 {
    const p = path[0..path_len];
    fs.cwd().deleteDir(p) catch return -1;
    return 0;
}

/// Delete a directory tree (recursive)
/// Returns 0 on success, -1 on error
pub export fn tempfile_rmtree(path: [*]const u8, path_len: usize) i32 {
    const p = path[0..path_len];
    fs.cwd().deleteTree(p) catch return -1;
    return 0;
}
