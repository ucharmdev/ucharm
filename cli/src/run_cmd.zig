const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const io = @import("io.zig");

pub fn run(allocator: Allocator, args: []const [:0]const u8) !void {
    if (args.len < 1) {
        io.eprint("\x1b[31mError:\x1b[0m No script specified\n", .{});
        io.eprint("Usage: ucharm run <script.py> [args...]\n", .{});
        std.process.exit(1);
    }

    const script = args[0];

    // Check if script exists
    fs.cwd().access(script, .{}) catch {
        io.eprint("\x1b[31mError:\x1b[0m Script not found: {s}\n", .{script});
        std.process.exit(1);
    };

    // Find micropython
    const mpy_path = findMicropython() catch {
        io.eprint("\x1b[31mError:\x1b[0m micropython not found\n", .{});
        std.process.exit(1);
    };

    // Build argv
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);

    try argv.append(allocator, mpy_path);
    try argv.append(allocator, script);

    // Add any additional arguments
    for (args[1..]) |arg| {
        try argv.append(allocator, arg);
    }

    // Execute micropython
    var child = std.process.Child.init(argv.items, allocator);
    child.spawn() catch |err| {
        io.eprint("\x1b[31mError:\x1b[0m Failed to spawn micropython: {}\n", .{err});
        std.process.exit(1);
    };

    const result = child.wait() catch |err| {
        io.eprint("\x1b[31mError:\x1b[0m Failed to wait for micropython: {}\n", .{err});
        std.process.exit(1);
    };

    switch (result) {
        .Exited => |code| std.process.exit(code),
        .Signal => |sig| std.process.exit(128 + @as(u8, @intCast(sig))),
        else => std.process.exit(1),
    }
}

fn findMicropython() ![]const u8 {
    const paths = [_][]const u8{
        "/opt/homebrew/bin/micropython",
        "/usr/local/bin/micropython",
        "/usr/bin/micropython",
    };

    for (paths) |path| {
        fs.accessAbsolute(path, .{}) catch continue;
        return path;
    }

    return error.NotFound;
}
