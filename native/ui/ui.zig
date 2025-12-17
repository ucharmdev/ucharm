// ui.zig - UI rendering utilities for ucharm
//
// This module provides:
// - visible_len: Get visible length of string (excluding ANSI codes)
// - pad: Pad text to width with alignment
// - box: Draw boxes with various border styles
// - table: Render tables
// - progress_bar: Generate progress bar strings

const std = @import("std");

// ============================================================================
// Types
// ============================================================================

pub const CStr = [*:0]const u8;

pub const Alignment = enum(u8) {
    left = 0,
    right = 1,
    center = 2,
};

pub const BorderStyle = enum(u8) {
    rounded = 0,
    square = 1,
    double = 2,
    heavy = 3,
    none = 4,
};

pub const BoxChars = struct {
    tl: []const u8, // top-left
    tr: []const u8, // top-right
    bl: []const u8, // bottom-left
    br: []const u8, // bottom-right
    h: []const u8, // horizontal
    v: []const u8, // vertical
};

const box_styles = [_]BoxChars{
    // rounded
    .{ .tl = "╭", .tr = "╮", .bl = "╰", .br = "╯", .h = "─", .v = "│" },
    // square
    .{ .tl = "┌", .tr = "┐", .bl = "└", .br = "┘", .h = "─", .v = "│" },
    // double
    .{ .tl = "╔", .tr = "╗", .bl = "╚", .br = "╝", .h = "═", .v = "║" },
    // heavy
    .{ .tl = "┏", .tr = "┓", .bl = "┗", .br = "┛", .h = "━", .v = "┃" },
    // none (spaces)
    .{ .tl = " ", .tr = " ", .bl = " ", .br = " ", .h = " ", .v = " " },
};

// ============================================================================
// String Utilities
// ============================================================================

/// Get visible length of string, excluding ANSI escape codes
/// ANSI codes are: ESC [ ... m (and other single-letter terminators)
pub export fn ui_visible_len(str: CStr) usize {
    var len: usize = 0;
    var i: usize = 0;

    while (str[i] != 0) {
        // Check for ANSI escape sequence: ESC [
        if (str[i] == 0x1b and str[i + 1] == '[') {
            // Skip ESC [
            i += 2;
            // Skip until we hit a letter (m, H, J, K, etc.)
            while (str[i] != 0) {
                const c = str[i];
                i += 1;
                // Letters A-Z and a-z terminate the sequence
                if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z')) {
                    break;
                }
            }
        } else {
            // Regular character - but handle UTF-8
            const byte = str[i];
            if (byte < 0x80) {
                // ASCII
                len += 1;
                i += 1;
            } else if (byte < 0xC0) {
                // Continuation byte (shouldn't happen at start)
                i += 1;
            } else if (byte < 0xE0) {
                // 2-byte UTF-8
                len += 1;
                i += 2;
            } else if (byte < 0xF0) {
                // 3-byte UTF-8
                len += 1;
                i += 3;
            } else {
                // 4-byte UTF-8
                len += 1;
                i += 4;
            }
        }
    }

    return len;
}

/// Get byte length of string (for buffer sizing)
pub export fn ui_byte_len(str: CStr) usize {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    return i;
}

/// Copy string to buffer, return bytes written
pub export fn ui_strcpy(dest: [*]u8, src: CStr) usize {
    var i: usize = 0;
    while (src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }
    dest[i] = 0;
    return i;
}

/// Pad text to width with alignment, writes to buffer
/// Returns bytes written (not including null terminator)
pub export fn ui_pad(buf: [*]u8, text: CStr, width: usize, alignment: Alignment) usize {
    const visible = ui_visible_len(text);

    if (visible >= width) {
        // No padding needed, just copy
        return ui_strcpy(buf, text);
    }

    const padding = width - visible;
    var pos: usize = 0;

    switch (alignment) {
        .left => {
            // Text first, then spaces
            pos += ui_strcpy(buf + pos, text);
            for (0..padding) |_| {
                buf[pos] = ' ';
                pos += 1;
            }
        },
        .right => {
            // Spaces first, then text
            for (0..padding) |_| {
                buf[pos] = ' ';
                pos += 1;
            }
            pos += ui_strcpy(buf + pos, text);
        },
        .center => {
            // Half spaces, text, half spaces
            const left = padding / 2;
            const right = padding - left;
            for (0..left) |_| {
                buf[pos] = ' ';
                pos += 1;
            }
            pos += ui_strcpy(buf + pos, text);
            for (0..right) |_| {
                buf[pos] = ' ';
                pos += 1;
            }
        },
    }

    buf[pos] = 0;
    return pos;
}

