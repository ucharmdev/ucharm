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

const Mode = enum {
    single,
    executable,
    universal,
};

pub fn run(allocator: Allocator, args: []const [:0]const u8) !void {
    var script_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var mode: Mode = .universal;
    var prefer_native: bool = true; // Default to native if available

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
        } else if (std.mem.eql(u8, arg, "--native")) {
            prefer_native = true;
        } else if (std.mem.eql(u8, arg, "--no-native")) {
            prefer_native = false;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            io.eprint("\x1b[31mError:\x1b[0m Unknown option '{s}'\n", .{arg});
            std.process.exit(1);
        } else {
            script_path = arg;
        }
    }
    


    if (script_path == null) {
        io.eprint("\x1b[31mError:\x1b[0m No input script specified\n", .{});
        io.eprint("Usage: mcharm build <script.py> -o <output> [--mode <mode>]\n", .{});
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
    _ = io.stdout().write(logo) catch {};
    io.print("Building \x1b[1m{s}\x1b[0m...\n", .{script});
    io.print("Mode: \x1b[36m{s}\x1b[0m\n", .{@tagName(mode)});
    io.print("Output: \x1b[36m{s}\x1b[0m\n\n", .{output_path.?});

    switch (mode) {
        .single => try buildSingle(allocator, script, output_path.?),
        .executable => try buildExecutable(allocator, script, output_path.?, prefer_native),
        .universal => try buildUniversal(allocator, script, output_path.?, prefer_native),
    }

    io.print("\n\x1b[32mDone!\x1b[0m\n", .{});
}

fn buildSingle(allocator: Allocator, script: []const u8, output: []const u8) !void {
    // Read the script
    const script_content = try fs.cwd().readFileAlloc(allocator, script, 1024 * 1024);
    defer allocator.free(script_content);

    // Microcharm library files to embed
    const microcharm_files = [_][]const u8{
        "terminal.py",
        "style.py",
        "components.py",
        "input.py",
        "table.py",
    };

    // Build combined output using a simple buffer approach
    var output_buffer: std.ArrayList(u8) = .empty;
    defer output_buffer.deinit(allocator);

    // Helper to append slice
    const appendSlice = struct {
        fn f(list: *std.ArrayList(u8), alloc: Allocator, slice: []const u8) !void {
            try list.appendSlice(alloc, slice);
        }
    }.f;

    // Header
    try appendSlice(&output_buffer, allocator, "#!/usr/bin/env micropython\n");
    try appendSlice(&output_buffer, allocator, "# Built with μcharm\n\n");
    try appendSlice(&output_buffer, allocator, "import sys\nimport time\n\n");
    try appendSlice(&output_buffer, allocator, "# === Embedded microcharm library ===\n\n");

    // Find microcharm directory - try relative paths
    const microcharm_paths = [_][]const u8{
        "microcharm",
        "../microcharm",
        "../../microcharm",
    };

    var microcharm_base: ?[]const u8 = null;
    for (microcharm_paths) |path| {
        const test_path = try fs.path.join(allocator, &.{ path, "style.py" });
        defer allocator.free(test_path);
        if (fs.cwd().access(test_path, .{})) |_| {
            microcharm_base = path;
            break;
        } else |_| {}
    }

    if (microcharm_base == null) {
        io.eprint("\x1b[31mError:\x1b[0m Could not find microcharm library\n", .{});
        std.process.exit(1);
    }

    // Embed each library file
    for (microcharm_files) |filename| {
        const file_path = try fs.path.join(allocator, &.{ microcharm_base.?, filename });
        defer allocator.free(file_path);

        const content = fs.cwd().readFileAlloc(allocator, file_path, 512 * 1024) catch {
            io.eprint("\x1b[31mError:\x1b[0m Could not read {s}\n", .{file_path});
            std.process.exit(1);
        };
        defer allocator.free(content);

        try appendSlice(&output_buffer, allocator, "# --- microcharm/");
        try appendSlice(&output_buffer, allocator, filename);
        try appendSlice(&output_buffer, allocator, " ---\n");

        // Process content - skip relative imports and duplicate imports
        var lines = std.mem.splitSequence(u8, content, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (std.mem.startsWith(u8, trimmed, "from .")) continue;
            if (std.mem.eql(u8, trimmed, "import sys")) continue;
            if (std.mem.eql(u8, trimmed, "import time")) continue;
            try appendSlice(&output_buffer, allocator, line);
            try output_buffer.append(allocator, '\n');
        }
        try output_buffer.append(allocator, '\n');
    }

    try appendSlice(&output_buffer, allocator, "# === Application ===\n\n");

    // Process main script - skip microcharm imports and sys.path manipulation
    var in_multiline_import = false;
    var script_lines = std.mem.splitSequence(u8, script_content, "\n");
    while (script_lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");

        if (in_multiline_import) {
            if (std.mem.indexOf(u8, line, ")") != null) {
                in_multiline_import = false;
            }
            continue;
        }

        if (std.mem.indexOf(u8, line, "from microcharm") != null or
            std.mem.indexOf(u8, line, "import microcharm") != null)
        {
            if (std.mem.indexOf(u8, line, "(") != null and std.mem.indexOf(u8, line, ")") == null) {
                in_multiline_import = true;
            }
            continue;
        }

        if (std.mem.indexOf(u8, line, "sys.path") != null) continue;
        if (std.mem.eql(u8, trimmed, "import sys")) continue;
        if (std.mem.eql(u8, trimmed, "import time")) continue;

        try appendSlice(&output_buffer, allocator, line);
        try output_buffer.append(allocator, '\n');
    }

    // Write output file
    const output_file = try fs.cwd().createFile(output, .{});
    defer output_file.close();
    try output_file.writeAll(output_buffer.items);

    // Make executable (mode 0o755)
    const file_for_chmod = try fs.cwd().openFile(output, .{ .mode = .read_write });
    defer file_for_chmod.close();
    try file_for_chmod.chmod(0o755);

    io.print("Created: {s} ({d} bytes)\n", .{ output, output_buffer.items.len });
}

