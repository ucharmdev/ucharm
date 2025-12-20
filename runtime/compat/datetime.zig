const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_datetime: c.py_Type = 0;
var tp_date: c.py_Type = 0;
var tp_time: c.py_Type = 0;
var tp_timedelta: c.py_Type = 0;

// Helper to calculate days since Unix epoch (1970-01-01)
fn daysSinceEpoch(year: i64, month: i64, day: i64) i64 {
    var y = year;
    var m = month;
    if (m <= 2) {
        y -= 1;
        m += 12;
    }
    m -= 3;
    const era: i64 = @divFloor(y, 400);
    const yoe: i64 = @mod(y, 400);
    const doy: i64 = @divFloor(153 * m + 2, 5) + day - 1;
    const doe: i64 = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

// Convert days since epoch to year/month/day
fn epochDaysToYmd(days: i64) struct { year: i64, month: i64, day: i64 } {
    const z = days + 719468;
    const era: i64 = @divFloor(if (z >= 0) z else z - 146096, 146097);
    const doe: i64 = z - era * 146097;
    const yoe: i64 = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    const y: i64 = yoe + era * 400;
    const doy: i64 = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp: i64 = @divFloor(5 * doy + 2, 153);
    const d: i64 = doy - @divFloor(153 * mp + 2, 5) + 1;
    const m: i64 = if (mp < 10) mp + 3 else mp - 9;
    return .{
        .year = if (m <= 2) y + 1 else y,
        .month = m,
        .day = d,
    };
}

// Helper to get integer attribute or default
fn getIntAttr(obj: c.py_Ref, name: [:0]const u8, default: i64) i64 {
    const val = c.py_getdict(obj, c.py_name(name));
    if (val == null) return default;
    return c.py_toint(val.?);
}

// Helper to set integer attribute
fn setIntAttr(obj: c.py_Ref, name: [:0]const u8, val: i64) void {
    c.py_newint(c.py_r0(), val);
    c.py_setdict(obj, c.py_name(name), c.py_r0());
}

// Helper to create a new string from buffer
fn newStrFromSlice(slice: []const u8) void {
    _ = c.py_newstrn(c.py_retval(), @intCast(slice.len));
    const out = @as([*]u8, @ptrCast(@constCast(c.py_tostr(c.py_retval()))));
    @memcpy(out[0..slice.len], slice);
}

// ============== datetime class ==============

fn datetimeNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 4 or argc > 8) {
        return c.py_exception(c.tp_TypeError, "datetime() requires 3-7 arguments");
    }
    _ = pk.argRef(argv, 0); // cls
    _ = c.py_newobject(c.py_retval(), tp_datetime, -1, 0);
    return true;
}

fn datetimeInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 4) {
        return c.py_exception(c.tp_TypeError, "datetime() requires at least year, month, day");
    }
    const self = pk.argRef(argv, 0);

    setIntAttr(self, "year", c.py_toint(pk.argRef(argv, 1)));
    setIntAttr(self, "month", c.py_toint(pk.argRef(argv, 2)));
    setIntAttr(self, "day", c.py_toint(pk.argRef(argv, 3)));
    setIntAttr(self, "hour", if (argc > 4) c.py_toint(pk.argRef(argv, 4)) else 0);
    setIntAttr(self, "minute", if (argc > 5) c.py_toint(pk.argRef(argv, 5)) else 0);
    setIntAttr(self, "second", if (argc > 6) c.py_toint(pk.argRef(argv, 6)) else 0);
    setIntAttr(self, "microsecond", if (argc > 7) c.py_toint(pk.argRef(argv, 7)) else 0);

    c.py_newnone(c.py_retval());
    return true;
}