/// Repeat a character n times into buffer
pub export fn ui_repeat_char(buf: [*]u8, char: u8, count: usize) usize {
    for (0..count) |i| {
        buf[i] = char;
    }
    buf[count] = 0;
    return count;
}

/// Repeat a UTF-8 string n times into buffer
pub export fn ui_repeat_str(buf: [*]u8, str: CStr, count: usize) usize {
    const str_len = ui_byte_len(str);
    var pos: usize = 0;

    for (0..count) |_| {
        for (0..str_len) |j| {
            buf[pos] = str[j];
            pos += 1;
        }
    }
    buf[pos] = 0;
    return pos;
}

// ============================================================================
// Progress Bar
// ============================================================================

/// Generate a progress bar string
/// fill_char and empty_char are single UTF-8 characters (as null-terminated strings)
pub export fn ui_progress_bar(
    buf: [*]u8,
    current: usize,
    total: usize,
    width: usize,
    fill_char: CStr,
    empty_char: CStr,
) usize {
    if (total == 0 or width == 0) {
        buf[0] = 0;
        return 0;
    }

    const ratio = @min(current, total) * width / total;
    var pos: usize = 0;

    // Filled portion
    pos += ui_repeat_str(buf + pos, fill_char, ratio);

    // Empty portion
    pos += ui_repeat_str(buf + pos, empty_char, width - ratio);

    return pos;
}

/// Generate percentage string (e.g., "42%")
pub export fn ui_percent_str(buf: [*]u8, current: usize, total: usize) usize {
    if (total == 0) {
        buf[0] = '0';
        buf[1] = '%';
        buf[2] = 0;
        return 2;
    }

    const percent = current * 100 / total;
    var pos: usize = 0;

    if (percent >= 100) {
        buf[0] = '1';
        buf[1] = '0';
        buf[2] = '0';
        pos = 3;
    } else if (percent >= 10) {
        buf[0] = '0' + @as(u8, @intCast(percent / 10));
        buf[1] = '0' + @as(u8, @intCast(percent % 10));
        pos = 2;
    } else {
        buf[0] = '0' + @as(u8, @intCast(percent));
        pos = 1;
    }

    buf[pos] = '%';
    pos += 1;
    buf[pos] = 0;

    return pos;
}

// ============================================================================
// Box Drawing
// ============================================================================

/// Get box characters for a style
pub export fn ui_box_char_tl(style_idx: u8) CStr {
    if (style_idx >= box_styles.len) return " ";
    return @ptrCast(box_styles[style_idx].tl.ptr);
}

pub export fn ui_box_char_tr(style_idx: u8) CStr {
    if (style_idx >= box_styles.len) return " ";
    return @ptrCast(box_styles[style_idx].tr.ptr);
}

pub export fn ui_box_char_bl(style_idx: u8) CStr {
    if (style_idx >= box_styles.len) return " ";
    return @ptrCast(box_styles[style_idx].bl.ptr);
}

pub export fn ui_box_char_br(style_idx: u8) CStr {
    if (style_idx >= box_styles.len) return " ";
    return @ptrCast(box_styles[style_idx].br.ptr);
}

pub export fn ui_box_char_h(style_idx: u8) CStr {
    if (style_idx >= box_styles.len) return " ";
    return @ptrCast(box_styles[style_idx].h.ptr);
}

pub export fn ui_box_char_v(style_idx: u8) CStr {
    if (style_idx >= box_styles.len) return " ";
    return @ptrCast(box_styles[style_idx].v.ptr);
}

/// Build top border of box
/// Format: tl + h*width + tr
pub export fn ui_box_top(buf: [*]u8, width: usize, style_idx: u8) usize {
    const chars = if (style_idx < box_styles.len) box_styles[style_idx] else box_styles[0];
    var pos: usize = 0;

    // Top-left corner
    for (chars.tl) |c| {
        buf[pos] = c;
        pos += 1;
    }

    // Horizontal line
    for (0..width) |_| {
        for (chars.h) |c| {
            buf[pos] = c;
            pos += 1;
        }
    }

    // Top-right corner
    for (chars.tr) |c| {
        buf[pos] = c;
        pos += 1;
    }

    buf[pos] = 0;
    return pos;
}

