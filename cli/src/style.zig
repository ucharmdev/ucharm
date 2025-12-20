// style.zig - Shared style definitions for the ucharm CLI
//
// Provides consistent colors, symbols, and formatting utilities.

const std = @import("std");

// ────────────────────────────────────────────────────────────────────────────
// Colors - Consistent palette across all commands
// ────────────────────────────────────────────────────────────────────────────

pub const reset = "\x1b[0m";

// Text styles
pub const bold = "\x1b[1m";
pub const dim = "\x1b[2m";
pub const italic = "\x1b[3m";
pub const underline = "\x1b[4m";

// Base colors
pub const red = "\x1b[31m";
pub const green = "\x1b[32m";
pub const yellow = "\x1b[33m";
pub const blue = "\x1b[34m";
pub const magenta = "\x1b[35m";
pub const cyan = "\x1b[36m";
pub const white = "\x1b[37m";

// Bright colors
pub const bright_red = "\x1b[91m";
pub const bright_green = "\x1b[92m";
pub const bright_yellow = "\x1b[93m";
pub const bright_blue = "\x1b[94m";
pub const bright_magenta = "\x1b[95m";
pub const bright_cyan = "\x1b[96m";

// Brand colors (gradient effect via different shades)
pub const brand = cyan; // Primary brand color
pub const brand_light = bright_cyan;
pub const accent = magenta;
pub const accent_light = bright_magenta;

// Semantic colors
pub const success = green;
pub const warning = yellow;
pub const err = red;
pub const info = cyan;
pub const hint = dim;

// ────────────────────────────────────────────────────────────────────────────
// Symbols - Unicode symbols for prettier output
// ────────────────────────────────────────────────────────────────────────────

pub const symbols = struct {
    // Status indicators
    pub const check = "✓";
    pub const cross = "✗";
    pub const warning_icon = "⚠";
    pub const info_icon = "ℹ";
    pub const question = "?";

    // Arrows and pointers
    pub const arrow_right = "→";
    pub const arrow_left = "←";
    pub const pointer = "▸";
    pub const chevron = "›";

    // Bullets and markers
    pub const bullet = "•";
    pub const dot = "·";
    pub const star = "★";
    pub const diamond = "◆";

    // Box drawing (for borders and separators)
    pub const h_line = "─";
    pub const v_line = "│";
    pub const corner_tl = "┌";
    pub const corner_tr = "┐";
    pub const corner_bl = "└";
    pub const corner_br = "┘";
    pub const t_down = "┬";
    pub const t_up = "┴";
    pub const t_right = "├";
    pub const t_left = "┤";
    pub const cross_box = "┼";

    // Progress
    pub const spinner_frames = [_][]const u8{ "◐", "◓", "◑", "◒" };
    pub const progress_full = "█";
    pub const progress_empty = "░";
    pub const progress_half = "▓";
};

// ────────────────────────────────────────────────────────────────────────────
// Formatting helpers
// ────────────────────────────────────────────────────────────────────────────

/// Creates a horizontal line of the specified width
pub fn line(width: usize) []const u8 {
    const max_width = 80;
    const full_line = "────────────────────────────────────────────────────────────────────────────────";
    const actual_width = @min(width, max_width);
    return full_line[0 .. actual_width * 3]; // UTF-8: each ─ is 3 bytes
}

/// Styled header line (dim line)
pub const header_line = dim ++ "─────────────────────────────────────────" ++ reset;

// ────────────────────────────────────────────────────────────────────────────
// Pre-formatted message prefixes
// ────────────────────────────────────────────────────────────────────────────

// Success prefix: ✓ in green
pub const ok_prefix = success ++ symbols.check ++ reset ++ " ";

// Error prefix: Error: in red
pub const err_prefix = err ++ "Error:" ++ reset ++ " ";

// Warning prefix: ! in yellow
pub const warn_prefix = warning ++ symbols.warning_icon ++ reset ++ " ";

// Info prefix: ℹ in cyan
pub const info_prefix = info ++ symbols.info_icon ++ reset ++ " ";

// Hint prefix: dim bullet
pub const hint_prefix = dim ++ symbols.bullet ++ reset ++ " ";

// Created file prefix: + in green
pub const created_prefix = success ++ "+" ++ reset ++ " ";

// ────────────────────────────────────────────────────────────────────────────
// Command styling
// ────────────────────────────────────────────────────────────────────────────

/// Formats a command name for help text (cyan + bold)
pub fn cmd(name: []const u8) [256]u8 {
    var buf: [256]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, brand ++ "{s}" ++ reset, .{name}) catch {};
    return buf;
}

// ────────────────────────────────────────────────────────────────────────────
// Logo and branding
// ────────────────────────────────────────────────────────────────────────────

pub const logo_small = brand ++ bold ++ "μcharm" ++ reset;

pub const logo_ascii =
    "\n" ++
    cyan ++ "┌┬┐┌─┐┬ ┬┌─┐┬─┐┌┬┐" ++ reset ++ "\n" ++
    cyan ++ "││││  ├─┤├─┤├┬┘│││" ++ reset ++ "\n" ++
    cyan ++ "┴ ┴└─┘┴ ┴┴ ┴┴└─┴ ┴" ++ reset ++ "\n";

pub const tagline = dim ++ "Beautiful CLIs with PocketPy" ++ reset;

// ────────────────────────────────────────────────────────────────────────────
// Help text formatting constants
// ────────────────────────────────────────────────────────────────────────────

// Section headers for help text
pub const section_usage = bold ++ "USAGE" ++ reset;
pub const section_commands = bold ++ "COMMANDS" ++ reset;
pub const section_options = bold ++ "OPTIONS" ++ reset;
pub const section_examples = bold ++ "EXAMPLES" ++ reset;
pub const section_args = bold ++ "ARGUMENTS" ++ reset;

// For raw string help text (use literal escape codes)
pub const help = struct {
    pub const bold_on = "\x1b[1m";
    pub const bold_off = "\x1b[0m";
    pub const dim_on = "\x1b[2m";
    pub const dim_off = "\x1b[0m";
    pub const cyan_on = "\x1b[36m";
    pub const cyan_off = "\x1b[0m";
    pub const green_on = "\x1b[32m";
    pub const green_off = "\x1b[0m";
    pub const yellow_on = "\x1b[33m";
    pub const yellow_off = "\x1b[0m";
    pub const magenta_on = "\x1b[35m";
    pub const magenta_off = "\x1b[0m";
};
