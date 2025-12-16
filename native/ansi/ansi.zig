// ansi.zig - ANSI color and style code generation
//
// This module handles color name parsing, hex color parsing,
// and ANSI escape code generation.

const std = @import("std");

// ============================================================================
// Types
// ============================================================================

pub const CStr = [*:0]const u8;

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    valid: bool,
};

pub const ColorIndex = extern struct {
    index: i16, // -1 if not found, 0-15 for standard, 0-255 for 256-color
    is_bright: bool,
};

// ============================================================================
// Color Name Lookup
// ============================================================================

const ColorName = struct {
    name: []const u8,
    index: u8,
};

const standard_colors = [_]ColorName{
    .{ .name = "black", .index = 0 },
    .{ .name = "red", .index = 1 },
    .{ .name = "green", .index = 2 },
    .{ .name = "yellow", .index = 3 },
    .{ .name = "blue", .index = 4 },
    .{ .name = "magenta", .index = 5 },
    .{ .name = "cyan", .index = 6 },
    .{ .name = "white", .index = 7 },
    .{ .name = "gray", .index = 8 },
    .{ .name = "grey", .index = 8 },
};

fn streql_slice(cstr: CStr, slice: []const u8) bool {
    for (slice, 0..) |c, i| {
        if (cstr[i] == 0 or cstr[i] != c) return false;
    }
    return cstr[slice.len] == 0;
}

fn streql_slice_prefix(cstr: CStr, slice: []const u8) bool {
    for (slice, 0..) |c, i| {
        if (cstr[i] == 0 or cstr[i] != c) return false;
    }
    return true;
}

fn to_lower(c: u8) u8 {
    if (c >= 'A' and c <= 'Z') return c + 32;
    return c;
}

/// Look up a color by name, returns index 0-15 or -1 if not found
pub export fn ansi_color_name_to_index(name: CStr) ColorIndex {
    // Check for "bright_" prefix
    if (streql_slice_prefix(name, "bright_")) {
        const base_name: CStr = @ptrCast(name + 7);
        for (standard_colors) |color| {
            if (streql_slice(base_name, color.name)) {
                return .{ .index = color.index + 8, .is_bright = true };
            }
        }
        return .{ .index = -1, .is_bright = false };
    }

    // Check standard colors (case-insensitive first char)
    for (standard_colors) |color| {
        if (streql_slice(name, color.name)) {
            return .{ .index = color.index, .is_bright = false };
        }
    }

    return .{ .index = -1, .is_bright = false };
}

// ============================================================================
// Hex Color Parsing
// ============================================================================

fn hex_digit(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    return null;
}

/// Parse a hex color (#RGB or #RRGGBB)
pub export fn ansi_parse_hex_color(hex: CStr) Color {
    // Must start with #
    if (hex[0] != '#') {
        return .{ .r = 0, .g = 0, .b = 0, .valid = false };
    }

    // Count length
    var len: usize = 0;
    while (hex[len + 1] != 0) : (len += 1) {}

    if (len == 3) {
        // #RGB format
        const r = hex_digit(hex[1]) orelse return .{ .r = 0, .g = 0, .b = 0, .valid = false };
        const g = hex_digit(hex[2]) orelse return .{ .r = 0, .g = 0, .b = 0, .valid = false };
        const b = hex_digit(hex[3]) orelse return .{ .r = 0, .g = 0, .b = 0, .valid = false };
        return .{ .r = r * 17, .g = g * 17, .b = b * 17, .valid = true };
    } else if (len == 6) {
        // #RRGGBB format
        const r1 = hex_digit(hex[1]) orelse return .{ .r = 0, .g = 0, .b = 0, .valid = false };
        const r2 = hex_digit(hex[2]) orelse return .{ .r = 0, .g = 0, .b = 0, .valid = false };
        const g1 = hex_digit(hex[3]) orelse return .{ .r = 0, .g = 0, .b = 0, .valid = false };
        const g2 = hex_digit(hex[4]) orelse return .{ .r = 0, .g = 0, .b = 0, .valid = false };
        const b1 = hex_digit(hex[5]) orelse return .{ .r = 0, .g = 0, .b = 0, .valid = false };
        const b2 = hex_digit(hex[6]) orelse return .{ .r = 0, .g = 0, .b = 0, .valid = false };
        return .{
            .r = r1 * 16 + r2,
            .g = g1 * 16 + g2,
            .b = b1 * 16 + b2,
            .valid = true,
        };
    }

    return .{ .r = 0, .g = 0, .b = 0, .valid = false };
}

