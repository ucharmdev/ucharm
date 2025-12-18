const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const io = @import("io.zig");

const logo =
    \\ 
    \\[36m┌┬┐┌─┐┬ ┬┌─┐┬─┐┌┬┐[0m
    \\[36m││││  ├─┤├─┤├┬┘│││[0m
    \\[36m┴ ┴└─┘┴ ┴┴ ┴┴└─┴ ┴[0m
    \\[2mμcharm - Beautiful CLIs with MicroPython[0m
    \\
    \\
;

const template =
    \\#!/usr/bin/env micropython
    \\"""
    \\{s} - Built with μcharm
    \\"""
    \\import sys
    \\sys.path.insert(0, ".")  # Adjust path to ucharm
    \\
    \\from ucharm import (
    \\    style, box, spinner, progress,
    \\    success, error, warning, info,
    \\    select, confirm, prompt
    \\)
    \\from ucharm.table import table, key_value
    \\import time
    \\
    \\
    \\def main():
    \\    box(
    \\        "{s}\n"
    \\        "Built with μcharm",
    \\        title="Welcome",
    \\        border_color="cyan"
    \\    )
    \\    print()
    \\    
    \\    choice = select("What would you like to do?", [
    \\        "Say hello",
    \\        "Show status",
    \\        "Exit"
    \\    ])
    \\    
    \\    if choice == "Say hello":
    \\        name = prompt("What's your name?", default="World")
    \\        print()
    \\        success("Hello, " + str(name) + "!")
    \\    elif choice == "Show status":
    \\        print()
    \\        spinner("Checking systems...", duration=1)
    \\        success("All systems operational")
    \\    else:
    \\        info("Goodbye!")
    \\
    \\
    \\if __name__ == "__main__":
    \\    main()
    \\
;

const help_text =
    \\[1mμcharm new[0m - Create a new μcharm project
    \\
    \\[2mUSAGE:[0m
    \\    ucharm new <name>
    \\
    \\[2mARGUMENTS:[0m
    \\    <name>    Project name (creates <name>.py)
    \\
    \\[2mEXAMPLES:[0m
    \\    ucharm new myapp
    \\    ucharm new "My CLI Tool"
    \\
;

pub fn run(allocator: Allocator, args: []const [:0]const u8) !void {
    if (args.len < 1) {
        io.eprint("\x1b[31mError:\x1b[0m No project name specified\n", .{});
        io.eprint("Usage: ucharm new <name>\n", .{});
        std.process.exit(1);
    }

    const name = args[0];

    // Handle --help / -h
    if (std.mem.eql(u8, name, "--help") or std.mem.eql(u8, name, "-h")) {
        _ = io.stdout().write(help_text) catch {};
        return;
    }

    // Convert name to filename (lowercase, underscores)
    var filename_buf: [256]u8 = undefined;
    var filename_len: usize = 0;

    for (name) |c| {
        if (c == ' ' or c == '-') {
            filename_buf[filename_len] = '_';
        } else if (c >= 'A' and c <= 'Z') {
            filename_buf[filename_len] = c + 32; // lowercase
        } else {
            filename_buf[filename_len] = c;
        }
        filename_len += 1;
        if (filename_len >= filename_buf.len - 4) break;
    }

    const filename_base = filename_buf[0..filename_len];

    // Create filename with .py extension
    var full_filename: [260]u8 = undefined;
    const filename = std.fmt.bufPrint(&full_filename, "{s}.py", .{filename_base}) catch {
        io.eprint("\x1b[31mError:\x1b[0m Filename too long\n", .{});
        std.process.exit(1);
    };

    // Check if file exists
    if (fs.cwd().access(filename, .{})) |_| {
        io.eprint("\x1b[31mError:\x1b[0m {s} already exists\n", .{filename});
        std.process.exit(1);
    } else |_| {}

    // Generate content
    var content_buf: [4096]u8 = undefined;
    const content = std.fmt.bufPrint(&content_buf, template, .{ name, name }) catch {
        io.eprint("\x1b[31mError:\x1b[0m Template error\n", .{});
        std.process.exit(1);
    };

    // Write file
    const file = try fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(content);

    // Make executable
    const file_for_chmod = try fs.cwd().openFile(filename, .{ .mode = .read_write });
    defer file_for_chmod.close();
    try file_for_chmod.chmod(0o755);

    // Print success
    _ = io.stdout().write(logo) catch {};
    io.print("Creating new project: \x1b[1m{s}\x1b[0m\n\n", .{name});
    io.print("\x1b[32mCreated:\x1b[0m {s}\n\n", .{filename});
    io.print("Run your app:\n", .{});
    io.print("  \x1b[36mmicropython {s}\x1b[0m\n\n", .{filename});
    io.print("Build standalone binary:\n", .{});
    io.print("  \x1b[36mucharm build {s} -o {s} --mode universal\x1b[0m\n", .{ filename, filename_base });

    _ = allocator;
}
