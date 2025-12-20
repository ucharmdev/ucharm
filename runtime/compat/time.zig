const std = @import("std");
const pk = @import("pk");
const c = pk.c;
const builtin = @import("builtin");

// C time types - use isize which matches time_t on most platforms
const time_t = isize;
const struct_tm = extern struct {
    tm_sec: c_int,
    tm_min: c_int,
    tm_hour: c_int,
    tm_mday: c_int,
    tm_mon: c_int,
    tm_year: c_int,
    tm_wday: c_int,
    tm_yday: c_int,
    tm_isdst: c_int,
    // Platform-specific fields for macOS/Linux
    tm_gmtoff: c_long = 0,
    tm_zone: ?[*:0]const u8 = null,
};

extern "c" fn time(tloc: ?*time_t) time_t;
extern "c" fn localtime(timer: *const time_t) ?*struct_tm;
extern "c" fn gmtime(timer: *const time_t) ?*struct_tm;
extern "c" fn mktime(tm: *struct_tm) time_t;

fn monotonicFn(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    const ts = std.time.Instant.now() catch {
        return c.py_exception(c.tp_RuntimeError, "failed to get monotonic time");
    };
    // Access the timespec struct fields
    const secs: f64 = @floatFromInt(ts.timestamp.sec);
    const nsecs: f64 = @floatFromInt(ts.timestamp.nsec);
    c.py_newfloat(c.py_retval(), secs + nsecs / 1_000_000_000.0);
    return true;
}

fn createStructTime(tm_ptr: *struct_tm) bool {
    const tp = c.py_gettype("time", c.py_name("struct_time"));
    if (tp == 0) {
        return c.py_exception(c.tp_RuntimeError, "struct_time type not found");
    }
    const ud: *struct_tm = @ptrCast(@alignCast(c.py_newobject(c.py_retval(), tp, 0, @sizeOf(struct_tm))));
    ud.* = tm_ptr.*;
    return true;
}

fn localtimeFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    var t: time_t = undefined;

    if (argc == 0) {
        t = time(null);
    } else if (argc == 1) {
        var secs: c.py_f64 = 0;
        if (!c.py_castfloat(pk.argRef(argv, 0), &secs)) return false;
        t = @intFromFloat(secs);
    } else {
        return c.py_exception(c.tp_TypeError, "localtime() takes at most 1 argument");
    }

    const tm_ptr = localtime(&t) orelse {
        return c.py_exception(c.tp_ValueError, "invalid time");
    };
    return createStructTime(tm_ptr);
}

fn gmtimeFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    var t: time_t = undefined;

    if (argc == 0) {
        t = time(null);
    } else if (argc == 1) {
        var secs: c.py_f64 = 0;
        if (!c.py_castfloat(pk.argRef(argv, 0), &secs)) return false;
        t = @intFromFloat(secs);
    } else {
        return c.py_exception(c.tp_TypeError, "gmtime() takes at most 1 argument");
    }

    const tm_ptr = gmtime(&t) orelse {
        return c.py_exception(c.tp_ValueError, "invalid time");
    };
    return createStructTime(tm_ptr);
}

fn mktimeFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const arg = pk.argRef(argv, 0);

    var tm_copy: struct_tm = undefined;

    // Check if it's a tuple (9 elements) or struct_time
    if (c.py_istuple(arg)) {
        const len = c.py_tuple_len(arg);
        if (len < 9) {
            return c.py_exception(c.tp_TypeError, "mktime requires a 9-element tuple");
        }
        // Extract elements from tuple
        tm_copy.tm_year = @intCast(c.py_toint(c.py_tuple_getitem(arg, 0)) - 1900);
        tm_copy.tm_mon = @intCast(c.py_toint(c.py_tuple_getitem(arg, 1)) - 1);
        tm_copy.tm_mday = @intCast(c.py_toint(c.py_tuple_getitem(arg, 2)));
        tm_copy.tm_hour = @intCast(c.py_toint(c.py_tuple_getitem(arg, 3)));
        tm_copy.tm_min = @intCast(c.py_toint(c.py_tuple_getitem(arg, 4)));
        tm_copy.tm_sec = @intCast(c.py_toint(c.py_tuple_getitem(arg, 5)));
        tm_copy.tm_wday = @intCast(c.py_toint(c.py_tuple_getitem(arg, 6)));
        tm_copy.tm_yday = @intCast(c.py_toint(c.py_tuple_getitem(arg, 7)));
        tm_copy.tm_isdst = @intCast(c.py_toint(c.py_tuple_getitem(arg, 8)));
        tm_copy.tm_gmtoff = 0;
        tm_copy.tm_zone = null;
    } else {
        // Assume struct_time with userdata
        const tm_ptr: *struct_tm = @ptrCast(@alignCast(c.py_touserdata(arg)));
        tm_copy = tm_ptr.*;
    }

    const result = mktime(&tm_copy);
    if (result == -1) {
        return c.py_exception(c.tp_ValueError, "mktime argument out of range");
    }

    c.py_newfloat(c.py_retval(), @floatFromInt(result));
    return true;
}