fn datetimeNow(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argv;
    if (argc > 1) {
        return c.py_exception(c.tp_TypeError, "now() takes at most 1 argument");
    }

    const ts = std.time.timestamp();
    const days = @divFloor(ts, 86400);
    const day_secs = @mod(ts, 86400);

    const ymd = epochDaysToYmd(days);

    _ = c.py_newobject(c.py_retval(), tp_datetime, -1, 0);

    setIntAttr(c.py_retval(), "year", ymd.year);
    setIntAttr(c.py_retval(), "month", ymd.month);
    setIntAttr(c.py_retval(), "day", ymd.day);
    setIntAttr(c.py_retval(), "hour", @divFloor(day_secs, 3600));
    setIntAttr(c.py_retval(), "minute", @divFloor(@mod(day_secs, 3600), 60));
    setIntAttr(c.py_retval(), "second", @mod(day_secs, 60));
    setIntAttr(c.py_retval(), "microsecond", 0);

    return true;
}

fn datetimeUtcnow(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    return datetimeNow(argc, argv);
}

fn datetimeDate(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "date() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    _ = c.py_newobject(c.py_retval(), tp_date, -1, 0);
    setIntAttr(c.py_retval(), "year", getIntAttr(self, "year", 1));
    setIntAttr(c.py_retval(), "month", getIntAttr(self, "month", 1));
    setIntAttr(c.py_retval(), "day", getIntAttr(self, "day", 1));

    return true;
}

fn datetimeTime(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "time() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    _ = c.py_newobject(c.py_retval(), tp_time, -1, 0);
    setIntAttr(c.py_retval(), "hour", getIntAttr(self, "hour", 0));
    setIntAttr(c.py_retval(), "minute", getIntAttr(self, "minute", 0));
    setIntAttr(c.py_retval(), "second", getIntAttr(self, "second", 0));
    setIntAttr(c.py_retval(), "microsecond", getIntAttr(self, "microsecond", 0));

    return true;
}

fn datetimeTimestamp(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "timestamp() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    const year = getIntAttr(self, "year", 1970);
    const month = getIntAttr(self, "month", 1);
    const day = getIntAttr(self, "day", 1);
    const hour = getIntAttr(self, "hour", 0);
    const minute = getIntAttr(self, "minute", 0);
    const second = getIntAttr(self, "second", 0);

    const days = daysSinceEpoch(year, month, day);
    const secs: i64 = days * 86400 + hour * 3600 + minute * 60 + second;

    c.py_newfloat(c.py_retval(), @floatFromInt(secs));
    return true;
}

fn datetimeIsoformat(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1 or argc > 2) {
        return c.py_exception(c.tp_TypeError, "isoformat() takes at most 1 argument");
    }
    const self = pk.argRef(argv, 0);

    const year: u32 = @intCast(getIntAttr(self, "year", 1));
    const month: u32 = @intCast(getIntAttr(self, "month", 1));
    const day: u32 = @intCast(getIntAttr(self, "day", 1));
    const hour: u32 = @intCast(getIntAttr(self, "hour", 0));
    const minute: u32 = @intCast(getIntAttr(self, "minute", 0));
    const second: u32 = @intCast(getIntAttr(self, "second", 0));

    var buf: [32]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}", .{
        year, month, day, hour, minute, second,
    }) catch {
        return c.py_exception(c.tp_RuntimeError, "format error");
    };

    newStrFromSlice(len);
    return true;
}

fn datetimeStrftime(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "strftime() requires 1 argument");
    }
    const self = pk.argRef(argv, 0);
    if (!c.py_checkstr(pk.argRef(argv, 1))) return false;

    const year: u32 = @intCast(getIntAttr(self, "year", 1));
    const month: u32 = @intCast(getIntAttr(self, "month", 1));
    const day: u32 = @intCast(getIntAttr(self, "day", 1));

    var buf: [32]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{ year, month, day }) catch {
        return c.py_exception(c.tp_RuntimeError, "format error");
    };

    newStrFromSlice(len);
    return true;
}

