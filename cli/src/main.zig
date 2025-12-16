const std = @import("std");
const builtin = @import("builtin");

const build_cmd = @import("build_cmd.zig");
const new_cmd = @import("new_cmd.zig");
const run_cmd = @import("run_cmd.zig");

const version = "0.1.0";

const logo =
    \\ 
    \\[36m┌┬┐┌─┐┬ ┬┌─┐┬─┐┌┬┐[0m
    \\[36m││││  ├─┤├─┤├┬┘│││[0m
    \\[36m┴ ┴└─┘┴ ┴┴ ┴┴└─┴ ┴[0m
    \\[2mμcharm - Beautiful CLIs with MicroPython[0m
    \\
    \\
;

const usage =
    \\[1mUSAGE:[0m
    \\    mcharm <command> [options]
    \\
    \\[1mCOMMANDS:[0m
    \\    build    Build a standalone executable
    \\    new      Create a new μcharm project
    \\    run      Run a script with micropython
    \\
    \\[1mOPTIONS:[0m
    \\    -h, --help       Show this help message
    \\    -v, --version    Show version
    \\
    \\[1mEXAMPLES:[0m
    \\    mcharm new "My App"
    \\    mcharm run myapp.py
    \\    mcharm build myapp.py -o myapp
    \\    mcharm build myapp.py -o app --mode universal
    \\
    \\
;

// Helper for stdout/stderr in Zig 0.15
fn stdout() std.fs.File {
    return std.fs.File{ .handle = std.posix.STDOUT_FILENO };
}

fn stderr() std.fs.File {
    return std.fs.File{ .handle = std.posix.STDERR_FILENO };
}

fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = stdout().write(msg) catch {};
}

fn eprint(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = stderr().write(msg) catch {};
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printLogo();
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "-h") or std.mem.eql(u8, command, "--help")) {
        printLogo();
        printUsage();
        return;
    }

    if (std.mem.eql(u8, command, "-v") or std.mem.eql(u8, command, "--version")) {
        print("mcharm {s}\n", .{version});
        return;
    }

    if (std.mem.eql(u8, command, "build")) {
        try build_cmd.run(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "new")) {
        try new_cmd.run(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "run")) {
        try run_cmd.run(allocator, args[2..]);
    } else {
        eprint("\x1b[31mError:\x1b[0m Unknown command '{s}'\n", .{command});
        printUsage();
        std.process.exit(1);
    }
}

fn printLogo() void {
    _ = stdout().write(logo) catch {};
}

fn printUsage() void {
    _ = stdout().write(usage) catch {};
}
