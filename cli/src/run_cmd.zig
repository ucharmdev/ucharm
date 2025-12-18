const std = @import("std");
const fs = std.fs;
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const io = @import("io.zig");

// Embedded micropython binary with native modules
const micropython_macos_aarch64 = @embedFile("stubs/micropython-ucharm-macos-aarch64");

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

    // Extract embedded micropython
    const mpy_path = extractMicropython(allocator) catch {
        io.eprint("\x1b[31mError:\x1b[0m Failed to extract micropython\n", .{});
        std.process.exit(1);
    };
    defer allocator.free(mpy_path);

    // Transform script to use native modules instead of ucharm package
    const transformed_path = transformScript(allocator, script) catch {
        io.eprint("\x1b[31mError:\x1b[0m Failed to transform script\n", .{});
        std.process.exit(1);
    };
    defer allocator.free(transformed_path);

    // Build argv
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);

    try argv.append(allocator, mpy_path);
    try argv.append(allocator, transformed_path);

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

    // Clean up temp script
    fs.deleteFileAbsolute(transformed_path) catch {};

    switch (result) {
        .Exited => |code| std.process.exit(code),
        .Signal => |sig| std.process.exit(128 + @as(u8, @intCast(sig))),
        else => std.process.exit(1),
    }
}

fn extractMicropython(allocator: Allocator) ![]const u8 {
    // Select the right binary for this platform
    const mpy_binary = switch (builtin.target.os.tag) {
        .macos => switch (builtin.target.cpu.arch) {
            .aarch64 => micropython_macos_aarch64,
            else => return error.UnsupportedPlatform,
        },
        else => return error.UnsupportedPlatform,
    };

    // Create a hash-based cache directory
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(mpy_binary);
    const hash = hasher.final();

    var hash_str: [16]u8 = undefined;
    _ = std.fmt.bufPrint(&hash_str, "{x:0>16}", .{hash}) catch unreachable;

    const cache_dir = try std.fmt.allocPrint(allocator, "/tmp/ucharm-{s}", .{hash_str});
    defer allocator.free(cache_dir);

    const mpy_path = try std.fmt.allocPrint(allocator, "/tmp/ucharm-{s}/micropython", .{hash_str});

    // Check if already cached
    if (fs.accessAbsolute(mpy_path, .{})) |_| {
        return mpy_path;
    } else |_| {}

    // Create cache directory
    fs.makeDirAbsolute(cache_dir) catch |err| {
        if (err != error.PathAlreadyExists) {
            allocator.free(mpy_path);
            return err;
        }
    };

    // Write micropython binary
    const file = try fs.createFileAbsolute(mpy_path, .{ .mode = 0o755 });
    defer file.close();
    try file.writeAll(mpy_binary);

    return mpy_path;
}

fn transformScript(allocator: Allocator, script_path: []const u8) ![]const u8 {
    // Read the user's script
    const script_content = try fs.cwd().readFileAlloc(allocator, script_path, 1024 * 1024);
    defer allocator.free(script_content);

    // Build output
    var output_buffer: std.ArrayList(u8) = .empty;
    defer output_buffer.deinit(allocator);

    // Header
    try output_buffer.appendSlice(allocator, "#!/usr/bin/env micropython\n");
    try output_buffer.appendSlice(allocator, "# Transformed by ucharm run\n\n");

    // Always add native module imports (simpler and more robust)
    try output_buffer.appendSlice(allocator, "from charm import style, box, rule, success, error, warning, info, progress, spinner_frame, visible_len\n");
    try output_buffer.appendSlice(allocator, "from input import select, multiselect, confirm, prompt, password\n");
    try output_buffer.appendSlice(allocator, "\n");

    // Stub out missing functions that demo.py uses
    try output_buffer.appendSlice(allocator, "# Stubs for functions not yet in native modules\n");
    try output_buffer.appendSlice(allocator, "def spinner(msg, duration=1): pass\n");
    try output_buffer.appendSlice(allocator, "def table(data, headers=None, header_style=None): pass\n");
    try output_buffer.appendSlice(allocator, "def key_value(data): pass\n");
    try output_buffer.appendSlice(allocator, "class Color: pass\n");
    try output_buffer.appendSlice(allocator, "\n");

    // Process lines and skip ucharm imports (including multiline)
    var in_multiline_import = false;
    var lines = std.mem.splitSequence(u8, script_content, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");

        // Handle multiline imports
        if (in_multiline_import) {
            // Check if this line ends the multiline import
            if (std.mem.indexOf(u8, line, ")") != null) {
                in_multiline_import = false;
            }
            continue;
        }

        // Skip ucharm imports
        if (std.mem.startsWith(u8, trimmed, "from ucharm import") or
            std.mem.startsWith(u8, trimmed, "from ucharm.") or
            std.mem.startsWith(u8, trimmed, "import ucharm"))
        {
            // Check if this starts a multiline import
            if (std.mem.indexOf(u8, line, "(") != null and std.mem.indexOf(u8, line, ")") == null) {
                in_multiline_import = true;
            }
            continue;
        }

        // Skip sys.path modifications
        if (std.mem.indexOf(u8, line, "sys.path") != null) {
            continue;
        }

        try output_buffer.appendSlice(allocator, line);
        try output_buffer.append(allocator, '\n');
    }

    // Write to temp file
    const temp_path = "/tmp/ucharm_run.py";
    const temp_file = try fs.createFileAbsolute(temp_path, .{});
    defer temp_file.close();
    try temp_file.writeAll(output_buffer.items);

    return try allocator.dupe(u8, temp_path);
}
