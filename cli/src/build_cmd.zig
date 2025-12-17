const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const io = @import("io.zig");

// Embedded loader stubs for instant-startup universal binaries
const stub_macos_aarch64 = @embedFile("stubs/loader-macos-aarch64");
const stub_macos_x86_64 = @embedFile("stubs/loader-macos-x86_64");
const stub_linux_x86_64 = @embedFile("stubs/loader-linux-x86_64");

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
    io.print("\n", .{});
    io.print(cyan ++ bold ++ "μcharm build" ++ reset ++ "\n", .{});
    io.print(dim ++ "─────────────────────────────────────────" ++ reset ++ "\n", .{});
    io.print(dim ++ "  Input:  " ++ reset ++ "{s}\n", .{script});
    io.print(dim ++ "  Output: " ++ reset ++ "{s}\n", .{output_path.?});
    io.print(dim ++ "  Mode:   " ++ reset ++ cyan ++ "{s}" ++ reset ++ "\n", .{@tagName(mode)});
    io.print(dim ++ "─────────────────────────────────────────" ++ reset ++ "\n\n", .{});

    switch (mode) {
        .single => try buildSingle(allocator, script, output_path.?),
        .executable => try buildExecutable(allocator, script, output_path.?, prefer_native),
        .universal => try buildUniversal(allocator, script, output_path.?, prefer_native),
    }
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

    // Add constants that are normally from _native.py
    try appendSlice(&output_buffer, allocator, "# Constants (from _native.py)\n");
    try appendSlice(&output_buffer, allocator, "ALIGN_LEFT = 0\n");
    try appendSlice(&output_buffer, allocator, "ALIGN_RIGHT = 1\n");
    try appendSlice(&output_buffer, allocator, "ALIGN_CENTER = 2\n");
    try appendSlice(&output_buffer, allocator, "BORDER_ROUNDED = 0\n");
    try appendSlice(&output_buffer, allocator, "BORDER_SQUARE = 1\n");
    try appendSlice(&output_buffer, allocator, "BORDER_DOUBLE = 2\n");
    try appendSlice(&output_buffer, allocator, "BORDER_HEAVY = 3\n");
    try appendSlice(&output_buffer, allocator, "BORDER_NONE = 4\n\n");

    // Add pure Python ui class for MicroPython compatibility
    try appendSlice(&output_buffer, allocator,
        \\# Pure Python ui class (for MicroPython - replaces _native.ui)
        \\class ui:
        \\    _BOX_CHARS = {
        \\        0: ('╭', '╮', '╰', '╯', '─', '│'),  # rounded
        \\        1: ('┌', '┐', '└', '┘', '─', '│'),  # square
        \\        2: ('╔', '╗', '╚', '╝', '═', '║'),  # double
        \\        3: ('┏', '┓', '┗', '┛', '━', '┃'),  # heavy
        \\        4: (' ', ' ', ' ', ' ', ' ', ' '),  # none
        \\    }
        \\    _SPINNER = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
        \\
        \\    @staticmethod
        \\    def visible_len(s):
        \\        i, length = 0, 0
        \\        while i < len(s):
        \\            if s[i] == '\x1b' and i + 1 < len(s) and s[i + 1] == '[':
        \\                i += 2
        \\                while i < len(s) and s[i] not in 'mHJK':
        \\                    i += 1
        \\                i += 1
        \\            else:
        \\                c = ord(s[i])
        \\                if c < 128:
        \\                    length += 1
        \\                    i += 1
        \\                elif c < 0xE0:
        \\                    length += 1
        \\                    i += 2
        \\                elif c < 0xF0:
        \\                    length += 2
        \\                    i += 3
        \\                else:
        \\                    length += 2
        \\                    i += 4
        \\        return length
        \\
        \\    @staticmethod
        \\    def pad(text, width, align=0):
        \\        vis = ui.visible_len(text)
        \\        if vis >= width:
        \\            return text
        \\        pad = width - vis
        \\        if align == 1:  # right
        \\            return ' ' * pad + text
        \\        elif align == 2:  # center
        \\            l = pad // 2
        \\            return ' ' * l + text + ' ' * (pad - l)
        \\        return text + ' ' * pad
        \\
        \\    @staticmethod
        \\    def progress_bar(cur, total, width, fill='█', empty='░'):
        \\        if total <= 0:
        \\            return empty * width
        \\        filled = int(width * cur / total)
        \\        return fill * filled + empty * (width - filled)
        \\
        \\    @staticmethod
        \\    def percent_str(cur, total):
        \\        if total <= 0:
        \\            return '0%'
        \\        return str(int(100 * cur / total)) + '%'
        \\
        \\    @staticmethod
        \\    def box_chars(style=0):
        \\        c = ui._BOX_CHARS.get(style, ui._BOX_CHARS[0])
        \\        return {'tl': c[0], 'tr': c[1], 'bl': c[2], 'br': c[3], 'h': c[4], 'v': c[5]}
        \\
        \\    @staticmethod
        \\    def box_top(width, style=0):
        \\        c = ui.box_chars(style)
        \\        return c['tl'] + c['h'] * width + c['tr']
        \\
        \\    @staticmethod
        \\    def box_bottom(width, style=0):
        \\        c = ui.box_chars(style)
        \\        return c['bl'] + c['h'] * width + c['br']
        \\
        \\    @staticmethod
        \\    def box_middle(content, width, style=0, padding=1):
        \\        c = ui.box_chars(style)
        \\        pad = ' ' * padding
        \\        inner_w = width - padding * 2
        \\        return c['v'] + pad + ui.pad(content, inner_w) + pad + c['v']
        \\
        \\    @staticmethod
        \\    def rule(width, char='─'):
        \\        return char * width
        \\
        \\    @staticmethod
        \\    def rule_with_title(width, title, char='─'):
        \\        t = ' ' + title + ' '
        \\        side = (width - len(t)) // 2
        \\        return char * side + t + char * (width - side - len(t))
        \\
        \\    @staticmethod
        \\    def spinner_frame(idx):
        \\        return ui._SPINNER[idx % len(ui._SPINNER)]
        \\
        \\    @staticmethod
        \\    def spinner_frame_count():
        \\        return len(ui._SPINNER)
        \\
        \\    @staticmethod
        \\    def symbol_success():
        \\        return '✓'
        \\
        \\    @staticmethod
        \\    def symbol_error():
        \\        return '✗'
        \\
        \\    @staticmethod
        \\    def symbol_warning():
        \\        return '⚠'
        \\
        \\    @staticmethod
        \\    def symbol_info():
        \\        return 'ℹ'
        \\
        \\    @staticmethod
        \\    def symbol_bullet():
        \\        return '•'
        \\
        \\    @staticmethod
        \\    def table_v():
        \\        return '│'
        \\
        \\    @staticmethod
        \\    def table_top(col_widths):
        \\        return '┌' + '┬'.join('─' * w for w in col_widths) + '┐'
        \\
        \\    @staticmethod
        \\    def table_divider(col_widths):
        \\        return '├' + '┼'.join('─' * w for w in col_widths) + '┤'
        \\
        \\    @staticmethod
        \\    def table_bottom(col_widths):
        \\        return '└' + '┴'.join('─' * w for w in col_widths) + '┘'
        \\
        \\    @staticmethod
        \\    def table_cell(content, width, align=0, padding=1):
        \\        inner_w = width - padding * 2
        \\        pad = ' ' * padding
        \\        return pad + ui.pad(content, inner_w, align) + pad
        \\
        \\    @staticmethod
        \\    def select_indicator():
        \\        return '❯ '
        \\
        \\    @staticmethod
        \\    def checkbox_on():
        \\        return '◉'
        \\
        \\    @staticmethod
        \\    def checkbox_off():
        \\        return '○'
        \\
        \\    @staticmethod
        \\    def prompt_question():
        \\        return '? '
        \\
        \\    @staticmethod
        \\    def prompt_success():
        \\        return '✓ '
        \\
        \\    @staticmethod
        \\    def cursor_up(n):
        \\        return '\x1b[' + str(n) + 'A'
        \\
        \\    @staticmethod
        \\    def cursor_down(n):
        \\        return '\x1b[' + str(n) + 'B'
        \\
        \\    @staticmethod
        \\    def clear_line():
        \\        return '\x1b[2K\r'
        \\
        \\    @staticmethod
        \\    def hide_cursor():
        \\        return '\x1b[?25l'
        \\
        \\    @staticmethod
        \\    def show_cursor():
        \\        return '\x1b[?25h'
        \\
        \\
    );

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
        var last_line_was_block_start = false;
        var last_line_indent: usize = 0;
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");

            // Calculate indentation of this line
            var indent: usize = 0;
            for (line) |c| {
                if (c == ' ') {
                    indent += 1;
                } else if (c == '\t') {
                    indent += 4;
                } else {
                    break;
                }
            }

            // Skip relative imports and duplicate imports
            const should_skip = std.mem.startsWith(u8, trimmed, "from .") or
                std.mem.eql(u8, trimmed, "import sys") or
                std.mem.eql(u8, trimmed, "import time");

            if (should_skip) {
                // If previous line ended with :, add pass at proper indentation
                if (last_line_was_block_start) {
                    // Add indentation (use current line's indent which is block body indent)
                    var i: usize = 0;
                    while (i < indent) : (i += 1) {
                        try output_buffer.append(allocator, ' ');
                    }
                    try appendSlice(&output_buffer, allocator, "pass\n");
                    last_line_was_block_start = false;
                }
                continue;
            }

            try appendSlice(&output_buffer, allocator, line);
            try output_buffer.append(allocator, '\n');

            // Track if this line starts a block (ends with :)
            last_line_was_block_start = trimmed.len > 0 and trimmed[trimmed.len - 1] == ':';
            last_line_indent = indent;
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

    io.print(green ++ check ++ reset ++ " Bundled Python code " ++ dim ++ "({d} bytes)" ++ reset ++ "\n", .{output_buffer.items.len});
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

    io.print(green ++ check ++ reset ++ " Created shell wrapper " ++ dim ++ "({d} bytes)" ++ reset ++ "\n", .{wrapper.items.len});
    io.print("\n" ++ dim ++ "─────────────────────────────────────────" ++ reset ++ "\n", .{});
    io.print(green ++ bold ++ check ++ " Built successfully!" ++ reset ++ "\n", .{});
    if (output[0] == '/') {
        io.print(dim ++ "  Run with: " ++ reset ++ "{s}\n\n", .{output});
    } else {
        io.print(dim ++ "  Run with: " ++ reset ++ "./{s}\n\n", .{output});
    }
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
        io.print(green ++ check ++ reset ++ " Using " ++ bold ++ "micropython-mcharm" ++ reset ++ dim ++ " (18 native modules)" ++ reset ++ "\n", .{});
    } else {
        io.print(yellow ++ bullet ++ reset ++ " Using " ++ bold ++ "standard micropython" ++ reset ++ dim ++ " (native modules not available)" ++ reset ++ "\n", .{});
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

    // Select loader stub for host platform
    const stub = selectLoaderStub();
    io.print(green ++ check ++ reset ++ " Selected loader " ++ bold ++ "{s}" ++ reset ++ dim ++ " ({d} KB)" ++ reset ++ "\n", .{ stub.name, stub.data.len / 1024 });

    // Calculate offsets for trailer
    const stub_size: u64 = stub.data.len;
    const micropython_offset: u64 = stub_size;
    const micropython_size: u64 = mpy_size;
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

    const total_size = stub.data.len + mpy_size + py_content.len + TRAILER_SIZE;
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