fn buildExecutable(allocator: Allocator, script: []const u8, output: []const u8, prefer_native: bool) !void {
    // First build single file to temp
    const temp_path = "/tmp/mcharm_bundle.py";
    try buildSingle(allocator, script, temp_path);

    // Read bundled content
    const bundled = try fs.cwd().readFileAlloc(allocator, temp_path, 2 * 1024 * 1024);
    defer allocator.free(bundled);

    // Base64 encode
    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(bundled.len);
    const encoded = try allocator.alloc(u8, encoded_len);
    defer allocator.free(encoded);
    _ = encoder.encode(encoded, bundled);

    // Find micropython
    const mpy_path = findMicropython(prefer_native) catch "/opt/homebrew/bin/micropython";

    // Create shell wrapper
    var wrapper: std.ArrayList(u8) = .empty;
    defer wrapper.deinit(allocator);

    try wrapper.appendSlice(allocator, "#!/bin/bash\n");
    try wrapper.appendSlice(allocator, "# Built with μcharm - https://github.com/niklas-heer/microcharm\n");
    try wrapper.appendSlice(allocator, "MICROPYTHON=\"");
    try wrapper.appendSlice(allocator, mpy_path);
    try wrapper.appendSlice(allocator, "\"\n");
    try wrapper.appendSlice(allocator, "if ! command -v \"$MICROPYTHON\" &> /dev/null; then\n");
    try wrapper.appendSlice(allocator, "    if command -v micropython &> /dev/null; then\n");
    try wrapper.appendSlice(allocator, "        MICROPYTHON=\"micropython\"\n");
    try wrapper.appendSlice(allocator, "    else\n");
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

    io.print("Created: {s} ({d} bytes)\n", .{ output, wrapper.items.len });
}

fn buildUniversal(allocator: Allocator, script: []const u8, output: []const u8, prefer_native: bool) !void {
    // First build single file
    const temp_path = "/tmp/mcharm_bundle.py";
    try buildSingle(allocator, script, temp_path);

    // Read bundled content
    const py_content = try fs.cwd().readFileAlloc(allocator, temp_path, 2 * 1024 * 1024);
    defer allocator.free(py_content);

    // Find and read micropython binary (prefer native build with term/ansi modules)
    const mpy_info = findMicropythonWithInfo(prefer_native);
    const mpy_path = mpy_info.path;
    
    if (mpy_info.is_native) {
        io.print("Using: \x1b[32mmicropython-mcharm\x1b[0m (with native modules)\n", .{});
    } else {
        io.print("Using: \x1b[33mstandard micropython\x1b[0m (native modules not available)\n", .{});
    }

    // Open micropython binary (handle both absolute and relative paths)
    const mpy_file = if (mpy_path[0] == '/')
        try fs.openFileAbsolute(mpy_path, .{})
    else
        try fs.cwd().openFile(mpy_path, .{});
    defer mpy_file.close();

    const mpy_stat = try mpy_file.stat();
    const mpy_size = mpy_stat.size;

    const mpy_binary = try allocator.alloc(u8, mpy_size);
    defer allocator.free(mpy_binary);
    _ = try mpy_file.readAll(mpy_binary);

    // Calculate content hash for caching
    var hasher = std.crypto.hash.Md5.init(.{});
    const hash_len = @min(1000, mpy_binary.len);
    hasher.update(mpy_binary[0..hash_len]);
    const py_hash_len = @min(1000, py_content.len);
    hasher.update(py_content[0..py_hash_len]);
    var hash: [16]u8 = undefined;
    hasher.final(&hash);

    var hash_hex: [8]u8 = undefined;
    const hex_chars = "0123456789abcdef";
    for (0..4) |idx| {
        hash_hex[idx * 2] = hex_chars[hash[idx] >> 4];
        hash_hex[idx * 2 + 1] = hex_chars[hash[idx] & 0x0f];
    }

    // Create header (must be exactly 4096 bytes for block alignment)
    const BLOCK_SIZE: usize = 4096;
    var header_buf: [BLOCK_SIZE]u8 = undefined;
    @memset(&header_buf, '#');

    var header_stream = std.io.fixedBufferStream(&header_buf);
    const hw = header_stream.writer();

    hw.print(
        \\#!/bin/bash
        \\H={s};C="$HOME/.cache/microcharm/$H"
        \\if [ -x "$C/m" ] && [ -f "$C/a.py" ]; then exec "$C/m" "$C/a.py" "$@"; fi
        \\mkdir -p "$C";S="$0"
        \\dd bs=4096 skip=1 if="$S" 2>/dev/null|head -c {d} >"$C/m";chmod +x "$C/m"
        \\tail -c {d} "$S">"$C/a.py";exec "$C/m" "$C/a.py" "$@"
        \\
    , .{ hash_hex, mpy_size, py_content.len }) catch {};

    // Pad with newline at end
    const pos = header_stream.pos;
    header_buf[pos] = '\n';
    header_buf[BLOCK_SIZE - 1] = '\n';

    // Write universal binary
    const output_file = try fs.cwd().createFile(output, .{});
    defer output_file.close();

    try output_file.writeAll(&header_buf);
    try output_file.writeAll(mpy_binary);
    try output_file.writeAll(py_content);

    const file_for_chmod = try fs.cwd().openFile(output, .{ .mode = .read_write });
    defer file_for_chmod.close();
    try file_for_chmod.chmod(0o755);

    const total_size = BLOCK_SIZE + mpy_size + py_content.len;
    io.print("Created: {s} ({d} bytes)\n", .{ output, total_size });
    io.print("This is a universal binary - no dependencies required!\n", .{});
}