fn datetimeRepr(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "__repr__() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    const year: u32 = @intCast(getIntAttr(self, "year", 1));
    const month: u32 = @intCast(getIntAttr(self, "month", 1));
    const day: u32 = @intCast(getIntAttr(self, "day", 1));
    const hour: u32 = @intCast(getIntAttr(self, "hour", 0));
    const minute: u32 = @intCast(getIntAttr(self, "minute", 0));
    const second: u32 = @intCast(getIntAttr(self, "second", 0));

    var buf: [64]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "datetime.datetime({d}, {d}, {d}, {d}, {d}, {d})", .{
        year, month, day, hour, minute, second,
    }) catch {
        return c.py_exception(c.tp_RuntimeError, "format error");
    };

    newStrFromSlice(len);
    return true;
}

// ============== date class ==============

fn dateNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 4) {
        return c.py_exception(c.tp_TypeError, "date() requires year, month, day");
    }
    _ = pk.argRef(argv, 0); // cls
    _ = c.py_newobject(c.py_retval(), tp_date, -1, 0);
    return true;
}

fn dateInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 4) {
        return c.py_exception(c.tp_TypeError, "date() requires year, month, day");
    }
    const self = pk.argRef(argv, 0);

    setIntAttr(self, "year", c.py_toint(pk.argRef(argv, 1)));
    setIntAttr(self, "month", c.py_toint(pk.argRef(argv, 2)));
    setIntAttr(self, "day", c.py_toint(pk.argRef(argv, 3)));

    c.py_newnone(c.py_retval());
    return true;
}

fn dateToday(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argv;
    if (argc > 1) {
        return c.py_exception(c.tp_TypeError, "today() takes no arguments");
    }

    const ts = std.time.timestamp();
    const days = @divFloor(ts, 86400);
    const ymd = epochDaysToYmd(days);

    _ = c.py_newobject(c.py_retval(), tp_date, -1, 0);
    setIntAttr(c.py_retval(), "year", ymd.year);
    setIntAttr(c.py_retval(), "month", ymd.month);
    setIntAttr(c.py_retval(), "day", ymd.day);

    return true;
}

fn dateIsoformat(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "isoformat() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    const year: u32 = @intCast(getIntAttr(self, "year", 1));
    const month: u32 = @intCast(getIntAttr(self, "month", 1));
    const day: u32 = @intCast(getIntAttr(self, "day", 1));

    var buf: [16]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{ year, month, day }) catch {
        return c.py_exception(c.tp_RuntimeError, "format error");
    };

    newStrFromSlice(len);
    return true;
}

fn dateWeekday(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "weekday() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    const year = getIntAttr(self, "year", 1);
    const month = getIntAttr(self, "month", 1);
    const day = getIntAttr(self, "day", 1);

    // Calculate days since epoch, then mod 7
    // 1970-01-01 was a Thursday (weekday 3)
    const days = daysSinceEpoch(year, month, day);
    // Python weekday: Monday=0, Sunday=6
    // Days since epoch: Thursday=0 -> we need to adjust
    // Thursday is day 3 in Python's weekday
    var weekday = @mod(days + 3, 7);
    if (weekday < 0) weekday += 7;

    c.py_newint(c.py_retval(), weekday);
    return true;
}

fn dateRepr(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "__repr__() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    const year: u32 = @intCast(getIntAttr(self, "year", 1));
    const month: u32 = @intCast(getIntAttr(self, "month", 1));
    const day: u32 = @intCast(getIntAttr(self, "day", 1));

    var buf: [32]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "datetime.date({d}, {d}, {d})", .{ year, month, day }) catch {
        return c.py_exception(c.tp_RuntimeError, "format error");
    };

    newStrFromSlice(len);
    return true;
}

// ============== time class ==============

fn timeNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argv;
    if (argc < 1 or argc > 5) {
        return c.py_exception(c.tp_TypeError, "time() takes 0-4 arguments");
    }
    _ = c.py_newobject(c.py_retval(), tp_time, -1, 0);
    return true;
}

