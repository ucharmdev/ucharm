// datetime.zig - Date and time operations
// Provides C-ABI compatible functions for datetime manipulation

const std = @import("std");

// ============================================================================
// Types
// ============================================================================

pub const DateTime = extern struct {
    year: i32,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    microsecond: u32,
};

pub const TimeDelta = extern struct {
    days: i32,
    seconds: i32,
    microseconds: i32,
};

// ============================================================================
// Constants
// ============================================================================

const DAYS_IN_MONTH = [_]u8{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
const DAYS_BEFORE_MONTH = [_]u16{ 0, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };

// ============================================================================
// Helper Functions
// ============================================================================

fn isLeapYear(year: i32) bool {
    if (@mod(year, 4) != 0) return false;
    if (@mod(year, 100) != 0) return true;
    return @mod(year, 400) == 0;
}

fn daysInMonth(year: i32, month: u8) u8 {
    if (month == 2 and isLeapYear(year)) return 29;
    return DAYS_IN_MONTH[month];
}

fn daysBeforeYear(year: i32) i64 {
    const y = year - 1;
    return @as(i64, y) * 365 + @divFloor(y, 4) - @divFloor(y, 100) + @divFloor(y, 400);
}

fn daysBeforeMonth(year: i32, month: u8) u16 {
    var days = DAYS_BEFORE_MONTH[month];
    if (month > 2 and isLeapYear(year)) {
        days += 1;
    }
    return days;
}

fn ymdToOrdinal(year: i32, month: u8, day: u8) i64 {
    return daysBeforeYear(year) + @as(i64, daysBeforeMonth(year, month)) + @as(i64, day);
}

fn ordinalToYmd(ordinal: i64) struct { year: i32, month: u8, day: u8 } {
    // Approximate year
    var y: i32 = @intCast(@divFloor(ordinal, 365));

    // Adjust year - find the correct year
    while (daysBeforeYear(y) >= ordinal) {
        y -= 1;
    }
    while (daysBeforeYear(y + 1) < ordinal) {
        y += 1;
    }

    // Day of year
    var doy: u16 = @intCast(ordinal - daysBeforeYear(y));

    // Find month
    const leap = isLeapYear(y);
    var m: u8 = 1;
    while (m <= 12) : (m += 1) {
        const dim = if (m == 2 and leap) @as(u8, 29) else DAYS_IN_MONTH[m];
        if (doy <= dim) {
            return .{ .year = y, .month = m, .day = @intCast(doy) };
        }
        doy -= dim;
    }

    return .{ .year = y, .month = 12, .day = 31 };
}

// ============================================================================
// DateTime Functions
// ============================================================================

/// Get current local time
pub export fn datetime_now() DateTime {
    const ts = std.time.timestamp();
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };
    const day = epoch.getEpochDay();
    const year_day = day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_secs = epoch.getDaySeconds();

    return DateTime{
        .year = year_day.year,
        .month = month_day.month.numeric(),
        .day = month_day.day_index + 1,
        .hour = day_secs.getHoursIntoDay(),
        .minute = day_secs.getMinutesIntoHour(),
        .second = day_secs.getSecondsIntoMinute(),
        .microsecond = 0,
    };
}

/// Get current UTC time
pub export fn datetime_utcnow() DateTime {
    return datetime_now(); // For now, same as now (TODO: proper UTC)
}

/// Create datetime from components
pub export fn datetime_new(year: i32, month: u8, day: u8, hour: u8, minute: u8, second: u8, microsecond: u32) DateTime {
    return DateTime{
        .year = year,
        .month = month,
        .day = day,
        .hour = hour,
        .minute = minute,
        .second = second,
        .microsecond = microsecond,
    };
}