/// Build bottom border of box
pub export fn ui_box_bottom(buf: [*]u8, width: usize, style_idx: u8) usize {
    const chars = if (style_idx < box_styles.len) box_styles[style_idx] else box_styles[0];
    var pos: usize = 0;

    for (chars.bl) |c| {
        buf[pos] = c;
        pos += 1;
    }

    for (0..width) |_| {
        for (chars.h) |c| {
            buf[pos] = c;
            pos += 1;
        }
    }

    for (chars.br) |c| {
        buf[pos] = c;
        pos += 1;
    }

    buf[pos] = 0;
    return pos;
}

/// Build middle row of box (vertical bars on sides)
pub export fn ui_box_middle(buf: [*]u8, content: CStr, width: usize, style_idx: u8, padding: usize) usize {
    const chars = if (style_idx < box_styles.len) box_styles[style_idx] else box_styles[0];
    var pos: usize = 0;

    // Left vertical
    for (chars.v) |c| {
        buf[pos] = c;
        pos += 1;
    }

    // Left padding
    for (0..padding) |_| {
        buf[pos] = ' ';
        pos += 1;
    }

    // Content
    pos += ui_strcpy(buf + pos, content);

    // Right padding to fill width
    const content_visible = ui_visible_len(content);
    const content_width = width - (padding * 2);
    if (content_visible < content_width) {
        for (0..(content_width - content_visible)) |_| {
            buf[pos] = ' ';
            pos += 1;
        }
    }

    // Right padding
    for (0..padding) |_| {
        buf[pos] = ' ';
        pos += 1;
    }

    // Right vertical
    for (chars.v) |c| {
        buf[pos] = c;
        pos += 1;
    }

    buf[pos] = 0;
    return pos;
}

// ============================================================================
// Horizontal Rule
// ============================================================================

/// Build a horizontal rule
pub export fn ui_rule(buf: [*]u8, width: usize, char: CStr) usize {
    return ui_repeat_str(buf, char, width);
}

/// Build a horizontal rule with centered title
pub export fn ui_rule_with_title(buf: [*]u8, width: usize, title: CStr, char: CStr) usize {
    const title_visible = ui_visible_len(title);

    // Format: ───── title ─────
    const side_len = if (width > title_visible + 4) (width - title_visible - 2) / 2 else 0;
    var pos: usize = 0;

    // Left side
    pos += ui_repeat_str(buf + pos, char, side_len);

    // Space + title + space
    buf[pos] = ' ';
    pos += 1;
    pos += ui_strcpy(buf + pos, title);
    buf[pos] = ' ';
    pos += 1;

    // Right side (may need adjustment for odd widths)
    const remaining = if (width > pos) width - ui_visible_len(@ptrCast(buf)) else 0;
    pos += ui_repeat_str(buf + pos, char, remaining);

    return pos;
}

// ============================================================================
// Spinner Frames
// ============================================================================

const spinner_frames = [_][]const u8{
    "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏",
};

pub export fn ui_spinner_frame(index: usize) CStr {
    const frame = spinner_frames[index % spinner_frames.len];
    return @ptrCast(frame.ptr);
}

pub export fn ui_spinner_frame_count() usize {
    return spinner_frames.len;
}

// ============================================================================
// Status Symbols
// ============================================================================

pub export fn ui_symbol_success() CStr {
    return "✓";
}

pub export fn ui_symbol_error() CStr {
    return "✗";
}

pub export fn ui_symbol_warning() CStr {
    return "⚠";
}

pub export fn ui_symbol_info() CStr {
    return "ℹ";
}

pub export fn ui_symbol_bullet() CStr {
    return "●";
}

pub export fn ui_symbol_arrow() CStr {
    return ">";
}

pub export fn ui_symbol_checkbox_checked() CStr {
    return "[x]";
}

pub export fn ui_symbol_checkbox_unchecked() CStr {
    return "[ ]";
}

// ============================================================================
// Table Rendering
// ============================================================================

/// Table border characters
pub const TableChars = struct {
    h: []const u8, // horizontal
    v: []const u8, // vertical
    tl: []const u8, // top-left
    tr: []const u8, // top-right
    bl: []const u8, // bottom-left
    br: []const u8, // bottom-right
    t_down: []const u8, // T pointing down (top border)
    t_up: []const u8, // T pointing up (bottom border)
    t_left: []const u8, // T pointing left
    t_right: []const u8, // T pointing right
    cross: []const u8, // cross
};

