const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const io = @import("io.zig");

// Embedded loader stubs for instant-startup universal binaries
const stub_macos_aarch64 = @embedFile("stubs/loader-macos-aarch64");
const stub_macos_x86_64 = @embedFile("stubs/loader-macos-x86_64");
const stub_linux_x86_64 = @embedFile("stubs/loader-linux-x86_64");

// Embedded micropython-ucharm binary (contains all native modules)
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

pub fn run(allocator: Allocator, args: []const [:0]const u8) !void {
    var script_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var mode: Mode = .universal;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= args.len) {
                io.eprint("\x1b[31mError:\x1b[0m -o requires an argument\n", .{});
                std.process.exit(1);
            }
            output_path = args[i];
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--mode")) {
            i += 1;
            if (i >= args.len) {
                io.eprint("\x1b[31mError:\x1b[0m --mode requires an argument\n", .{});
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
                io.eprint("\x1b[31mError:\x1b[0m Unknown mode '{s}'. Use: single, executable, universal\n", .{mode_str});
                std.process.exit(1);
            }
        } else if (std.mem.startsWith(u8, arg, "-")) {
            io.eprint("\x1b[31mError:\x1b[0m Unknown option '{s}'\n", .{arg});
            std.process.exit(1);
        } else {
            script_path = arg;
        }
    }

    if (script_path == null) {
        io.eprint("\x1b[31mError:\x1b[0m No input script specified\n", .{});
        io.eprint("Usage: ucharm build <script.py> -o <output> [--mode <mode>]\n", .{});
        std.process.exit(1);
    }

    if (output_path == null) {
        io.eprint("\x1b[31mError:\x1b[0m No output path specified (-o)\n", .{});
        std.process.exit(1);
    }

    // Check if script exists
    const script = script_path.?;
    fs.cwd().access(script, .{}) catch {
        io.eprint("\x1b[31mError:\x1b[0m Script not found: {s}\n", .{script});
        std.process.exit(1);
    };

    // Print header
    io.print("\n", .{});
    io.print(cyan ++ bold ++ "μcharm build" ++ reset ++ "\n", .{});
    io.print(dim ++ "─────────────────────────────────────────" ++ reset ++ "\n", .{});
    io.print(dim ++ "  Input:  " ++ reset ++ "{s}\n", .{script});
    io.print(dim ++ "  Output: " ++ reset ++ "{s}\n", .{output_path.?});
    io.print(dim ++ "  Mode:   " ++ reset ++ cyan ++ "{s}" ++ reset ++ "\n", .{@tagName(mode)});
    io.print(dim ++ "─────────────────────────────────────────" ++ reset ++ "\n\n", .{});

    switch (mode) {
        .single => try buildSingle(allocator, script, output_path.?),
        .executable => try buildExecutable(allocator, script, output_path.?),
        .universal => try buildUniversal(allocator, script, output_path.?),
    }
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

fn buildUniversal(allocator: Allocator, script: []const u8, output: []const u8) !void {
    // Transform script to use native modules
    const py_content = try transformScript(allocator, script);
    defer allocator.free(py_content);

    // Use embedded micropython-ucharm (with native modules)
    const mpy_binary = micropython_macos_aarch64;
    io.print(green ++ check ++ reset ++ " Using embedded " ++ bold ++ "micropython-ucharm" ++ reset ++ dim ++ " (23 native modules)" ++ reset ++ "\n", .{});

    // Select loader stub for host platform
    const stub = selectLoaderStub();
    io.print(green ++ check ++ reset ++ " Selected loader " ++ bold ++ "{s}" ++ reset ++ dim ++ " ({d} KB)" ++ reset ++ "\n", .{ stub.name, stub.data.len / 1024 });

    // Calculate offsets for trailer
    const stub_size: u64 = stub.data.len;
    const micropython_offset: u64 = stub_size;
    const micropython_size: u64 = mpy_binary.len;
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

    try output_file.writeAll(stub.data);
    try output_file.writeAll(mpy_binary);
    try output_file.writeAll(py_content);
    try output_file.writeAll(&trailer);

    const file_for_chmod = try fs.cwd().openFile(output, .{ .mode = .read_write });
    defer file_for_chmod.close();
    try file_for_chmod.chmod(0o755);

    const total_size = stub.data.len + mpy_binary.len + py_content.len + TRAILER_SIZE;
    const total_kb = total_size / 1024;
    io.print(green ++ check ++ reset ++ " Wrote universal binary " ++ dim ++ "({d} KB)" ++ reset ++ "\n", .{total_kb});

    // Success summary
    io.print("\n" ++ dim ++ "─────────────────────────────────────────" ++ reset ++ "\n", .{});
    io.print(green ++ bold ++ check ++ " Built successfully!" ++ reset ++ "\n", .{});
    io.print(dim ++ "  Output:  " ++ reset ++ "{s}\n", .{output});
    io.print(dim ++ "  Size:    " ++ reset ++ "{d} KB " ++ dim ++ "(standalone, no dependencies)" ++ reset ++ "\n", .{total_kb});
    io.print(dim ++ "  Startup: " ++ reset ++ "~6ms " ++ dim ++ "(instant)" ++ reset ++ "\n", .{});
    // Show run command - handle absolute vs relative paths
    if (output[0] == '/') {
        io.print("\n" ++ dim ++ "  Run with: " ++ reset ++ "{s}\n\n", .{output});
    } else {
        io.print("\n" ++ dim ++ "  Run with: " ++ reset ++ "./{s}\n\n", .{output});
    }
}

const LoaderStub = struct {
    name: []const u8,
    data: []const u8,
};

fn selectLoaderStub() LoaderStub {
    // Select based on host OS and architecture
    const os = @import("builtin").os.tag;
    const arch = @import("builtin").cpu.arch;

    if (os == .macos) {
        if (arch == .aarch64) {
            return .{ .name = "macos-aarch64", .data = stub_macos_aarch64 };
        } else {
            return .{ .name = "macos-x86_64", .data = stub_macos_x86_64 };
        }
    } else {
        // Linux (and other Unix-like)
        return .{ .name = "linux-x86_64", .data = stub_linux_x86_64 };
    }
}
