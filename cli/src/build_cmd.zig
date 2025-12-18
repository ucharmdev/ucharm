const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const io = @import("io.zig");
const builtin = @import("builtin");

// Embedded loader stubs for instant-startup universal binaries
const stub_macos_aarch64 = @embedFile("stubs/loader-macos-aarch64");
const stub_macos_x86_64 = @embedFile("stubs/loader-macos-x86_64");
const stub_linux_x86_64 = @embedFile("stubs/loader-linux-x86_64");
const stub_linux_aarch64 = @embedFile("stubs/loader-linux-aarch64");

// Embedded micropython-ucharm binaries (contains all native modules)
// Note: Only the host platform binary is embedded. Cross-compilation requires
// the target platform's micropython binary to be available in ~/.ucharm/runtimes/
const micropython_macos_aarch64 = @embedFile("stubs/micropython-ucharm-macos-aarch64");

// Trailer format constants (must match loader/src/trailer.zig)
const TRAILER_MAGIC: *const [8]u8 = "MCHARM01";
const TRAILER_SIZE: usize = 48;

// ANSI color codes
const dim = "\x1b[2m";
const bold = "\x1b[1m";
const cyan = "\x1b[36m";
const green = "\x1b[32m";
const yellow = "\x1b[33m";
const red = "\x1b[31m";
const reset = "\x1b[0m";

// Symbols
const check = "✓";
const arrow = "→";
const bullet = "•";

const Mode = enum {
    single,
    executable,
    universal,
};

const Target = enum {
    macos_aarch64,
    macos_x86_64,
    linux_x86_64,
    linux_aarch64,

    pub fn name(self: Target) []const u8 {
        return switch (self) {
            .macos_aarch64 => "macos-aarch64",
            .macos_x86_64 => "macos-x86_64",
            .linux_x86_64 => "linux-x86_64",
            .linux_aarch64 => "linux-aarch64",
        };
    }

    pub fn displayName(self: Target) []const u8 {
        return switch (self) {
            .macos_aarch64 => "macOS (Apple Silicon)",
            .macos_x86_64 => "macOS (Intel)",
            .linux_x86_64 => "Linux (x86_64)",
            .linux_aarch64 => "Linux (ARM64)",
        };
    }

    pub fn fromString(s: []const u8) ?Target {
        if (std.mem.eql(u8, s, "macos-aarch64") or std.mem.eql(u8, s, "macos-arm64")) {
            return .macos_aarch64;
        } else if (std.mem.eql(u8, s, "macos-x86_64") or std.mem.eql(u8, s, "macos-amd64")) {
            return .macos_x86_64;
        } else if (std.mem.eql(u8, s, "linux-x86_64") or std.mem.eql(u8, s, "linux-amd64")) {
            return .linux_x86_64;
        } else if (std.mem.eql(u8, s, "linux-aarch64") or std.mem.eql(u8, s, "linux-arm64")) {
            return .linux_aarch64;
        }
        return null;
    }

    pub fn fromHost() Target {
        const os = builtin.os.tag;
        const arch = builtin.cpu.arch;

        if (os == .macos) {
            if (arch == .aarch64) {
                return .macos_aarch64;
            } else {
                return .macos_x86_64;
            }
        } else {
            // Linux (and other Unix-like)
            if (arch == .aarch64) {
                return .linux_aarch64;
            } else {
                return .linux_x86_64;
            }
        }
    }

    pub fn loaderStub(self: Target) []const u8 {
        return switch (self) {
            .macos_aarch64 => stub_macos_aarch64,
            .macos_x86_64 => stub_macos_x86_64,
            .linux_x86_64 => stub_linux_x86_64,
            .linux_aarch64 => stub_linux_aarch64,
        };
    }

    pub fn micropythonFilename(self: Target) []const u8 {
        return switch (self) {
            .macos_aarch64 => "micropython-ucharm-macos-aarch64",
            .macos_x86_64 => "micropython-ucharm-macos-x86_64",
            .linux_x86_64 => "micropython-ucharm-linux-x86_64",
            .linux_aarch64 => "micropython-ucharm-linux-aarch64",
        };
    }
};