const table_chars = TableChars{
    .h = "─",
    .v = "│",
    .tl = "┌",
    .tr = "┐",
    .bl = "└",
    .br = "┘",
    .t_down = "┬",
    .t_up = "┴",
    .t_left = "┤",
    .t_right = "├",
    .cross = "┼",
};

/// Get table character
pub export fn ui_table_char_h() CStr {
    return @ptrCast(table_chars.h.ptr);
}

pub export fn ui_table_char_v() CStr {
    return @ptrCast(table_chars.v.ptr);
}

pub export fn ui_table_char_tl() CStr {
    return @ptrCast(table_chars.tl.ptr);
}

pub export fn ui_table_char_tr() CStr {
    return @ptrCast(table_chars.tr.ptr);
}

pub export fn ui_table_char_bl() CStr {
    return @ptrCast(table_chars.bl.ptr);
}

pub export fn ui_table_char_br() CStr {
    return @ptrCast(table_chars.br.ptr);
}

pub export fn ui_table_char_t_down() CStr {
    return @ptrCast(table_chars.t_down.ptr);
}

pub export fn ui_table_char_t_up() CStr {
    return @ptrCast(table_chars.t_up.ptr);
}

pub export fn ui_table_char_t_left() CStr {
    return @ptrCast(table_chars.t_left.ptr);
}

pub export fn ui_table_char_t_right() CStr {
    return @ptrCast(table_chars.t_right.ptr);
}

pub export fn ui_table_char_cross() CStr {
    return @ptrCast(table_chars.cross.ptr);
}

/// Build table top border: ┌───┬───┐
/// col_widths is an array of widths, num_cols is the count
pub export fn ui_table_top(buf: [*]u8, col_widths: [*]const usize, num_cols: usize) usize {
    var pos: usize = 0;

    // Top-left corner
    for (table_chars.tl) |c| {
        buf[pos] = c;
        pos += 1;
    }

    for (0..num_cols) |i| {
        // Horizontal for column width
        const width = col_widths[i];
        for (0..width) |_| {
            for (table_chars.h) |c| {
                buf[pos] = c;
                pos += 1;
            }
        }

        // T-down or top-right
        if (i < num_cols - 1) {
            for (table_chars.t_down) |c| {
                buf[pos] = c;
                pos += 1;
            }
        } else {
            for (table_chars.tr) |c| {
                buf[pos] = c;
                pos += 1;
            }
        }
    }

    buf[pos] = 0;
    return pos;
}

/// Build table middle divider: ├───┼───┤
pub export fn ui_table_divider(buf: [*]u8, col_widths: [*]const usize, num_cols: usize) usize {
    var pos: usize = 0;

    // T-right
    for (table_chars.t_right) |c| {
        buf[pos] = c;
        pos += 1;
    }

    for (0..num_cols) |i| {
        const width = col_widths[i];
        for (0..width) |_| {
            for (table_chars.h) |c| {
                buf[pos] = c;
                pos += 1;
            }
        }

        // Cross or T-left
        if (i < num_cols - 1) {
            for (table_chars.cross) |c| {
                buf[pos] = c;
                pos += 1;
            }
        } else {
            for (table_chars.t_left) |c| {
                buf[pos] = c;
                pos += 1;
            }
        }
    }

    buf[pos] = 0;
    return pos;
}

/// Build table bottom border: └───┴───┘
pub export fn ui_table_bottom(buf: [*]u8, col_widths: [*]const usize, num_cols: usize) usize {
    var pos: usize = 0;

    // Bottom-left
    for (table_chars.bl) |c| {
        buf[pos] = c;
        pos += 1;
    }

    for (0..num_cols) |i| {
        const width = col_widths[i];
        for (0..width) |_| {
            for (table_chars.h) |c| {
                buf[pos] = c;
                pos += 1;
            }
        }

        // T-up or bottom-right
        if (i < num_cols - 1) {
            for (table_chars.t_up) |c| {
                buf[pos] = c;
                pos += 1;
            }
        } else {
            for (table_chars.br) |c| {
                buf[pos] = c;
                pos += 1;
            }
        }
    }

    buf[pos] = 0;
    return pos;
}

/// Build a single table cell with padding and alignment
/// Returns bytes written
pub export fn ui_table_cell(buf: [*]u8, content: CStr, width: usize, alignment: Alignment, padding: usize) usize {
    var pos: usize = 0;

    // Left padding
    for (0..padding) |_| {
        buf[pos] = ' ';
        pos += 1;
    }

    // Content with alignment (width minus padding on both sides)
    const content_width = width - (padding * 2);
    pos += ui_pad(buf + pos, content, content_width, alignment);

    // Right padding
    for (0..padding) |_| {
        buf[pos] = ' ';
        pos += 1;
    }

    buf[pos] = 0;
    return pos;
}

