const std = @import("std");
pub const style = @import("style.zig");

// Helper for stdout/stderr in Zig 0.15
pub fn stdout() std.fs.File {
    return std.fs.File{ .handle = std.posix.STDOUT_FILENO };
}

pub fn stderr() std.fs.File {
    return std.fs.File{ .handle = std.posix.STDERR_FILENO };
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [8192]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = stdout().write(msg) catch {};
}

pub fn eprint(comptime fmt: []const u8, args: anytype) void {
    var buf: [8192]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = stderr().write(msg) catch {};
}

pub fn puts(s: []const u8) void {
    _ = stdout().write(s) catch {};
}