/// Create datetime from Unix timestamp
pub export fn datetime_fromtimestamp(timestamp: i64) DateTime {
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(timestamp) };
    const day = epoch.getEpochDay();
    const year_day = day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_secs = epoch.getDaySeconds();

    return DateTime{
        .year = year_day.year,
        .month = month_day.month.numeric(),
        .day = month_day.day_index + 1,
        .hour = day_secs.getHoursIntoDay(),
        .minute = day_secs.getMinutesIntoHour(),
        .second = day_secs.getSecondsIntoMinute(),
        .microsecond = 0,
    };
}

/// Convert datetime to Unix timestamp
pub export fn datetime_timestamp(dt: DateTime) i64 {
    const ordinal = ymdToOrdinal(dt.year, dt.month, dt.day);
    // Days since Unix epoch (1970-01-01)
    const unix_epoch_ordinal = ymdToOrdinal(1970, 1, 1);
    const days_since_epoch = ordinal - unix_epoch_ordinal;

    return days_since_epoch * 86400 +
        @as(i64, dt.hour) * 3600 +
        @as(i64, dt.minute) * 60 +
        @as(i64, dt.second);
}

/// Get ordinal (days since year 1)
pub export fn datetime_toordinal(dt: DateTime) i64 {
    return ymdToOrdinal(dt.year, dt.month, dt.day);
}

/// Get weekday (0=Monday, 6=Sunday)
pub export fn datetime_weekday(dt: DateTime) u8 {
    const ordinal = ymdToOrdinal(dt.year, dt.month, dt.day);
    return @intCast(@mod(ordinal + 6, 7));
}

/// Get ISO weekday (1=Monday, 7=Sunday)
pub export fn datetime_isoweekday(dt: DateTime) u8 {
    return datetime_weekday(dt) + 1;
}

/// Format datetime as ISO string into buffer
/// Returns number of bytes written
pub export fn datetime_isoformat(dt: DateTime, buf: [*]u8, buf_len: usize, sep: u8) usize {
    if (buf_len < 26) return 0;

    // Format: YYYY-MM-DDTHH:MM:SS.ffffff
    var i: usize = 0;

    // Year
    i += formatInt(buf + i, @as(u32, @intCast(dt.year)), 4);
    buf[i] = '-';
    i += 1;

    // Month
    i += formatInt(buf + i, dt.month, 2);
    buf[i] = '-';
    i += 1;

    // Day
    i += formatInt(buf + i, dt.day, 2);
    buf[i] = sep;
    i += 1;

    // Hour
    i += formatInt(buf + i, dt.hour, 2);
    buf[i] = ':';
    i += 1;

    // Minute
    i += formatInt(buf + i, dt.minute, 2);
    buf[i] = ':';
    i += 1;

    // Second
    i += formatInt(buf + i, dt.second, 2);

    // Microseconds (only if non-zero)
    if (dt.microsecond > 0) {
        buf[i] = '.';
        i += 1;
        i += formatInt(buf + i, dt.microsecond, 6);
    }

    return i;
}

/// Format date as ISO string (YYYY-MM-DD)
pub export fn date_isoformat(dt: DateTime, buf: [*]u8, buf_len: usize) usize {
    if (buf_len < 10) return 0;

    var i: usize = 0;
    i += formatInt(buf + i, @as(u32, @intCast(dt.year)), 4);
    buf[i] = '-';
    i += 1;
    i += formatInt(buf + i, dt.month, 2);
    buf[i] = '-';
    i += 1;
    i += formatInt(buf + i, dt.day, 2);

    return i;
}

/// Format time as ISO string (HH:MM:SS)
pub export fn time_isoformat(dt: DateTime, buf: [*]u8, buf_len: usize) usize {
    if (buf_len < 8) return 0;

    var i: usize = 0;
    i += formatInt(buf + i, dt.hour, 2);
    buf[i] = ':';
    i += 1;
    i += formatInt(buf + i, dt.minute, 2);
    buf[i] = ':';
    i += 1;
    i += formatInt(buf + i, dt.second, 2);

    if (dt.microsecond > 0 and buf_len >= 15) {
        buf[i] = '.';
        i += 1;
        i += formatInt(buf + i, dt.microsecond, 6);
    }

    return i;
}