// ============================================================================
// Input Helpers
// ============================================================================

/// Selection indicator
pub export fn ui_select_indicator() CStr {
    return "> ";
}

/// Checkbox checked
pub export fn ui_checkbox_on() CStr {
    return "[x]";
}

/// Checkbox unchecked
pub export fn ui_checkbox_off() CStr {
    return "[ ]";
}

/// Question mark prompt prefix
pub export fn ui_prompt_question() CStr {
    return "? ";
}

/// Success prompt prefix
pub export fn ui_prompt_success() CStr {
    return "* ";
}

// ============================================================================
// ANSI cursor movement strings
// ============================================================================

/// Move cursor up n lines - writes escape sequence to buffer
pub export fn ui_cursor_up(buf: [*]u8, n: usize) usize {
    // ESC [ n A
    buf[0] = 0x1b;
    buf[1] = '[';
    var pos: usize = 2;

    // Write number
    if (n == 0) {
        buf[pos] = '0';
        pos += 1;
    } else {
        var num = n;
        var digits: [10]u8 = undefined;
        var digit_count: usize = 0;
        while (num > 0) {
            digits[digit_count] = '0' + @as(u8, @intCast(num % 10));
            digit_count += 1;
            num /= 10;
        }
        // Reverse digits
        while (digit_count > 0) {
            digit_count -= 1;
            buf[pos] = digits[digit_count];
            pos += 1;
        }
    }

    buf[pos] = 'A';
    pos += 1;
    buf[pos] = 0;
    return pos;
}

/// Move cursor down n lines
pub export fn ui_cursor_down(buf: [*]u8, n: usize) usize {
    buf[0] = 0x1b;
    buf[1] = '[';
    var pos: usize = 2;

    if (n == 0) {
        buf[pos] = '0';
        pos += 1;
    } else {
        var num = n;
        var digits: [10]u8 = undefined;
        var digit_count: usize = 0;
        while (num > 0) {
            digits[digit_count] = '0' + @as(u8, @intCast(num % 10));
            digit_count += 1;
            num /= 10;
        }
        while (digit_count > 0) {
            digit_count -= 1;
            buf[pos] = digits[digit_count];
            pos += 1;
        }
    }

    buf[pos] = 'B';
    pos += 1;
    buf[pos] = 0;
    return pos;
}

/// Clear line escape sequence
pub export fn ui_clear_line() CStr {
    return "\x1b[2K\r";
}

/// Hide cursor escape sequence
pub export fn ui_hide_cursor() CStr {
    return "\x1b[?25l";
}

/// Show cursor escape sequence
pub export fn ui_show_cursor() CStr {
    return "\x1b[?25h";
}

// ============================================================================
// Tests
// ============================================================================

test "visible_len" {
    // Plain text
    try std.testing.expectEqual(@as(usize, 5), ui_visible_len("hello"));

    // With ANSI codes
    try std.testing.expectEqual(@as(usize, 5), ui_visible_len("\x1b[31mhello\x1b[0m"));
    try std.testing.expectEqual(@as(usize, 4), ui_visible_len("\x1b[1;31mtest\x1b[0m"));

    // Empty
    try std.testing.expectEqual(@as(usize, 0), ui_visible_len(""));
}

test "pad" {
    var buf: [64]u8 = undefined;

    // Left align
    _ = ui_pad(&buf, "hi", 5, .left);
    try std.testing.expectEqualStrings("hi   ", buf[0..5]);

    // Right align
    _ = ui_pad(&buf, "hi", 5, .right);
    try std.testing.expectEqualStrings("   hi", buf[0..5]);

    // Center align
    _ = ui_pad(&buf, "hi", 6, .center);
    try std.testing.expectEqualStrings("  hi  ", buf[0..6]);
}

test "progress_bar" {
    var buf: [64]u8 = undefined;

    const len = ui_progress_bar(&buf, 50, 100, 10, "█", "░");
    try std.testing.expectEqual(@as(usize, 30), len); // 10 * 3 bytes per char
}

test "box_top" {
    var buf: [128]u8 = undefined;

    _ = ui_box_top(&buf, 5, 0); // rounded
    // Should be: ╭─────╮
    try std.testing.expect(buf[0] != 0);
}