fn findMicropython(prefer_native: bool) ![]const u8 {
    // Custom micropython-mcharm locations (with native modules)
    const native_paths = [_][]const u8{
        // Installed location
        "/usr/local/bin/micropython-mcharm",
        "/opt/homebrew/bin/micropython-mcharm",
        // Development location (relative to mcharm binary)
        "../native/dist/micropython-mcharm",
        "native/dist/micropython-mcharm",
    };

    // Standard micropython locations
    const standard_paths = [_][]const u8{
        "/opt/homebrew/bin/micropython",
        "/usr/local/bin/micropython",
        "/usr/bin/micropython",
    };

    // Try native first if preferred
    if (prefer_native) {
        for (native_paths) |path| {
            if (path[0] == '/') {
                fs.accessAbsolute(path, .{}) catch continue;
                return path;
            } else {
                fs.cwd().access(path, .{}) catch continue;
                return path;
            }
        }
    }

    // Try standard paths
    for (standard_paths) |path| {
        fs.accessAbsolute(path, .{}) catch continue;
        return path;
    }

    // Fall back to native paths if not preferred but nothing else found
    if (!prefer_native) {
        for (native_paths) |path| {
            if (path[0] == '/') {
                fs.accessAbsolute(path, .{}) catch continue;
                return path;
            } else {
                fs.cwd().access(path, .{}) catch continue;
                return path;
            }
        }
    }

    return error.NotFound;
}

fn findMicropythonWithInfo(prefer_native: bool) struct { path: []const u8, is_native: bool } {
    // Custom micropython-mcharm locations (with native modules)
    const native_abs_paths = [_][]const u8{
        "/usr/local/bin/micropython-mcharm",
        "/opt/homebrew/bin/micropython-mcharm",
    };
    
    const native_rel_paths = [_][]const u8{
        "native/dist/micropython-mcharm",
        "../native/dist/micropython-mcharm",
    };

    // Standard micropython locations
    const standard_paths = [_][]const u8{
        "/opt/homebrew/bin/micropython",
        "/usr/local/bin/micropython",
        "/usr/bin/micropython",
    };

    // Try native first if preferred
    if (prefer_native) {
        // Absolute paths
        for (native_abs_paths) |path| {
            fs.accessAbsolute(path, .{}) catch continue;
            return .{ .path = path, .is_native = true };
        }
        // Relative paths
        for (native_rel_paths) |path| {
            fs.cwd().access(path, .{}) catch continue;
            return .{ .path = path, .is_native = true };
        }
    }

    // Try standard paths
    for (standard_paths) |path| {
        fs.accessAbsolute(path, .{}) catch continue;
        return .{ .path = path, .is_native = false };
    }

    // Fall back to native paths
    if (!prefer_native) {
        for (native_abs_paths) |path| {
            fs.accessAbsolute(path, .{}) catch continue;
            return .{ .path = path, .is_native = true };
        }
        for (native_rel_paths) |path| {
            fs.cwd().access(path, .{}) catch continue;
            return .{ .path = path, .is_native = true };
        }
    }

    return .{ .path = "/opt/homebrew/bin/micropython", .is_native = false };
}