fn timeInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    setIntAttr(self, "hour", if (argc > 1) c.py_toint(pk.argRef(argv, 1)) else 0);
    setIntAttr(self, "minute", if (argc > 2) c.py_toint(pk.argRef(argv, 2)) else 0);
    setIntAttr(self, "second", if (argc > 3) c.py_toint(pk.argRef(argv, 3)) else 0);
    setIntAttr(self, "microsecond", if (argc > 4) c.py_toint(pk.argRef(argv, 4)) else 0);

    c.py_newnone(c.py_retval());
    return true;
}

fn timeIsoformat(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "isoformat() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    const hour: u32 = @intCast(getIntAttr(self, "hour", 0));
    const minute: u32 = @intCast(getIntAttr(self, "minute", 0));
    const second: u32 = @intCast(getIntAttr(self, "second", 0));

    var buf: [16]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hour, minute, second }) catch {
        return c.py_exception(c.tp_RuntimeError, "format error");
    };

    newStrFromSlice(len);
    return true;
}

fn timeRepr(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "__repr__() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    const hour: u32 = @intCast(getIntAttr(self, "hour", 0));
    const minute: u32 = @intCast(getIntAttr(self, "minute", 0));
    const second: u32 = @intCast(getIntAttr(self, "second", 0));

    var buf: [32]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "datetime.time({d}, {d}, {d})", .{ hour, minute, second }) catch {
        return c.py_exception(c.tp_RuntimeError, "format error");
    };

    newStrFromSlice(len);
    return true;
}

// ============== timedelta class ==============

fn timedeltaNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argv;
    if (argc < 1 or argc > 8) {
        return c.py_exception(c.tp_TypeError, "timedelta() takes 0-7 arguments");
    }
    _ = c.py_newobject(c.py_retval(), tp_timedelta, -1, 0);
    return true;
}

fn timedeltaInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    // timedelta(days=0, seconds=0, microseconds=0, milliseconds=0, minutes=0, hours=0, weeks=0)
    var days: i64 = if (argc > 1) c.py_toint(pk.argRef(argv, 1)) else 0;
    var seconds: i64 = if (argc > 2) c.py_toint(pk.argRef(argv, 2)) else 0;
    var microseconds: i64 = if (argc > 3) c.py_toint(pk.argRef(argv, 3)) else 0;
    const milliseconds: i64 = if (argc > 4) c.py_toint(pk.argRef(argv, 4)) else 0;
    const minutes: i64 = if (argc > 5) c.py_toint(pk.argRef(argv, 5)) else 0;
    const hours: i64 = if (argc > 6) c.py_toint(pk.argRef(argv, 6)) else 0;
    const weeks: i64 = if (argc > 7) c.py_toint(pk.argRef(argv, 7)) else 0;

    // Normalize
    days += weeks * 7;
    seconds += hours * 3600 + minutes * 60;
    microseconds += milliseconds * 1000;

    // Carry microseconds to seconds
    seconds += @divFloor(microseconds, 1_000_000);
    microseconds = @mod(microseconds, 1_000_000);

    // Carry seconds to days
    days += @divFloor(seconds, 86400);
    seconds = @mod(seconds, 86400);

    setIntAttr(self, "days", days);
    setIntAttr(self, "seconds", seconds);
    setIntAttr(self, "microseconds", microseconds);

    c.py_newnone(c.py_retval());
    return true;
}

fn timedeltaTotalSeconds(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "total_seconds() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    const days = getIntAttr(self, "days", 0);
    const seconds = getIntAttr(self, "seconds", 0);
    const microseconds = getIntAttr(self, "microseconds", 0);

    const total: f64 = @as(f64, @floatFromInt(days)) * 86400.0 +
        @as(f64, @floatFromInt(seconds)) +
        @as(f64, @floatFromInt(microseconds)) / 1_000_000.0;

    c.py_newfloat(c.py_retval(), total);
    return true;
}

