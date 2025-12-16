const std = @import("std");
const testing = std.testing;

// Test utilities and helper functions
// These tests verify core logic that doesn't require file system operations

test "filename sanitization" {
    // Test converting project names to valid filenames
    const cases = [_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "My App", .expected = "my_app" },
        .{ .input = "hello-world", .expected = "hello_world" },
        .{ .input = "TEST", .expected = "test" },
        .{ .input = "Simple", .expected = "simple" },
    };

    for (cases) |case| {
        var filename_buf: [256]u8 = undefined;
        var filename_len: usize = 0;

        for (case.input) |c| {
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

        const result = filename_buf[0..filename_len];
        try testing.expectEqualStrings(case.expected, result);
    }
}

test "mode parsing" {
    const Mode = enum {
        single,
        executable,
        universal,
    };

    const cases = [_]struct { input: []const u8, expected: ?Mode }{
        .{ .input = "single", .expected = .single },
        .{ .input = "executable", .expected = .executable },
        .{ .input = "universal", .expected = .universal },
        .{ .input = "invalid", .expected = null },
    };

    for (cases) |case| {
        var mode: ?Mode = null;
        if (std.mem.eql(u8, case.input, "single")) {
            mode = .single;
        } else if (std.mem.eql(u8, case.input, "executable")) {
            mode = .executable;
        } else if (std.mem.eql(u8, case.input, "universal")) {
            mode = .universal;
        }
        try testing.expectEqual(case.expected, mode);
    }
}

test "argument parsing - output flag detection" {
    const args = [_][]const u8{ "script.py", "-o", "output", "--mode", "single" };

    var output_path: ?[]const u8 = null;
    var script_path: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i < args.len) {
                output_path = args[i];
            }
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            if (script_path == null) {
                script_path = arg;
            }
        }
    }

    try testing.expectEqualStrings("output", output_path.?);
    try testing.expectEqualStrings("script.py", script_path.?);
}

test "hash hex conversion" {
    // Test the hex conversion used for cache directory names
    const hash = [_]u8{ 0xAB, 0xCD, 0x12, 0x34 };
    var hash_hex: [8]u8 = undefined;
    const hex_chars = "0123456789abcdef";

    for (0..4) |idx| {
        hash_hex[idx * 2] = hex_chars[hash[idx] >> 4];
        hash_hex[idx * 2 + 1] = hex_chars[hash[idx] & 0x0f];
    }

    try testing.expectEqualStrings("abcd1234", &hash_hex);
}

test "import line detection" {
    // Test detection of microcharm import lines for filtering
    const lines = [_][]const u8{
        "from microcharm import style",
        "import microcharm",
        "from microcharm.table import table",
        "import os",
        "print('hello')",
    };

    const expected_skip = [_]bool{ true, true, true, false, false };

    for (lines, 0..) |line, i| {
        const should_skip = std.mem.indexOf(u8, line, "from microcharm") != null or
            std.mem.indexOf(u8, line, "import microcharm") != null;
        try testing.expectEqual(expected_skip[i], should_skip);
    }
}

test "sys.path line detection" {
    const lines = [_][]const u8{
        "sys.path.insert(0, '.')",
        "sys.path.append('/some/path')",
        "print(sys.version)",
        "x = path.join(a, b)",
    };

    const expected_skip = [_]bool{ true, true, false, false };

    for (lines, 0..) |line, i| {
        const should_skip = std.mem.indexOf(u8, line, "sys.path") != null;
        try testing.expectEqual(expected_skip[i], should_skip);
    }
}

test "multiline import detection" {
    // Test detecting opening paren without closing paren
    const test_line = "from microcharm import (";
    const has_open = std.mem.indexOf(u8, test_line, "(") != null;
    const has_close = std.mem.indexOf(u8, test_line, ")") != null;

    try testing.expect(has_open);
    try testing.expect(!has_close);
}

test "base64 encoding length" {
    const encoder = std.base64.standard.Encoder;

    // Test various input lengths
    try testing.expectEqual(@as(usize, 4), encoder.calcSize(1));
    try testing.expectEqual(@as(usize, 4), encoder.calcSize(2));
    try testing.expectEqual(@as(usize, 4), encoder.calcSize(3));
    try testing.expectEqual(@as(usize, 8), encoder.calcSize(4));
    try testing.expectEqual(@as(usize, 8), encoder.calcSize(5));
}

test "block size alignment" {
    const BLOCK_SIZE: usize = 4096;

    // Header must fit within block size
    const sample_header =
        \\#!/bin/bash
        \\H=abcd1234;C="$HOME/.cache/microcharm/$H"
        \\if [ -x "$C/m" ] && [ -f "$C/a.py" ]; then exec "$C/m" "$C/a.py" "$@"; fi
        \\mkdir -p "$C";S="$0"
        \\dd bs=4096 skip=1 if="$S" 2>/dev/null|head -c 700000 >"$C/m";chmod +x "$C/m"
        \\tail -c 50000 "$S">"$C/a.py";exec "$C/m" "$C/a.py" "$@"
        \\
    ;

    try testing.expect(sample_header.len < BLOCK_SIZE);
}

test "trim whitespace" {
    const line = "  from .style import style  \t";
    const trimmed = std.mem.trim(u8, line, " \t");
    try testing.expectEqualStrings("from .style import style", trimmed);
}

test "relative import detection" {
    const lines = [_][]const u8{
        "from .style import style",
        "from .terminal import clear",
        "from style import style",
        "import style",
    };

    const expected_relative = [_]bool{ true, true, false, false };

    for (lines, 0..) |line, i| {
        const trimmed = std.mem.trim(u8, line, " \t");
        const is_relative = std.mem.startsWith(u8, trimmed, "from .");
        try testing.expectEqual(expected_relative[i], is_relative);
    }
}
