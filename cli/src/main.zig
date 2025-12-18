const std = @import("std");
const builtin = @import("builtin");

const build_cmd = @import("build_cmd.zig");
const init_cmd = @import("init_cmd.zig");
const new_cmd = @import("new_cmd.zig");
const run_cmd = @import("run_cmd.zig");
const test_cmd = @import("test_cmd.zig");
const style = @import("style.zig");
const tui = @import("tui");

// Version is read from VERSION file at compile time
const version_raw = @embedFile("VERSION");
const version = std.mem.trim(u8, version_raw, " \t\n\r");

// Branded logo with visual flair - uses shared tui library
fn printLogo() void {
    const out = stdout();

    // Use comptime box characters for rounded style
    const box = comptime tui.getBoxChars(.rounded);

    // Box dimensions
    const tagline = "Beautiful CLIs with MicroPython";
    const box_width = tagline.len + 6; // 37

    _ = out.write("\n") catch return;

    // Top border
    _ = out.write(tui.ansi.cyan ++ tui.ansi.bold ++ "  " ++ box.tl) catch return;
    for (0..box_width) |_| _ = out.write(box.h) catch return;
    _ = out.write(box.tr ++ "\n" ++ tui.ansi.reset) catch return;

    // Title line: center "μcharm vX.Y.Z"
    const title_visible_len = 8 + version.len; // "μcharm v" + version
    const title_pad_total = box_width - title_visible_len;
    const title_pad_left = title_pad_total / 2;
    const title_pad_right = title_pad_total - title_pad_left;

    _ = out.write(tui.ansi.cyan ++ tui.ansi.bold ++ "  " ++ box.v ++ tui.ansi.reset) catch return;
    for (0..title_pad_left) |_| _ = out.write(" ") catch return;
    _ = out.write(tui.ansi.cyan ++ tui.ansi.bold ++ "\xce\xbc" ++ "charm" ++ tui.ansi.reset ++ " " ++ tui.ansi.dim ++ "v") catch return;
    _ = out.write(version) catch return;
    _ = out.write(tui.ansi.reset) catch return;
    for (0..title_pad_right) |_| _ = out.write(" ") catch return;
    _ = out.write(tui.ansi.cyan ++ tui.ansi.bold ++ box.v ++ "\n" ++ tui.ansi.reset) catch return;

    // Tagline line: center tagline
    const tagline_pad_total = box_width - tagline.len;
    const tagline_pad_left = tagline_pad_total / 2;
    const tagline_pad_right = tagline_pad_total - tagline_pad_left;

    _ = out.write(tui.ansi.cyan ++ tui.ansi.bold ++ "  " ++ box.v ++ tui.ansi.reset) catch return;
    for (0..tagline_pad_left) |_| _ = out.write(" ") catch return;
    _ = out.write(tui.ansi.dim ++ tagline ++ tui.ansi.reset) catch return;
    for (0..tagline_pad_right) |_| _ = out.write(" ") catch return;
    _ = out.write(tui.ansi.cyan ++ tui.ansi.bold ++ box.v ++ "\n" ++ tui.ansi.reset) catch return;

    // Bottom border
    _ = out.write(tui.ansi.cyan ++ tui.ansi.bold ++ "  " ++ box.bl) catch return;
    for (0..box_width) |_| _ = out.write(box.h) catch return;
    _ = out.write(box.br ++ "\n" ++ tui.ansi.reset) catch return;

    _ = out.write("\n") catch return;
}

const usage =
    \\[1mUSAGE[0m
    \\    ucharm [36m<command>[0m [options]
    \\
    \\[1mCOMMANDS[0m
    \\    [36mnew[0m [2m<name>[0m        Create a new project
    \\    [36mrun[0m [2m<file>[0m        Run a script with micropython
    \\    [36mbuild[0m [2m<file>[0m      Build a standalone binary
    \\    [36minit[0m              Initialize ucharm in current directory
    \\    [36mtest[0m              Run compatibility tests
    \\
    \\[1mOPTIONS[0m
    \\    [36m-h[0m, [36m--help[0m        Show this help
    \\    [36m-v[0m, [36m--version[0m     Show version
    \\
    \\[1mEXAMPLES[0m
    \\    [2m$[0m ucharm new myapp                  [2m# Create new project[0m
    \\    [2m$[0m ucharm run app.py                 [2m# Run with micropython[0m
    \\    [2m$[0m ucharm build app.py -o app        [2m# Build universal binary[0m
    \\    [2m$[0m ucharm init --stubs --ai claude   [2m# Add IDE support[0m
    \\
    \\[2m    Docs: https://github.com/ucharmdev/ucharm[0m
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
        print(tui.ansi.cyan ++ tui.ansi.bold ++ "\xce\xbc" ++ "charm" ++ tui.ansi.reset ++ " " ++ tui.ansi.dim ++ "v{s}" ++ tui.ansi.reset ++ "\n", .{version});
        return;
    }

    if (std.mem.eql(u8, command, "build")) {
        try build_cmd.run(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "init")) {
        try init_cmd.run(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "new")) {
        try new_cmd.run(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "run")) {
        try run_cmd.run(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "test")) {
        try test_cmd.run(allocator, args[2..]);
    } else {
        eprint(style.err_prefix ++ "Unknown command '" ++ style.bold ++ "{s}" ++ style.reset ++ "'\n", .{command});
        eprint(style.dim ++ "Run '" ++ style.reset ++ "ucharm --help" ++ style.dim ++ "' for usage." ++ style.reset ++ "\n", .{});
        std.process.exit(1);
    }
}

fn printUsage() void {
    _ = stdout().write(usage) catch {};
}