pub fn run(allocator: Allocator, args: []const [:0]const u8) !void {
    var script_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var mode: Mode = .universal;
    var target: ?Target = null;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= args.len) {
                io.eprint(red ++ "Error:" ++ reset ++ " -o requires an argument\n", .{});
                std.process.exit(1);
            }
            output_path = args[i];
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--mode")) {
            i += 1;
            if (i >= args.len) {
                io.eprint(red ++ "Error:" ++ reset ++ " --mode requires an argument\n", .{});
                std.process.exit(1);
            }
            const mode_str = args[i];
            if (std.mem.eql(u8, mode_str, "single")) {
                mode = .single;
            } else if (std.mem.eql(u8, mode_str, "executable")) {
                mode = .executable;
            } else if (std.mem.eql(u8, mode_str, "universal")) {
                mode = .universal;
            } else {
                io.eprint(red ++ "Error:" ++ reset ++ " Unknown mode '{s}'. Use: single, executable, universal\n", .{mode_str});
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--target")) {
            i += 1;
            if (i >= args.len) {
                io.eprint(red ++ "Error:" ++ reset ++ " --target requires an argument\n", .{});
                std.process.exit(1);
            }
            const target_str = args[i];
            target = Target.fromString(target_str);
            if (target == null) {
                io.eprint(red ++ "Error:" ++ reset ++ " Unknown target '{s}'\n", .{target_str});
                io.eprint("\nAvailable targets:\n", .{});
                io.eprint("  macos-aarch64  " ++ dim ++ "(macOS Apple Silicon)" ++ reset ++ "\n", .{});
                io.eprint("  macos-x86_64   " ++ dim ++ "(macOS Intel)" ++ reset ++ "\n", .{});
                io.eprint("  linux-x86_64   " ++ dim ++ "(Linux x86_64)" ++ reset ++ "\n", .{});
                io.eprint("  linux-aarch64  " ++ dim ++ "(Linux ARM64)" ++ reset ++ "\n", .{});
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, arg, "--targets")) {
            io.print("Available targets:\n", .{});
            io.print("  macos-aarch64  " ++ dim ++ "(macOS Apple Silicon)" ++ reset ++ "\n", .{});
            io.print("  macos-x86_64   " ++ dim ++ "(macOS Intel)" ++ reset ++ "\n", .{});
            io.print("  linux-x86_64   " ++ dim ++ "(Linux x86_64)" ++ reset ++ "\n", .{});
            io.print("  linux-aarch64  " ++ dim ++ "(Linux ARM64)" ++ reset ++ "\n", .{});
            return;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printHelp();
            return;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            io.eprint(red ++ "Error:" ++ reset ++ " Unknown option '{s}'\n", .{arg});
            std.process.exit(1);
        } else {
            script_path = arg;
        }
    }

    if (script_path == null) {
        io.eprint(red ++ "Error:" ++ reset ++ " No input script specified\n", .{});
        io.eprint("Usage: ucharm build <script.py> -o <output> [--mode <mode>] [--target <target>]\n", .{});
        std.process.exit(1);
    }

    if (output_path == null) {
        io.eprint(red ++ "Error:" ++ reset ++ " No output path specified (-o)\n", .{});
        std.process.exit(1);
    }

    // Default to host target
    const build_target = target orelse Target.fromHost();

    // Check if script exists
    const script = script_path.?;
    fs.cwd().access(script, .{}) catch {
        io.eprint(red ++ "Error:" ++ reset ++ " Script not found: {s}\n", .{script});
        std.process.exit(1);
    };

    // Print header
    io.print("\n", .{});
    io.print(cyan ++ bold ++ "μcharm build" ++ reset ++ "\n", .{});
    io.print(dim ++ "─────────────────────────────────────────" ++ reset ++ "\n", .{});
    io.print(dim ++ "  Input:  " ++ reset ++ "{s}\n", .{script});
    io.print(dim ++ "  Output: " ++ reset ++ "{s}\n", .{output_path.?});
    io.print(dim ++ "  Mode:   " ++ reset ++ cyan ++ "{s}" ++ reset ++ "\n", .{@tagName(mode)});
    if (mode == .universal) {
        io.print(dim ++ "  Target: " ++ reset ++ cyan ++ "{s}" ++ reset ++ dim ++ " ({s})" ++ reset ++ "\n", .{ build_target.name(), build_target.displayName() });
    }
    io.print(dim ++ "─────────────────────────────────────────" ++ reset ++ "\n\n", .{});

    switch (mode) {
        .single => try buildSingle(allocator, script, output_path.?),
        .executable => try buildExecutable(allocator, script, output_path.?),
        .universal => try buildUniversal(allocator, script, output_path.?, build_target),
    }
}