/// Check if string starts with #
pub export fn ansi_is_hex_color(str: CStr) bool {
    return str[0] == '#';
}

// ============================================================================
// ANSI Code Generation (into provided buffer)
// ============================================================================

/// Generate foreground color code for 256-color index
pub export fn ansi_fg_256(index: u8, buf: [*]u8) usize {
    // "\x1b[38;5;XXXm" - max 13 chars
    buf[0] = 0x1b;
    buf[1] = '[';
    buf[2] = '3';
    buf[3] = '8';
    buf[4] = ';';
    buf[5] = '5';
    buf[6] = ';';

    var pos: usize = 7;
    if (index >= 100) {
        buf[pos] = '0' + (index / 100);
        pos += 1;
    }
    if (index >= 10) {
        buf[pos] = '0' + ((index / 10) % 10);
        pos += 1;
    }
    buf[pos] = '0' + (index % 10);
    pos += 1;
    buf[pos] = 'm';
    pos += 1;
    buf[pos] = 0;

    return pos;
}

/// Generate background color code for 256-color index
pub export fn ansi_bg_256(index: u8, buf: [*]u8) usize {
    buf[0] = 0x1b;
    buf[1] = '[';
    buf[2] = '4';
    buf[3] = '8';
    buf[4] = ';';
    buf[5] = '5';
    buf[6] = ';';

    var pos: usize = 7;
    if (index >= 100) {
        buf[pos] = '0' + (index / 100);
        pos += 1;
    }
    if (index >= 10) {
        buf[pos] = '0' + ((index / 10) % 10);
        pos += 1;
    }
    buf[pos] = '0' + (index % 10);
    pos += 1;
    buf[pos] = 'm';
    pos += 1;
    buf[pos] = 0;

    return pos;
}

/// Generate foreground RGB color code
pub export fn ansi_fg_rgb(r: u8, g: u8, b: u8, buf: [*]u8) usize {
    // "\x1b[38;2;R;G;Bm"
    buf[0] = 0x1b;
    buf[1] = '[';
    buf[2] = '3';
    buf[3] = '8';
    buf[4] = ';';
    buf[5] = '2';
    buf[6] = ';';

    var pos: usize = 7;
    pos += write_int(buf + pos, r);
    buf[pos] = ';';
    pos += 1;
    pos += write_int(buf + pos, g);
    buf[pos] = ';';
    pos += 1;
    pos += write_int(buf + pos, b);
    buf[pos] = 'm';
    pos += 1;
    buf[pos] = 0;

    return pos;
}

/// Generate background RGB color code
pub export fn ansi_bg_rgb(r: u8, g: u8, b: u8, buf: [*]u8) usize {
    buf[0] = 0x1b;
    buf[1] = '[';
    buf[2] = '4';
    buf[3] = '8';
    buf[4] = ';';
    buf[5] = '2';
    buf[6] = ';';

    var pos: usize = 7;
    pos += write_int(buf + pos, r);
    buf[pos] = ';';
    pos += 1;
    pos += write_int(buf + pos, g);
    buf[pos] = ';';
    pos += 1;
    pos += write_int(buf + pos, b);
    buf[pos] = 'm';
    pos += 1;
    buf[pos] = 0;

    return pos;
}