// ============================================================================
// DateTime Arithmetic
// ============================================================================

/// Add timedelta to datetime
pub export fn datetime_add(dt: DateTime, td: TimeDelta) DateTime {
    // Convert time to total microseconds
    var total_us: i64 = @as(i64, dt.microsecond) + @as(i64, td.microseconds) +
        (@as(i64, dt.second) + @as(i64, td.seconds)) * 1_000_000 +
        @as(i64, dt.minute) * 60_000_000 +
        @as(i64, dt.hour) * 3_600_000_000;

    var days = datetime_toordinal(dt) + @as(i64, td.days);

    // Normalize microseconds to days
    const us_per_day: i64 = 86_400_000_000;
    const extra_days = @divFloor(total_us, us_per_day);
    total_us = @mod(total_us, us_per_day);
    if (total_us < 0) {
        total_us += us_per_day;
    }
    days += extra_days;

    // Convert back to components
    const ymd = ordinalToYmd(days);
    const total_s = @divFloor(total_us, 1_000_000);
    const us: u32 = @intCast(@mod(total_us, 1_000_000));
    const total_m = @divFloor(total_s, 60);
    const s: u8 = @intCast(@mod(total_s, 60));
    const h = @divFloor(total_m, 60);
    const m: u8 = @intCast(@mod(total_m, 60));

    return DateTime{
        .year = ymd.year,
        .month = ymd.month,
        .day = ymd.day,
        .hour = @intCast(h),
        .minute = m,
        .second = s,
        .microsecond = us,
    };
}

/// Subtract two datetimes to get timedelta
pub export fn datetime_sub(dt1: DateTime, dt2: DateTime) TimeDelta {
    const days = datetime_toordinal(dt1) - datetime_toordinal(dt2);
    const seconds = (@as(i32, dt1.hour) - @as(i32, dt2.hour)) * 3600 +
        (@as(i32, dt1.minute) - @as(i32, dt2.minute)) * 60 +
        (@as(i32, dt1.second) - @as(i32, dt2.second));
    const microseconds = @as(i32, @intCast(dt1.microsecond)) - @as(i32, @intCast(dt2.microsecond));

    return timedelta_normalize(@intCast(days), seconds, microseconds);
}

// ============================================================================
// TimeDelta Functions
// ============================================================================

/// Create timedelta from components
pub export fn timedelta_new(days: i32, seconds: i32, microseconds: i32) TimeDelta {
    return timedelta_normalize(days, seconds, microseconds);
}

/// Normalize timedelta components
fn timedelta_normalize(days: i32, seconds: i32, microseconds: i32) TimeDelta {
    var d = days;
    var s = seconds;
    var us = microseconds;

    // Normalize microseconds
    const extra_s = @divFloor(us, 1_000_000);
    us = @mod(us, 1_000_000);
    if (us < 0) us += 1_000_000;
    s += extra_s;

    // Normalize seconds
    const extra_d = @divFloor(s, 86400);
    s = @mod(s, 86400);
    if (s < 0) s += 86400;
    d += extra_d;

    return TimeDelta{
        .days = d,
        .seconds = s,
        .microseconds = us,
    };
}

/// Get total seconds as float (returned as microseconds for precision)
pub export fn timedelta_total_microseconds(td: TimeDelta) i64 {
    return @as(i64, td.days) * 86_400_000_000 +
        @as(i64, td.seconds) * 1_000_000 +
        @as(i64, td.microseconds);
}

/// Add two timedeltas
pub export fn timedelta_add(td1: TimeDelta, td2: TimeDelta) TimeDelta {
    return timedelta_normalize(
        td1.days + td2.days,
        td1.seconds + td2.seconds,
        td1.microseconds + td2.microseconds,
    );
}