fn printHelp() void {
    io.print(
        \\{s}μcharm build{s} - Build standalone binaries from Python scripts
        \\
        \\{s}USAGE:{s}
        \\    ucharm build <script.py> -o <output> [OPTIONS]
        \\
        \\{s}OPTIONS:{s}
        \\    -o, --output <path>    Output file path (required)
        \\    -m, --mode <mode>      Build mode: universal, executable, single
        \\                           (default: universal)
        \\    -t, --target <target>  Target platform for cross-compilation
        \\                           (default: current platform)
        \\    --targets              List available targets
        \\    -h, --help             Show this help
        \\
        \\{s}TARGETS:{s}
        \\    macos-aarch64          macOS on Apple Silicon
        \\    macos-x86_64           macOS on Intel
        \\    linux-x86_64           Linux on x86_64
        \\    linux-aarch64          Linux on ARM64
        \\
        \\{s}MODES:{s}
        \\    universal              Standalone binary (~900KB, no dependencies)
        \\    executable             Shell wrapper (requires micropython-ucharm)
        \\    single                 Transformed .py file (requires micropython-ucharm)
        \\
        \\{s}EXAMPLES:{s}
        \\    ucharm build app.py -o app
        \\    ucharm build app.py -o app-linux --target linux-x86_64
        \\    ucharm build app.py -o app.py --mode single
        \\
    , .{ bold, reset, dim, reset, dim, reset, dim, reset, dim, reset, dim, reset });
}

fn transformScript(allocator: Allocator, script_path: []const u8) ![]u8 {
    // Read the user's script
    const script_content = try fs.cwd().readFileAlloc(allocator, script_path, 1024 * 1024);
    defer allocator.free(script_content);

    // Build output
    var output_buffer: std.ArrayList(u8) = .empty;
    errdefer output_buffer.deinit(allocator);

    // Header
    try output_buffer.appendSlice(allocator, "#!/usr/bin/env micropython\n");
    try output_buffer.appendSlice(allocator, "# Built with ucharm - native modules edition\n\n");

    // Track what needs to be imported from native modules
    var needs_charm = false;
    var needs_input = false;

    // First pass: check what ucharm imports are used
    var check_lines = std.mem.splitSequence(u8, script_content, "\n");
    while (check_lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");

        if (std.mem.startsWith(u8, trimmed, "from ucharm import")) {
            // Parse the imports to see what's needed
            const import_part = trimmed["from ucharm import".len..];
            if (containsAny(import_part, &.{ "style", "box", "rule", "success", "error", "warning", "info", "progress" })) {
                needs_charm = true;
            }
            if (containsAny(import_part, &.{ "select", "multiselect", "confirm", "prompt", "password" })) {
                needs_input = true;
            }
        } else if (std.mem.startsWith(u8, trimmed, "import ucharm")) {
            needs_charm = true;
            needs_input = true;
        }
    }

    // Add native module imports if needed
    if (needs_charm) {
        try output_buffer.appendSlice(allocator, "from charm import style, box, rule, success, error, warning, info, progress\n");
    }
    if (needs_input) {
        try output_buffer.appendSlice(allocator, "from input import select, multiselect, confirm, prompt, password\n");
    }
    if (needs_charm or needs_input) {
        try output_buffer.appendSlice(allocator, "\n");
    }

    // Second pass: process lines and skip ucharm imports
    var lines = std.mem.splitSequence(u8, script_content, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");

        // Skip ucharm imports (we've replaced them with native module imports)
        if (std.mem.startsWith(u8, trimmed, "from ucharm import") or
            std.mem.startsWith(u8, trimmed, "import ucharm") or
            std.mem.startsWith(u8, trimmed, "from ucharm."))
        {
            continue;
        }

        // Skip sys.path modifications for ucharm
        if (std.mem.indexOf(u8, line, "sys.path") != null and
            std.mem.indexOf(u8, line, "ucharm") != null)
        {
            continue;
        }

        try output_buffer.appendSlice(allocator, line);
        try output_buffer.append(allocator, '\n');
    }

    return try output_buffer.toOwnedSlice(allocator);
}