fn write_int(buf: [*]u8, val: u8) usize {
    var pos: usize = 0;
    if (val >= 100) {
        buf[pos] = '0' + (val / 100);
        pos += 1;
    }
    if (val >= 10) {
        buf[pos] = '0' + ((val / 10) % 10);
        pos += 1;
    }
    buf[pos] = '0' + (val % 10);
    pos += 1;
    return pos;
}

// ============================================================================
// Standard Color Codes
// ============================================================================

// Foreground codes for standard colors (indices 0-15)
const fg_codes = [16][]const u8{
    "30", "31", "32", "33", "34", "35", "36", "37", // standard 0-7
    "90", "91", "92", "93", "94", "95", "96", "97", // bright 8-15
};

// Background codes for standard colors (indices 0-15)
const bg_codes = [16][]const u8{
    "40", "41", "42", "43", "44", "45", "46", "47", // standard 0-7
    "100", "101", "102", "103", "104", "105", "106", "107", // bright 8-15
};

/// Generate foreground code for standard color (0-15)
pub export fn ansi_fg_standard(index: u8, buf: [*]u8) usize {
    if (index >= 16) return 0;

    const code = fg_codes[index];
    buf[0] = 0x1b;
    buf[1] = '[';
    for (code, 0..) |c, i| {
        buf[2 + i] = c;
    }
    buf[2 + code.len] = 'm';
    buf[3 + code.len] = 0;

    return 3 + code.len;
}

/// Generate background code for standard color (0-15)
pub export fn ansi_bg_standard(index: u8, buf: [*]u8) usize {
    if (index >= 16) return 0;

    const code = bg_codes[index];
    buf[0] = 0x1b;
    buf[1] = '[';
    for (code, 0..) |c, i| {
        buf[2 + i] = c;
    }
    buf[2 + code.len] = 'm';
    buf[3 + code.len] = 0;

    return 3 + code.len;
}

// ============================================================================
// Tests
// ============================================================================

test "color_name_to_index" {
    const red = ansi_color_name_to_index("red");
    try std.testing.expectEqual(@as(i16, 1), red.index);
    try std.testing.expect(!red.is_bright);

    const bright_red = ansi_color_name_to_index("bright_red");
    try std.testing.expectEqual(@as(i16, 9), bright_red.index);
    try std.testing.expect(bright_red.is_bright);

    const unknown = ansi_color_name_to_index("purple");
    try std.testing.expectEqual(@as(i16, -1), unknown.index);
}

test "parse_hex_color" {
    const rgb = ansi_parse_hex_color("#ff5500");
    try std.testing.expect(rgb.valid);
    try std.testing.expectEqual(@as(u8, 255), rgb.r);
    try std.testing.expectEqual(@as(u8, 85), rgb.g);
    try std.testing.expectEqual(@as(u8, 0), rgb.b);

    const short = ansi_parse_hex_color("#f50");
    try std.testing.expect(short.valid);
    try std.testing.expectEqual(@as(u8, 255), short.r);
    try std.testing.expectEqual(@as(u8, 85), short.g);
    try std.testing.expectEqual(@as(u8, 0), short.b);

    const invalid = ansi_parse_hex_color("ff5500");
    try std.testing.expect(!invalid.valid);
}

test "fg_256" {
    var buf: [32]u8 = undefined;
    const len = ansi_fg_256(196, &buf);
    try std.testing.expectEqualStrings("\x1b[38;5;196m", buf[0..len]);
}

test "fg_rgb" {
    var buf: [32]u8 = undefined;
    const len = ansi_fg_rgb(255, 100, 0, &buf);
    try std.testing.expectEqualStrings("\x1b[38;2;255;100;0m", buf[0..len]);
}

test "fg_standard" {
    var buf: [32]u8 = undefined;
    const len = ansi_fg_standard(1, &buf); // red
    try std.testing.expectEqualStrings("\x1b[31m", buf[0..len]);

    const len2 = ansi_fg_standard(9, &buf); // bright red
    try std.testing.expectEqualStrings("\x1b[91m", buf[0..len2]);
}
