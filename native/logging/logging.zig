// logging.zig - Native logging implementation for MicroPython
// Provides fast timestamp formatting and log level filtering

const std = @import("std");

// Log levels (match Python's logging module)
pub const LogLevel = enum(u32) {
    NOTSET = 0,
    DEBUG = 10,
    INFO = 20,
    WARNING = 30,
    ERROR = 40,
    CRITICAL = 50,
};

// Current log level
var current_level: u32 = @intFromEnum(LogLevel.WARNING);

// Log level names
const level_names = [_][]const u8{
    "NOTSET", // 0
    "DEBUG", // 10
    "INFO", // 20
    "WARNING", // 30
    "ERROR", // 40
    "CRITICAL", // 50
};

// Set log level
pub export fn logging_set_level(level: u32) void {
    current_level = level;
}

// Get log level
pub export fn logging_get_level() u32 {
    return current_level;
}

// Check if a message at given level would be logged
pub export fn logging_is_enabled(level: u32) bool {
    return level >= current_level;
}

// Get level name (returns pointer to static string)
pub export fn logging_level_name(level: u32, out_ptr: [*]u8, out_max: usize) usize {
    const name = switch (level) {
        0...9 => "NOTSET",
        10...19 => "DEBUG",
        20...29 => "INFO",
        30...39 => "WARNING",
        40...49 => "ERROR",
        else => "CRITICAL",
    };

    const len = @min(name.len, out_max);
    @memcpy(out_ptr[0..len], name[0..len]);
    return name.len;
}

// Parse level from name
pub export fn logging_parse_level(name_ptr: [*]const u8, name_len: usize) i32 {
    if (name_len == 0) return -1;

    const name = name_ptr[0..name_len];

    // Case-insensitive comparison
    if (eqlIgnoreCase(name, "NOTSET")) return 0;
    if (eqlIgnoreCase(name, "DEBUG")) return 10;
    if (eqlIgnoreCase(name, "INFO")) return 20;
    if (eqlIgnoreCase(name, "WARNING") or eqlIgnoreCase(name, "WARN")) return 30;
    if (eqlIgnoreCase(name, "ERROR")) return 40;
    if (eqlIgnoreCase(name, "CRITICAL") or eqlIgnoreCase(name, "FATAL")) return 50;

    return -1;
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        const la = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const lb = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (la != lb) return false;
    }
    return true;
}

// Format timestamp (ISO 8601 style: YYYY-MM-DD HH:MM:SS)
// Takes Unix timestamp, returns formatted string length
pub export fn logging_format_timestamp(
    timestamp: i64,
    out_ptr: [*]u8,
    out_max: usize,
) usize {
    if (out_max < 19) return 0; // Need at least "YYYY-MM-DD HH:MM:SS"

    // Convert Unix timestamp to components
    // Days since epoch
    var days = @divFloor(timestamp, 86400);
    var remaining = @mod(timestamp, 86400);
    if (remaining < 0) {
        remaining += 86400;
        days -= 1;
    }

    const hours: u32 = @intCast(@divFloor(remaining, 3600));
    remaining = @mod(remaining, 3600);
    const minutes: u32 = @intCast(@divFloor(remaining, 60));
    const seconds: u32 = @intCast(@mod(remaining, 60));

    // Calculate year, month, day from days since 1970-01-01
    var year: i32 = 1970;
    var day_of_year: i32 = @intCast(days);

    while (true) {
        const days_in_year: i32 = if (isLeapYear(year)) 366 else 365;
        if (day_of_year < days_in_year) break;
        day_of_year -= days_in_year;
        year += 1;
    }

    // Month and day
    const days_in_months = if (isLeapYear(year))
        [_]i32{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    else
        [_]i32{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

    var month: u32 = 1;
    for (days_in_months) |dim| {
        if (day_of_year < dim) break;
        day_of_year -= dim;
        month += 1;
    }
    const day: u32 = @intCast(day_of_year + 1);

    // Format: YYYY-MM-DD HH:MM:SS
    const uyear: u32 = @intCast(year);
    out_ptr[0] = '0' + @as(u8, @intCast(uyear / 1000));
    out_ptr[1] = '0' + @as(u8, @intCast((uyear / 100) % 10));
    out_ptr[2] = '0' + @as(u8, @intCast((uyear / 10) % 10));
    out_ptr[3] = '0' + @as(u8, @intCast(uyear % 10));
    out_ptr[4] = '-';
    out_ptr[5] = '0' + @as(u8, @intCast(month / 10));
    out_ptr[6] = '0' + @as(u8, @intCast(month % 10));
    out_ptr[7] = '-';
    out_ptr[8] = '0' + @as(u8, @intCast(day / 10));
    out_ptr[9] = '0' + @as(u8, @intCast(day % 10));
    out_ptr[10] = ' ';
    out_ptr[11] = '0' + @as(u8, @intCast(hours / 10));
    out_ptr[12] = '0' + @as(u8, @intCast(hours % 10));
    out_ptr[13] = ':';
    out_ptr[14] = '0' + @as(u8, @intCast(minutes / 10));
    out_ptr[15] = '0' + @as(u8, @intCast(minutes % 10));
    out_ptr[16] = ':';
    out_ptr[17] = '0' + @as(u8, @intCast(seconds / 10));
    out_ptr[18] = '0' + @as(u8, @intCast(seconds % 10));

    return 19;
}

fn isLeapYear(year: i32) bool {
    if (@mod(year, 400) == 0) return true;
    if (@mod(year, 100) == 0) return false;
    if (@mod(year, 4) == 0) return true;
    return false;
}

// Format a basic log message: "LEVEL - message"
pub export fn logging_format_basic(
    level: u32,
    msg_ptr: [*]const u8,
    msg_len: usize,
    out_ptr: [*]u8,
    out_max: usize,
) usize {
    var out_idx: usize = 0;

    // Level name
    const level_len = logging_level_name(level, out_ptr + out_idx, out_max - out_idx);
    out_idx += level_len;

    // Separator
    if (out_idx + 3 > out_max) return out_idx;
    out_ptr[out_idx] = ' ';
    out_ptr[out_idx + 1] = '-';
    out_ptr[out_idx + 2] = ' ';
    out_idx += 3;

    // Message
    const msg_copy_len = @min(msg_len, out_max - out_idx);
    @memcpy(out_ptr[out_idx..][0..msg_copy_len], msg_ptr[0..msg_copy_len]);
    out_idx += msg_copy_len;

    return out_idx;
}