fn containsAny(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (std.mem.indexOf(u8, haystack, needle) != null) {
            return true;
        }
    }
    return false;
}

fn buildSingle(allocator: Allocator, script: []const u8, output: []const u8) !void {
    // Transform script to use native modules
    const transformed = try transformScript(allocator, script);
    defer allocator.free(transformed);

    // Write output file
    const output_file = try fs.cwd().createFile(output, .{});
    defer output_file.close();
    try output_file.writeAll(transformed);

    // Make executable (mode 0o755)
    const file_for_chmod = try fs.cwd().openFile(output, .{ .mode = .read_write });
    defer file_for_chmod.close();
    try file_for_chmod.chmod(0o755);

    io.print(green ++ check ++ reset ++ " Transformed Python code " ++ dim ++ "({d} bytes)" ++ reset ++ "\n", .{transformed.len});
    io.print("\n" ++ dim ++ "Note: Requires micropython-ucharm with native modules" ++ reset ++ "\n", .{});
}

fn buildExecutable(allocator: Allocator, script: []const u8, output: []const u8) !void {
    // Transform script
    const transformed = try transformScript(allocator, script);
    defer allocator.free(transformed);

    // Base64 encode
    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(transformed.len);
    const encoded = try allocator.alloc(u8, encoded_len);
    defer allocator.free(encoded);
    _ = encoder.encode(encoded, transformed);

    // Create shell wrapper that extracts embedded micropython
    var wrapper: std.ArrayList(u8) = .empty;
    defer wrapper.deinit(allocator);

    try wrapper.appendSlice(allocator, "#!/bin/bash\n");
    try wrapper.appendSlice(allocator, "# Built with μcharm - https://github.com/ucharmdev/ucharm\n");
    try wrapper.appendSlice(allocator, "# Requires micropython-ucharm with native modules\n\n");
    try wrapper.appendSlice(allocator, "MICROPYTHON=\"micropython-ucharm\"\n");
    try wrapper.appendSlice(allocator, "if ! command -v \"$MICROPYTHON\" &> /dev/null; then\n");
    try wrapper.appendSlice(allocator, "    MICROPYTHON=\"micropython\"\n");
    try wrapper.appendSlice(allocator, "    if ! command -v \"$MICROPYTHON\" &> /dev/null; then\n");
    try wrapper.appendSlice(allocator, "        echo \"Error: micropython not found\" >&2\n");
    try wrapper.appendSlice(allocator, "        exit 1\n");
    try wrapper.appendSlice(allocator, "    fi\n");
    try wrapper.appendSlice(allocator, "fi\n");
    try wrapper.appendSlice(allocator, "echo \"");
    try wrapper.appendSlice(allocator, encoded);
    try wrapper.appendSlice(allocator, "\" | base64 -d | \"$MICROPYTHON\" /dev/stdin \"$@\"\n");

    // Write wrapper
    const output_file = try fs.cwd().createFile(output, .{});
    defer output_file.close();
    try output_file.writeAll(wrapper.items);

    const file_for_chmod = try fs.cwd().openFile(output, .{ .mode = .read_write });
    defer file_for_chmod.close();
    try file_for_chmod.chmod(0o755);

    io.print(green ++ check ++ reset ++ " Created shell wrapper " ++ dim ++ "({d} bytes)" ++ reset ++ "\n", .{wrapper.items.len});
    io.print("\n" ++ dim ++ "─────────────────────────────────────────" ++ reset ++ "\n", .{});
    io.print(green ++ bold ++ check ++ " Built successfully!" ++ reset ++ "\n", .{});
    if (output[0] == '/') {
        io.print(dim ++ "  Run with: " ++ reset ++ "{s}\n\n", .{output});
    } else {
        io.print(dim ++ "  Run with: " ++ reset ++ "./{s}\n\n", .{output});
    }
}

