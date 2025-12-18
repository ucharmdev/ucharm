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

// Usage text with proper ANSI escape codes
const bold = tui.ansi.bold;
const cyan = tui.ansi.cyan;
const dim = tui.ansi.dim;
const reset = tui.ansi.reset;

const usage =
    bold ++ "USAGE" ++ reset ++ "\n" ++
    "    ucharm " ++ cyan ++ "<command>" ++ reset ++ " [options]\n" ++
    "\n" ++
    bold ++ "COMMANDS" ++ reset ++ "\n" ++
    "    " ++ cyan ++ "new" ++ reset ++ " " ++ dim ++ "<name>" ++ reset ++ "        Create a new project\n" ++
    "    " ++ cyan ++ "run" ++ reset ++ " " ++ dim ++ "<file>" ++ reset ++ "        Run a script with micropython\n" ++
    "    " ++ cyan ++ "build" ++ reset ++ " " ++ dim ++ "<file>" ++ reset ++ "      Build a standalone binary\n" ++
    "    " ++ cyan ++ "init" ++ reset ++ "              Initialize ucharm in current directory\n" ++
    "    " ++ cyan ++ "test" ++ reset ++ "              Run compatibility tests\n" ++
    "\n" ++
    bold ++ "OPTIONS" ++ reset ++ "\n" ++
    "    " ++ cyan ++ "-h" ++ reset ++ ", " ++ cyan ++ "--help" ++ reset ++ "        Show this help\n" ++
    "    " ++ cyan ++ "-v" ++ reset ++ ", " ++ cyan ++ "--version" ++ reset ++ "     Show version\n" ++
    "\n" ++
    bold ++ "EXAMPLES" ++ reset ++ "\n" ++
    "    " ++ dim ++ "$" ++ reset ++ " ucharm new myapp                  " ++ dim ++ "# Create new project" ++ reset ++ "\n" ++
    "    " ++ dim ++ "$" ++ reset ++ " ucharm run app.py                 " ++ dim ++ "# Run with micropython" ++ reset ++ "\n" ++
    "    " ++ dim ++ "$" ++ reset ++ " ucharm build app.py -o app        " ++ dim ++ "# Build universal binary" ++ reset ++ "\n" ++
    "    " ++ dim ++ "$" ++ reset ++ " ucharm init --stubs --ai claude   " ++ dim ++ "# Add IDE support" ++ reset ++ "\n" ++
    "\n" ++
    dim ++ "    Docs: https://github.com/ucharmdev/ucharm" ++ reset ++ "\n";

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
