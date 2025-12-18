// tui.zig - Shared TUI library for ucharm
//
// This module provides terminal UI primitives that can be used by both:
// - The CLI application (ucharm binary)
// - Native MicroPython modules (via C bridge)
//
// It includes:
// - ANSI color and style code generation
// - Box drawing with multiple border styles
// - Text alignment and padding
// - Progress bars and spinners
// - Status symbols

const std = @import("std");

// ============================================================================
// ANSI Escape Codes
// ============================================================================

pub const ansi = struct {
    // Reset
    pub const reset = "\x1b[0m";

    // Styles
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";
    pub const italic = "\x1b[3m";
    pub const underline = "\x1b[4m";

    // Standard foreground colors
    pub const black = "\x1b[30m";
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const magenta = "\x1b[35m";
    pub const cyan = "\x1b[36m";
    pub const white = "\x1b[37m";

    // Bright foreground colors
    pub const bright_black = "\x1b[90m";
    pub const gray = "\x1b[90m";
    pub const grey = "\x1b[90m";
    pub const bright_red = "\x1b[91m";
    pub const bright_green = "\x1b[92m";
    pub const bright_yellow = "\x1b[93m";
    pub const bright_blue = "\x1b[94m";
    pub const bright_magenta = "\x1b[95m";
    pub const bright_cyan = "\x1b[96m";
    pub const bright_white = "\x1b[97m";

    // Standard background colors
    pub const bg_black = "\x1b[40m";
    pub const bg_red = "\x1b[41m";
    pub const bg_green = "\x1b[42m";
    pub const bg_yellow = "\x1b[43m";
    pub const bg_blue = "\x1b[44m";
    pub const bg_magenta = "\x1b[45m";
    pub const bg_cyan = "\x1b[46m";
    pub const bg_white = "\x1b[47m";

    // Cursor control
    pub const hide_cursor = "\x1b[?25l";
    pub const show_cursor = "\x1b[?25h";
    pub const clear_line = "\x1b[2K\r";
    pub const clear_screen = "\x1b[2J\x1b[H";

    /// Generate cursor up escape sequence
    pub fn cursorUp(n: usize) [16]u8 {
        var buf: [16]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[{d}A", .{n}) catch {};
        return buf;
    }

    /// Generate 256-color foreground code
    pub fn fg256(index: u8) [16]u8 {
        var buf: [16]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[38;5;{d}m", .{index}) catch {};
        return buf;
    }

    /// Generate 256-color background code
    pub fn bg256(index: u8) [16]u8 {
        var buf: [16]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[48;5;{d}m", .{index}) catch {};
        return buf;
    }

    /// Generate RGB foreground code
    pub fn fgRgb(r: u8, g: u8, b: u8) [24]u8 {
        var buf: [24]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[38;2;{d};{d};{d}m", .{ r, g, b }) catch {};
        return buf;
    }

    /// Generate RGB background code
    pub fn bgRgb(r: u8, g: u8, b: u8) [24]u8 {
        var buf: [24]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[48;2;{d};{d};{d}m", .{ r, g, b }) catch {};
        return buf;
    }
};

// ============================================================================
// Symbols
// ============================================================================

pub const symbols = struct {
    // Status symbols
    pub const success = "\xe2\x9c\x93"; // ✓
    pub const check = "\xe2\x9c\x93"; // ✓
    pub const error_sym = "\xe2\x9c\x97"; // ✗
    pub const cross = "\xe2\x9c\x97"; // ✗
    pub const warning = "\xe2\x9a\xa0"; // ⚠
    pub const info = "\xe2\x84\xb9"; // ℹ
    pub const bullet = "\xe2\x80\xa2"; // •

    // Selection symbols
    pub const pointer = "\xe2\x9d\xaf"; // ❯
    pub const radio_on = "\xe2\x97\x89"; // ◉
    pub const radio_off = "\xe2\x97\x8b"; // ○

    // Progress
    pub const progress_fill = "\xe2\x96\x88"; // █
    pub const progress_empty = "\xe2\x96\x91"; // ░

    // Spinner frames (braille)
    pub const spinner = [_][]const u8{
        "\xe2\xa0\x8b", // ⠋
        "\xe2\xa0\x99", // ⠙
        "\xe2\xa0\xb9", // ⠹
        "\xe2\xa0\xb8", // ⠸
        "\xe2\xa0\xbc", // ⠼
        "\xe2\xa0\xb4", // ⠴
        "\xe2\xa0\xa6", // ⠦
        "\xe2\xa0\xa7", // ⠧
        "\xe2\xa0\x87", // ⠇
        "\xe2\xa0\x8f", // ⠏
    };
};

// ============================================================================
// Box Drawing
// ============================================================================

pub const BorderStyle = enum {
    rounded,
    square,
    double,
    heavy,
    none,
};

pub const BoxChars = struct {
    tl: []const u8, // top-left
    tr: []const u8, // top-right
    bl: []const u8, // bottom-left
    br: []const u8, // bottom-right
    h: []const u8, // horizontal
    v: []const u8, // vertical
};

pub fn getBoxChars(style: BorderStyle) BoxChars {
    return switch (style) {
        .rounded => .{ .tl = "╭", .tr = "╮", .bl = "╰", .br = "╯", .h = "─", .v = "│" },
        .square => .{ .tl = "┌", .tr = "┐", .bl = "└", .br = "┘", .h = "─", .v = "│" },
        .double => .{ .tl = "╔", .tr = "╗", .bl = "╚", .br = "╝", .h = "═", .v = "║" },
        .heavy => .{ .tl = "┏", .tr = "┓", .bl = "┗", .br = "┛", .h = "━", .v = "┃" },
        .none => .{ .tl = " ", .tr = " ", .bl = " ", .br = " ", .h = " ", .v = " " },
    };
}

// ============================================================================
// Text Utilities
// ============================================================================

/// Calculate visible length of string, excluding ANSI escape codes
pub fn visibleLen(s: []const u8) usize {
    var i: usize = 0;
    var length: usize = 0;

    while (i < s.len) {
        if (i + 1 < s.len and s[i] == 0x1b and s[i + 1] == '[') {
            // Skip ANSI escape sequence
            i += 2;
            while (i < s.len and s[i] != 'm' and s[i] != 'H' and s[i] != 'J' and s[i] != 'K') {
                i += 1;
            }
            if (i < s.len) i += 1;
        } else {
            // Count UTF-8 character
            const c = s[i];
            if (c < 128) {
                length += 1;
                i += 1;
            } else if (c < 0xE0) {
                length += 1;
                i += 2;
            } else if (c < 0xF0) {
                length += 2; // Wide chars
                i += 3;
            } else {
                length += 2; // Wide chars
                i += 4;
            }
        }
    }

    return length;
}

/// Alignment options for text padding
pub const Align = enum {
    left,
    right,
    center,
};

/// Pad text to specified width with given alignment
pub fn pad(allocator: std.mem.Allocator, text: []const u8, width: usize, alignment: Align) ![]u8 {
    const vis_len = visibleLen(text);
    if (vis_len >= width) {
        const result = try allocator.alloc(u8, text.len);
        @memcpy(result, text);
        return result;
    }

    const pad_needed = width - vis_len;
    const total_len = text.len + pad_needed;
    const result = try allocator.alloc(u8, total_len);

    switch (alignment) {
        .left => {
            @memcpy(result[0..text.len], text);
            @memset(result[text.len..], ' ');
        },
        .right => {
            @memset(result[0..pad_needed], ' ');
            @memcpy(result[pad_needed..], text);
        },
        .center => {
            const left_pad = pad_needed / 2;
            const right_pad = pad_needed - left_pad;
            @memset(result[0..left_pad], ' ');
            @memcpy(result[left_pad .. left_pad + text.len], text);
            @memset(result[left_pad + text.len ..], ' ');
            _ = right_pad;
        },
    }

    return result;
}

/// Repeat a pattern n times
pub fn repeat(allocator: std.mem.Allocator, pattern: []const u8, count: usize) ![]u8 {
    const result = try allocator.alloc(u8, pattern.len * count);
    var i: usize = 0;
    while (i < count) : (i += 1) {
        @memcpy(result[i * pattern.len .. (i + 1) * pattern.len], pattern);
    }
    return result;
}

// ============================================================================
// High-Level Components
// ============================================================================

/// Writer interface for terminal output
pub const Writer = std.fs.File.Writer;

/// Box renderer for terminal output
pub const Box = struct {
    writer: Writer,
    style: BorderStyle,
    color: ?[]const u8,
    width: usize,
    padding: usize,

    pub fn init(writer: Writer) Box {
        return .{
            .writer = writer,
            .style = .rounded,
            .color = null,
            .width = 40,
            .padding = 1,
        };
    }

    pub fn borderStyle(self: *Box, style: BorderStyle) *Box {
        self.style = style;
        return self;
    }

    pub fn borderColor(self: *Box, color: []const u8) *Box {
        self.color = color;
        return self;
    }

    pub fn setWidth(self: *Box, width: usize) *Box {
        self.width = width;
        return self;
    }

    pub fn setPadding(self: *Box, padding: usize) *Box {
        self.padding = padding;
        return self;
    }

    pub fn render(self: *Box, title: ?[]const u8, content: []const u8) !void {
        const chars = getBoxChars(self.style);
        const inner_width = self.width - 2; // Account for borders

        // Apply color if set
        if (self.color) |c| try self.writer.writeAll(c);
        if (self.color != null) try self.writer.writeAll(ansi.bold);

        // Top border
        try self.writer.writeAll(chars.tl);
        if (title) |t| {
            const title_vis_len = visibleLen(t);
            const dashes_needed = inner_width - title_vis_len - 2; // -2 for spaces around title
            const left_dashes = dashes_needed / 2;
            const right_dashes = dashes_needed - left_dashes;

            var i: usize = 0;
            while (i < left_dashes) : (i += 1) try self.writer.writeAll(chars.h);
            try self.writer.writeAll(" ");
            if (self.color != null) try self.writer.writeAll(ansi.reset);
            try self.writer.writeAll(t);
            if (self.color) |c| try self.writer.writeAll(c);
            if (self.color != null) try self.writer.writeAll(ansi.bold);
            try self.writer.writeAll(" ");
            i = 0;
            while (i < right_dashes) : (i += 1) try self.writer.writeAll(chars.h);
        } else {
            var i: usize = 0;
            while (i < inner_width) : (i += 1) try self.writer.writeAll(chars.h);
        }
        try self.writer.writeAll(chars.tr);
        if (self.color != null) try self.writer.writeAll(ansi.reset);
        try self.writer.writeAll("\n");

        // Content lines with padding
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (self.color) |c| try self.writer.writeAll(c);
            if (self.color != null) try self.writer.writeAll(ansi.bold);
            try self.writer.writeAll(chars.v);
            if (self.color != null) try self.writer.writeAll(ansi.reset);

            // Left padding
            var p: usize = 0;
            while (p < self.padding) : (p += 1) try self.writer.writeAll(" ");

            // Content (pad to fill width)
            const line_vis_len = visibleLen(line);
            const content_width = inner_width - (self.padding * 2);
            try self.writer.writeAll(line);
            if (line_vis_len < content_width) {
                var s: usize = 0;
                while (s < content_width - line_vis_len) : (s += 1) try self.writer.writeAll(" ");
            }

            // Right padding
            p = 0;
            while (p < self.padding) : (p += 1) try self.writer.writeAll(" ");

            if (self.color) |c| try self.writer.writeAll(c);
            if (self.color != null) try self.writer.writeAll(ansi.bold);
            try self.writer.writeAll(chars.v);
            if (self.color != null) try self.writer.writeAll(ansi.reset);
            try self.writer.writeAll("\n");
        }

        // Bottom border
        if (self.color) |c| try self.writer.writeAll(c);
        if (self.color != null) try self.writer.writeAll(ansi.bold);
        try self.writer.writeAll(chars.bl);
        var i: usize = 0;
        while (i < inner_width) : (i += 1) try self.writer.writeAll(chars.h);
        try self.writer.writeAll(chars.br);
        if (self.color != null) try self.writer.writeAll(ansi.reset);
        try self.writer.writeAll("\n");
    }
};

/// Print a status message with symbol
pub fn printStatus(writer: Writer, status: enum { success, err, warning, info }, message: []const u8) !void {
    switch (status) {
        .success => {
            try writer.writeAll(ansi.green);
            try writer.writeAll(symbols.success);
            try writer.writeAll(ansi.reset);
        },
        .err => {
            try writer.writeAll(ansi.red);
            try writer.writeAll(symbols.error_sym);
            try writer.writeAll(ansi.reset);
        },
        .warning => {
            try writer.writeAll(ansi.yellow);
            try writer.writeAll(symbols.warning);
            try writer.writeAll(ansi.reset);
        },
        .info => {
            try writer.writeAll(ansi.cyan);
            try writer.writeAll(symbols.info);
            try writer.writeAll(ansi.reset);
        },
    }
    try writer.writeAll(" ");
    try writer.writeAll(message);
    try writer.writeAll("\n");
}

/// Render a horizontal rule
pub fn rule(writer: Writer, width: usize, style: BorderStyle) !void {
    const chars = getBoxChars(style);
    var i: usize = 0;
    while (i < width) : (i += 1) {
        try writer.writeAll(chars.h);
    }
    try writer.writeAll("\n");
}

/// Render a progress bar
pub fn progressBar(writer: Writer, current: usize, total: usize, width: usize) !void {
    if (total == 0) return;

    const filled = @min(width, (width * current) / total);
    var i: usize = 0;
    while (i < filled) : (i += 1) {
        try writer.writeAll(symbols.progress_fill);
    }
    while (i < width) : (i += 1) {
        try writer.writeAll(symbols.progress_empty);
    }
}

// ============================================================================
// Tests
// ============================================================================

test "visibleLen" {
    try std.testing.expectEqual(@as(usize, 5), visibleLen("hello"));
    try std.testing.expectEqual(@as(usize, 5), visibleLen("\x1b[31mhello\x1b[0m"));
    try std.testing.expectEqual(@as(usize, 0), visibleLen(""));
}

test "getBoxChars" {
    const rounded = getBoxChars(.rounded);
    try std.testing.expectEqualStrings("╭", rounded.tl);
    try std.testing.expectEqualStrings("─", rounded.h);
}
