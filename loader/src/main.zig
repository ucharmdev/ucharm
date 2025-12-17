const std = @import("std");
const Trailer = @import("trailer.zig").Trailer;
const executor = @import("executor.zig");

/// μcharm Universal Binary Loader
///
/// This is a tiny native executable that reads embedded data from itself:
/// - MicroPython interpreter binary
/// - Python application code
///
/// Binary format:
/// [Loader stub][MicroPython binary][Python code][48-byte Trailer]
///
/// On execution:
/// 1. Read self executable path
/// 2. Seek to end and read trailer (offsets + sizes)
/// 3. Extract MicroPython binary (memfd on Linux, /tmp on macOS)
/// 4. Extract Python code
/// 5. execve MicroPython with Python code as argument
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get path to self executable
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const self_path = try std.fs.selfExePath(&path_buf);

    // Open self executable
    const self_file = try std.fs.openFileAbsolute(self_path, .{});
    defer self_file.close();

    // Get file size and seek to trailer
    const stat = try self_file.stat();
    const file_size = stat.size;

    if (file_size < Trailer.SIZE) {
        std.debug.print("ucharm: invalid binary (too small)\n", .{});
        std.process.exit(1);
    }

    try self_file.seekTo(file_size - Trailer.SIZE);

    // Read and parse trailer
    const trailer = Trailer.readFromFile(self_file) catch {
        std.debug.print("ucharm: invalid binary (bad trailer)\n", .{});
        std.process.exit(1);
    };

    if (!trailer.isValid()) {
        std.debug.print("ucharm: invalid binary (bad trailer values)\n", .{});
        std.process.exit(1);
    }

    // Calculate content hash for caching
    const content_hash = try executor.calculateHash(self_file, trailer);

    // Prepare execution context (extract files)
    var ctx = try executor.prepare(allocator, self_file, trailer, content_hash);
    defer ctx.cleanup(allocator);

    // Get command-line arguments (skip argv[0])
    const args = std.os.argv;
    const user_args = if (args.len > 1) args[1..] else &[_][*:0]const u8{};

    // Execute! (does not return)
    executor.exec(allocator, ctx, user_args);
}