// C strftime function
extern "c" fn strftime(s: [*]u8, max: usize, format: [*:0]const u8, tm: *const struct_tm) usize;

fn strftimeFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "strftime() requires format and time tuple");
    }

    const format_arg = pk.argRef(argv, 0);
    const time_arg = pk.argRef(argv, 1);

    // Get format string
    if (!c.py_isstr(format_arg)) {
        return c.py_exception(c.tp_TypeError, "strftime() format must be a string");
    }
    const format_ptr = c.py_tostr(format_arg);
    const format_len = std.mem.len(format_ptr);

    // Build struct_tm from tuple or struct_time
    var tm_val: struct_tm = undefined;
    if (c.py_istuple(time_arg)) {
        const len = c.py_tuple_len(time_arg);
        if (len < 9) {
            return c.py_exception(c.tp_TypeError, "strftime requires a 9-element tuple");
        }
        tm_val.tm_year = @intCast(c.py_toint(c.py_tuple_getitem(time_arg, 0)) - 1900);
        tm_val.tm_mon = @intCast(c.py_toint(c.py_tuple_getitem(time_arg, 1)) - 1);
        tm_val.tm_mday = @intCast(c.py_toint(c.py_tuple_getitem(time_arg, 2)));
        tm_val.tm_hour = @intCast(c.py_toint(c.py_tuple_getitem(time_arg, 3)));
        tm_val.tm_min = @intCast(c.py_toint(c.py_tuple_getitem(time_arg, 4)));
        tm_val.tm_sec = @intCast(c.py_toint(c.py_tuple_getitem(time_arg, 5)));
        tm_val.tm_wday = @intCast(c.py_toint(c.py_tuple_getitem(time_arg, 6)));
        tm_val.tm_yday = @intCast(c.py_toint(c.py_tuple_getitem(time_arg, 7)));
        tm_val.tm_isdst = @intCast(c.py_toint(c.py_tuple_getitem(time_arg, 8)));
        tm_val.tm_gmtoff = 0;
        tm_val.tm_zone = null;
    } else {
        const tm_ptr: *struct_tm = @ptrCast(@alignCast(c.py_touserdata(time_arg)));
        tm_val = tm_ptr.*;
    }

    // Format the time
    var buffer: [256]u8 = undefined;

    // We need null-terminated format string
    var format_buf: [128]u8 = undefined;
    if (format_len >= format_buf.len) {
        return c.py_exception(c.tp_ValueError, "format string too long");
    }
    @memcpy(format_buf[0..format_len], format_ptr[0..format_len]);
    format_buf[format_len] = 0;

    const result_len = strftime(&buffer, buffer.len, @ptrCast(&format_buf), &tm_val);
    if (result_len == 0) {
        // Could be empty result or error; return empty string
        c.py_newstr(c.py_retval(), "");
        return true;
    }

    const out = c.py_newstrn(c.py_retval(), @intCast(result_len));
    @memcpy(out[0..result_len], buffer[0..result_len]);
    return true;
}

// C strptime function
extern "c" fn strptime(s: [*:0]const u8, format: [*:0]const u8, tm: *struct_tm) ?[*]const u8;

fn strptimeFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "strptime() requires string and format");
    }

    const string_arg = pk.argRef(argv, 0);
    const format_arg = pk.argRef(argv, 1);

    // Get string
    if (!c.py_isstr(string_arg)) {
        return c.py_exception(c.tp_TypeError, "strptime() string must be a string");
    }
    const string_ptr = c.py_tostr(string_arg);
    const string_len = std.mem.len(string_ptr);

    // Get format string
    if (!c.py_isstr(format_arg)) {
        return c.py_exception(c.tp_TypeError, "strptime() format must be a string");
    }
    const format_ptr = c.py_tostr(format_arg);
    const format_len = std.mem.len(format_ptr);

    // Create null-terminated buffers
    var string_buf: [256]u8 = undefined;
    var format_buf: [128]u8 = undefined;

    if (string_len >= string_buf.len or format_len >= format_buf.len) {
        return c.py_exception(c.tp_ValueError, "string or format too long");
    }

    @memcpy(string_buf[0..string_len], string_ptr[0..string_len]);
    string_buf[string_len] = 0;
    @memcpy(format_buf[0..format_len], format_ptr[0..format_len]);
    format_buf[format_len] = 0;

    // Parse the time
    var tm_val: struct_tm = std.mem.zeroes(struct_tm);

    const result = strptime(@ptrCast(&string_buf), @ptrCast(&format_buf), &tm_val);
    if (result == null) {
        return c.py_exception(c.tp_ValueError, "time data does not match format");
    }

    // Return struct_time
    return createStructTime(&tm_val);
}

pub fn register() void {
    const module = c.py_getmodule("time") orelse return;

    c.py_bind(module, "monotonic()", monotonicFn);
    c.py_bindfunc(module, "localtime", localtimeFn);
    c.py_bindfunc(module, "gmtime", gmtimeFn);
    c.py_bind(module, "mktime(t)", mktimeFn);
    c.py_bindfunc(module, "strftime", strftimeFn);
    c.py_bindfunc(module, "strptime", strptimeFn);
}