fn buildUniversal(allocator: Allocator, script: []const u8, output: []const u8, target: Target) !void {
    // Transform script to use native modules
    const py_content = try transformScript(allocator, script);
    defer allocator.free(py_content);

    // Get micropython binary for target
    const mpy_binary = try getMicropythonBinary(allocator, target);
    const mpy_is_allocated = mpy_binary.allocated;
    defer if (mpy_is_allocated) allocator.free(mpy_binary.data);

    io.print(green ++ check ++ reset ++ " Using " ++ bold ++ "micropython-ucharm" ++ reset ++ dim ++ " for {s} ({d} KB)" ++ reset ++ "\n", .{ target.name(), mpy_binary.data.len / 1024 });

    // Select loader stub for target platform
    const stub = target.loaderStub();
    io.print(green ++ check ++ reset ++ " Selected loader " ++ bold ++ "{s}" ++ reset ++ dim ++ " ({d} KB)" ++ reset ++ "\n", .{ target.name(), stub.len / 1024 });

    // Calculate offsets for trailer
    const stub_size: u64 = stub.len;
    const micropython_offset: u64 = stub_size;
    const micropython_size: u64 = mpy_binary.data.len;
    const python_offset: u64 = micropython_offset + micropython_size;
    const python_size: u64 = py_content.len;

    // Build trailer (48 bytes)
    var trailer: [TRAILER_SIZE]u8 = undefined;
    @memcpy(trailer[0..8], TRAILER_MAGIC);
    std.mem.writeInt(u64, trailer[8..16], micropython_offset, .little);
    std.mem.writeInt(u64, trailer[16..24], micropython_size, .little);
    std.mem.writeInt(u64, trailer[24..32], python_offset, .little);
    std.mem.writeInt(u64, trailer[32..40], python_size, .little);
    @memcpy(trailer[40..48], TRAILER_MAGIC);

    // Write universal binary: [stub][micropython][python][trailer]
    const output_file = try fs.cwd().createFile(output, .{});
    defer output_file.close();

    try output_file.writeAll(stub);
    try output_file.writeAll(mpy_binary.data);
    try output_file.writeAll(py_content);
    try output_file.writeAll(&trailer);

    const file_for_chmod = try fs.cwd().openFile(output, .{ .mode = .read_write });
    defer file_for_chmod.close();
    try file_for_chmod.chmod(0o755);

    const total_size = stub.len + mpy_binary.data.len + py_content.len + TRAILER_SIZE;
    const total_kb = total_size / 1024;
    io.print(green ++ check ++ reset ++ " Wrote universal binary " ++ dim ++ "({d} KB)" ++ reset ++ "\n", .{total_kb});

    // Success summary
    io.print("\n" ++ dim ++ "─────────────────────────────────────────" ++ reset ++ "\n", .{});
    io.print(green ++ bold ++ check ++ " Built successfully!" ++ reset ++ "\n", .{});
    io.print(dim ++ "  Output:  " ++ reset ++ "{s}\n", .{output});
    io.print(dim ++ "  Target:  " ++ reset ++ "{s}\n", .{target.displayName()});
    io.print(dim ++ "  Size:    " ++ reset ++ "{d} KB " ++ dim ++ "(standalone, no dependencies)" ++ reset ++ "\n", .{total_kb});
    io.print(dim ++ "  Startup: " ++ reset ++ "~6ms " ++ dim ++ "(instant)" ++ reset ++ "\n", .{});
    // Show run command - handle absolute vs relative paths
    if (output[0] == '/') {
        io.print("\n" ++ dim ++ "  Run with: " ++ reset ++ "{s}\n\n", .{output});
    } else {
        io.print("\n" ++ dim ++ "  Run with: " ++ reset ++ "./{s}\n\n", .{output});
    }
}

const MicropythonBinary = struct {
    data: []const u8,
    allocated: bool,
};

fn getMicropythonBinary(allocator: Allocator, target: Target) !MicropythonBinary {
    // For macOS ARM64, we have the binary embedded
    if (target == .macos_aarch64) {
        return .{ .data = micropython_macos_aarch64, .allocated = false };
    }

    // For other targets, try to load from ~/.ucharm/runtimes/
    const home = std.posix.getenv("HOME") orelse "/tmp";
    const runtime_dir = try std.fmt.allocPrint(allocator, "{s}/.ucharm/runtimes", .{home});
    defer allocator.free(runtime_dir);
    const runtime_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ runtime_dir, target.micropythonFilename() });
    defer allocator.free(runtime_path);

    // Try to open existing runtime
    const file = fs.cwd().openFile(runtime_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // Runtime not found - offer to download
            return downloadRuntime(allocator, target, runtime_dir, runtime_path);
        }
        return err;
    };
    defer file.close();

    const stat = try file.stat();
    const data = try allocator.alloc(u8, stat.size);
    const bytes_read = try file.readAll(data);
    if (bytes_read != stat.size) {
        return error.IncompleteRead;
    }

    return .{ .data = data, .allocated = true };
}