fn timedeltaRepr(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "__repr__() takes no arguments");
    }
    const self = pk.argRef(argv, 0);

    const days = getIntAttr(self, "days", 0);
    const seconds = getIntAttr(self, "seconds", 0);

    var buf: [64]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "datetime.timedelta(days={d}, seconds={d})", .{ days, seconds }) catch {
        return c.py_exception(c.tp_RuntimeError, "format error");
    };

    newStrFromSlice(len);
    return true;
}

pub fn register() void {
    const name: [:0]const u8 = "datetime";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);

    // datetime class
    tp_datetime = c.py_newtype("datetime", c.tp_object, module, null);
    c.py_bind(c.py_tpobject(tp_datetime), "__new__(cls, year, month, day, hour=0, minute=0, second=0, microsecond=0)", datetimeNew);
    c.py_bind(c.py_tpobject(tp_datetime), "__init__(self, year, month, day, hour=0, minute=0, second=0, microsecond=0)", datetimeInit);
    c.py_bind(c.py_tpobject(tp_datetime), "now(tz=None)", datetimeNow);
    c.py_bind(c.py_tpobject(tp_datetime), "utcnow()", datetimeUtcnow);
    c.py_bindmethod(tp_datetime, "date", datetimeDate);
    c.py_bindmethod(tp_datetime, "time", datetimeTime);
    c.py_bindmethod(tp_datetime, "timestamp", datetimeTimestamp);
    c.py_bindmethod(tp_datetime, "isoformat", datetimeIsoformat);
    c.py_bindmethod(tp_datetime, "strftime", datetimeStrftime);
    c.py_bindmethod(tp_datetime, "__repr__", datetimeRepr);
    c.py_setdict(module, c.py_name("datetime"), c.py_tpobject(tp_datetime));

    // date class
    tp_date = c.py_newtype("date", c.tp_object, module, null);
    c.py_bind(c.py_tpobject(tp_date), "__new__(cls, year, month, day)", dateNew);
    c.py_bind(c.py_tpobject(tp_date), "__init__(self, year, month, day)", dateInit);
    c.py_bind(c.py_tpobject(tp_date), "today()", dateToday);
    c.py_bindmethod(tp_date, "isoformat", dateIsoformat);
    c.py_bindmethod(tp_date, "weekday", dateWeekday);
    c.py_bindmethod(tp_date, "__repr__", dateRepr);
    c.py_setdict(module, c.py_name("date"), c.py_tpobject(tp_date));

    // time class
    tp_time = c.py_newtype("time", c.tp_object, module, null);
    c.py_bind(c.py_tpobject(tp_time), "__new__(cls, hour=0, minute=0, second=0, microsecond=0)", timeNew);
    c.py_bind(c.py_tpobject(tp_time), "__init__(self, hour=0, minute=0, second=0, microsecond=0)", timeInit);
    c.py_bindmethod(tp_time, "isoformat", timeIsoformat);
    c.py_bindmethod(tp_time, "__repr__", timeRepr);
    c.py_setdict(module, c.py_name("time"), c.py_tpobject(tp_time));

    // timedelta class
    tp_timedelta = c.py_newtype("timedelta", c.tp_object, module, null);
    c.py_bind(c.py_tpobject(tp_timedelta), "__new__(cls, days=0, seconds=0, microseconds=0, milliseconds=0, minutes=0, hours=0, weeks=0)", timedeltaNew);
    c.py_bind(c.py_tpobject(tp_timedelta), "__init__(self, days=0, seconds=0, microseconds=0, milliseconds=0, minutes=0, hours=0, weeks=0)", timedeltaInit);
    c.py_bindmethod(tp_timedelta, "total_seconds", timedeltaTotalSeconds);
    c.py_bindmethod(tp_timedelta, "__repr__", timedeltaRepr);
    c.py_setdict(module, c.py_name("timedelta"), c.py_tpobject(tp_timedelta));

    // Constants
    c.py_newint(c.py_r0(), 1);
    c.py_setdict(module, c.py_name("MINYEAR"), c.py_r0());
    c.py_newint(c.py_r0(), 9999);
    c.py_setdict(module, c.py_name("MAXYEAR"), c.py_r0());
}