/// Negate timedelta
pub export fn timedelta_neg(td: TimeDelta) TimeDelta {
    return timedelta_normalize(-td.days, -td.seconds, -td.microseconds);
}

/// Multiply timedelta by integer
pub export fn timedelta_mul(td: TimeDelta, n: i32) TimeDelta {
    const total_us = timedelta_total_microseconds(td) * @as(i64, n);
    const days: i32 = @intCast(@divFloor(total_us, 86_400_000_000));
    const remainder = @mod(total_us, 86_400_000_000);
    const seconds: i32 = @intCast(@divFloor(remainder, 1_000_000));
    const microseconds: i32 = @intCast(@mod(remainder, 1_000_000));
    return TimeDelta{ .days = days, .seconds = seconds, .microseconds = microseconds };
}

// ============================================================================
// Validation
// ============================================================================

/// Check if date components are valid
pub export fn datetime_is_valid(year: i32, month: u8, day: u8, hour: u8, minute: u8, second: u8) bool {
    if (month < 1 or month > 12) return false;
    if (day < 1 or day > daysInMonth(year, month)) return false;
    if (hour > 23) return false;
    if (minute > 59) return false;
    if (second > 59) return false;
    return true;
}

/// Check if year is a leap year
pub export fn datetime_is_leap_year(year: i32) bool {
    return isLeapYear(year);
}

/// Get days in month
pub export fn datetime_days_in_month(year: i32, month: u8) u8 {
    return daysInMonth(year, month);
}

// ============================================================================
// Formatting Helpers
// ============================================================================

fn formatInt(buf: [*]u8, value: anytype, width: usize) usize {
    var v: u32 = @intCast(value);
    var i: usize = width;

    while (i > 0) {
        i -= 1;
        buf[i] = '0' + @as(u8, @intCast(v % 10));
        v /= 10;
    }

    return width;
}

// ============================================================================
// Tests
// ============================================================================

test "datetime ordinal roundtrip" {
    const dt = DateTime{
        .year = 2024,
        .month = 1,
        .day = 15,
        .hour = 14,
        .minute = 30,
        .second = 45,
        .microsecond = 0,
    };

    const ordinal = datetime_toordinal(dt);
    const ymd = ordinalToYmd(ordinal);

    try std.testing.expectEqual(@as(i32, 2024), ymd.year);
    try std.testing.expectEqual(@as(u8, 1), ymd.month);
    try std.testing.expectEqual(@as(u8, 15), ymd.day);
}

test "datetime add timedelta" {
    const dt = DateTime{
        .year = 2024,
        .month = 1,
        .day = 15,
        .hour = 14,
        .minute = 30,
        .second = 45,
        .microsecond = 0,
    };

    const td = TimeDelta{ .days = 1, .seconds = 0, .microseconds = 0 };
    const result = datetime_add(dt, td);

    try std.testing.expectEqual(@as(u8, 16), result.day);
    try std.testing.expectEqual(@as(u8, 1), result.month);
    try std.testing.expectEqual(@as(i32, 2024), result.year);
}

test "timedelta normalization" {
    // 2 hours = 7200 seconds
    const td = timedelta_new(0, 7200, 0);
    try std.testing.expectEqual(@as(i32, 0), td.days);
    try std.testing.expectEqual(@as(i32, 7200), td.seconds);

    // 25 hours = 1 day + 1 hour
    const td2 = timedelta_new(0, 25 * 3600, 0);
    try std.testing.expectEqual(@as(i32, 1), td2.days);
    try std.testing.expectEqual(@as(i32, 3600), td2.seconds);
}

test "leap year" {
    try std.testing.expect(isLeapYear(2000));
    try std.testing.expect(isLeapYear(2024));
    try std.testing.expect(!isLeapYear(1900));
    try std.testing.expect(!isLeapYear(2023));
}