fn downloadRuntime(allocator: Allocator, target: Target, runtime_dir: []const u8, runtime_path: []const u8) !MicropythonBinary {
    const download_url = try std.fmt.allocPrint(allocator, "https://github.com/ucharmdev/ucharm/releases/latest/download/{s}", .{target.micropythonFilename()});
    defer allocator.free(download_url);

    io.print(yellow ++ "?" ++ reset ++ " MicroPython runtime for " ++ bold ++ "{s}" ++ reset ++ " not found locally.\n", .{target.name()});
    io.print("  Download from GitHub? " ++ dim ++ "(~850KB)" ++ reset ++ " [Y/n] ", .{});

    // Read user input
    var buf: [10]u8 = undefined;
    const read_result = std.posix.read(std.posix.STDIN_FILENO, &buf) catch 0;

    // Default to yes, or check for explicit no
    const should_download = if (read_result == 0) true else blk: {
        const input = std.mem.trim(u8, buf[0..read_result], " \t\n\r");
        break :blk input.len == 0 or input[0] == 'y' or input[0] == 'Y';
    };

    if (!should_download) {
        io.print("\n" ++ dim ++ "To download manually:" ++ reset ++ "\n", .{});
        io.print("  mkdir -p {s}\n", .{runtime_dir});
        io.print("  curl -L {s} -o {s}\n\n", .{ download_url, runtime_path });
        std.process.exit(1);
    }

    io.print("\n", .{});

    // Create runtime directory
    fs.cwd().makePath(runtime_dir) catch |err| {
        io.eprint(red ++ "Error:" ++ reset ++ " Failed to create directory {s}: {}\n", .{ runtime_dir, err });
        std.process.exit(1);
    };

    // Download using curl (available on macOS and most Linux)
    io.print(dim ++ "  Downloading..." ++ reset, .{});

    var child = std.process.Child.init(&[_][]const u8{
        "curl",
        "-fSL",
        "--progress-bar",
        "-o",
        runtime_path,
        download_url,
    }, allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;

    _ = child.spawn() catch |err| {
        io.eprint("\n" ++ red ++ "Error:" ++ reset ++ " Failed to run curl: {}\n", .{err});
        io.eprint(dim ++ "Install curl or download manually:\n" ++ reset, .{});
        io.eprint("  curl -L {s} -o {s}\n", .{ download_url, runtime_path });
        std.process.exit(1);
    };

    const result = child.wait() catch |err| {
        io.eprint("\n" ++ red ++ "Error:" ++ reset ++ " Download failed: {}\n", .{err});
        std.process.exit(1);
    };

    if (result.Exited != 0) {
        io.eprint("\n" ++ red ++ "Error:" ++ reset ++ " Download failed (curl exit code: {})\n", .{result.Exited});
        io.eprint(dim ++ "The runtime may not be available yet. Try again after the next release.\n" ++ reset, .{});
        std.process.exit(1);
    }

    io.print(" " ++ green ++ check ++ reset ++ "\n", .{});

    // Make it executable
    const file_for_chmod = try fs.cwd().openFile(runtime_path, .{ .mode = .read_write });
    defer file_for_chmod.close();
    try file_for_chmod.chmod(0o755);

    // Now read and return the downloaded file
    const file = try fs.cwd().openFile(runtime_path, .{});
    defer file.close();

    const stat = try file.stat();
    const data = try allocator.alloc(u8, stat.size);
    const bytes_read = try file.readAll(data);
    if (bytes_read != stat.size) {
        return error.IncompleteRead;
    }

    io.print(green ++ check ++ reset ++ " Downloaded runtime to " ++ dim ++ "{s}" ++ reset ++ "\n\n", .{runtime_path});

    return .{ .data = data, .allocated = true };
}
