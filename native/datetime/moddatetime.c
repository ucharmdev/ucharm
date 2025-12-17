/*
 * moddatetime - Native datetime module for microcharm
 *
 * Provides fast date/time operations using Zig's standard library.
 *
 * Usage in Python:
 *   import datetime
 *   now = datetime.now()
 *   print(now.year, now.month, now.day)
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// ============================================================================
// Zig Function Declarations
// ============================================================================

typedef struct {
    int32_t year;
    uint8_t month;
    uint8_t day;
    uint8_t hour;
    uint8_t minute;
    uint8_t second;
    uint32_t microsecond;
} DateTime;

typedef struct {
    int32_t days;
    int32_t seconds;
    int32_t microseconds;
} TimeDelta;

ZIG_EXTERN DateTime datetime_now(void);
ZIG_EXTERN DateTime datetime_utcnow(void);
ZIG_EXTERN DateTime datetime_new(int32_t year, uint8_t month, uint8_t day,
                                  uint8_t hour, uint8_t minute, uint8_t second,
                                  uint32_t microsecond);
ZIG_EXTERN DateTime datetime_fromtimestamp(int64_t timestamp);
ZIG_EXTERN int64_t datetime_timestamp(DateTime dt);
ZIG_EXTERN int64_t datetime_toordinal(DateTime dt);
ZIG_EXTERN uint8_t datetime_weekday(DateTime dt);
ZIG_EXTERN uint8_t datetime_isoweekday(DateTime dt);
ZIG_EXTERN size_t datetime_isoformat(DateTime dt, char *buf, size_t buf_len, char sep);
ZIG_EXTERN size_t date_isoformat(DateTime dt, char *buf, size_t buf_len);
ZIG_EXTERN size_t time_isoformat(DateTime dt, char *buf, size_t buf_len);
ZIG_EXTERN DateTime datetime_add(DateTime dt, TimeDelta td);
ZIG_EXTERN TimeDelta datetime_sub(DateTime dt1, DateTime dt2);
ZIG_EXTERN TimeDelta timedelta_new(int32_t days, int32_t seconds, int32_t microseconds);
ZIG_EXTERN int64_t timedelta_total_microseconds(TimeDelta td);
ZIG_EXTERN TimeDelta timedelta_add(TimeDelta td1, TimeDelta td2);
ZIG_EXTERN TimeDelta timedelta_neg(TimeDelta td);
ZIG_EXTERN TimeDelta timedelta_mul(TimeDelta td, int32_t n);
ZIG_EXTERN bool datetime_is_valid(int32_t year, uint8_t month, uint8_t day,
                                   uint8_t hour, uint8_t minute, uint8_t second);
ZIG_EXTERN bool datetime_is_leap_year(int32_t year);
ZIG_EXTERN uint8_t datetime_days_in_month(int32_t year, uint8_t month);

// ============================================================================
// datetime.now() -> dict
// ============================================================================

MPY_FUNC_0(datetime, now) {
    DateTime dt = datetime_now();

    mp_obj_t dict = mpy_new_dict();
    mpy_dict_store_str(dict, "year", mpy_new_int(dt.year));
    mpy_dict_store_str(dict, "month", mpy_new_int(dt.month));
    mpy_dict_store_str(dict, "day", mpy_new_int(dt.day));
    mpy_dict_store_str(dict, "hour", mpy_new_int(dt.hour));
    mpy_dict_store_str(dict, "minute", mpy_new_int(dt.minute));
    mpy_dict_store_str(dict, "second", mpy_new_int(dt.second));
    mpy_dict_store_str(dict, "microsecond", mpy_new_int(dt.microsecond));

    return dict;
}
MPY_FUNC_OBJ_0(datetime, now);

// ============================================================================
// datetime.utcnow() -> dict
// ============================================================================

MPY_FUNC_0(datetime, utcnow) {
    DateTime dt = datetime_utcnow();

    mp_obj_t dict = mpy_new_dict();
    mpy_dict_store_str(dict, "year", mpy_new_int(dt.year));
    mpy_dict_store_str(dict, "month", mpy_new_int(dt.month));
    mpy_dict_store_str(dict, "day", mpy_new_int(dt.day));
    mpy_dict_store_str(dict, "hour", mpy_new_int(dt.hour));
    mpy_dict_store_str(dict, "minute", mpy_new_int(dt.minute));
    mpy_dict_store_str(dict, "second", mpy_new_int(dt.second));
    mpy_dict_store_str(dict, "microsecond", mpy_new_int(dt.microsecond));

    return dict;
}
MPY_FUNC_OBJ_0(datetime, utcnow);

// ============================================================================
// datetime.fromtimestamp(ts) -> dict
// ============================================================================

MPY_FUNC_1(datetime, fromtimestamp) {
    int64_t ts = mpy_int(arg0);
    DateTime dt = datetime_fromtimestamp(ts);

    mp_obj_t dict = mpy_new_dict();
    mpy_dict_store_str(dict, "year", mpy_new_int(dt.year));
    mpy_dict_store_str(dict, "month", mpy_new_int(dt.month));
    mpy_dict_store_str(dict, "day", mpy_new_int(dt.day));
    mpy_dict_store_str(dict, "hour", mpy_new_int(dt.hour));
    mpy_dict_store_str(dict, "minute", mpy_new_int(dt.minute));
    mpy_dict_store_str(dict, "second", mpy_new_int(dt.second));
    mpy_dict_store_str(dict, "microsecond", mpy_new_int(dt.microsecond));

    return dict;
}
MPY_FUNC_OBJ_1(datetime, fromtimestamp);

// ============================================================================
// datetime.timestamp(year, month, day, hour, minute, second) -> int
// ============================================================================

MPY_FUNC_VAR(datetime, timestamp, 3, 6) {
    DateTime dt;
    dt.year = mpy_int(args[0]);
    dt.month = mpy_int(args[1]);
    dt.day = mpy_int(args[2]);
    dt.hour = n_args > 3 ? mpy_int(args[3]) : 0;
    dt.minute = n_args > 4 ? mpy_int(args[4]) : 0;
    dt.second = n_args > 5 ? mpy_int(args[5]) : 0;
    dt.microsecond = 0;

    return mpy_new_int64(datetime_timestamp(dt));
}
MPY_FUNC_OBJ_VAR(datetime, timestamp, 3, 6);

// ============================================================================
// datetime.isoformat(year, month, day, hour, minute, second, microsecond) -> str
// ============================================================================

MPY_FUNC_VAR(datetime, isoformat, 3, 7) {
    DateTime dt;
    dt.year = mpy_int(args[0]);
    dt.month = mpy_int(args[1]);
    dt.day = mpy_int(args[2]);
    dt.hour = n_args > 3 ? mpy_int(args[3]) : 0;
    dt.minute = n_args > 4 ? mpy_int(args[4]) : 0;
    dt.second = n_args > 5 ? mpy_int(args[5]) : 0;
    dt.microsecond = n_args > 6 ? mpy_int(args[6]) : 0;

    char buf[32];
    size_t len = datetime_isoformat(dt, buf, sizeof(buf), 'T');

    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_VAR(datetime, isoformat, 3, 7);

// ============================================================================
// datetime.date_isoformat(year, month, day) -> str
// ============================================================================

MPY_FUNC_3(datetime, date_isoformat) {
    DateTime dt;
    dt.year = mpy_int(arg0);
    dt.month = mpy_int(arg1);
    dt.day = mpy_int(arg2);

    char buf[16];
    size_t len = date_isoformat(dt, buf, sizeof(buf));

    return mpy_new_str_len(buf, len);
}
MPY_FUNC_OBJ_3(datetime, date_isoformat);

// ============================================================================
// datetime.weekday(year, month, day) -> int (0=Monday)
// ============================================================================

MPY_FUNC_3(datetime, weekday) {
    DateTime dt;
    dt.year = mpy_int(arg0);
    dt.month = mpy_int(arg1);
    dt.day = mpy_int(arg2);

    return mpy_new_int(datetime_weekday(dt));
}
MPY_FUNC_OBJ_3(datetime, weekday);

// ============================================================================
// datetime.isoweekday(year, month, day) -> int (1=Monday)
// ============================================================================

MPY_FUNC_3(datetime, isoweekday) {
    DateTime dt;
    dt.year = mpy_int(arg0);
    dt.month = mpy_int(arg1);
    dt.day = mpy_int(arg2);

    return mpy_new_int(datetime_isoweekday(dt));
}
MPY_FUNC_OBJ_3(datetime, isoweekday);

// ============================================================================
// datetime.toordinal(year, month, day) -> int
// ============================================================================

MPY_FUNC_3(datetime, toordinal) {
    DateTime dt;
    dt.year = mpy_int(arg0);
    dt.month = mpy_int(arg1);
    dt.day = mpy_int(arg2);

    return mpy_new_int64(datetime_toordinal(dt));
}
MPY_FUNC_OBJ_3(datetime, toordinal);

// ============================================================================
// datetime.is_valid(year, month, day, hour=0, minute=0, second=0) -> bool
// ============================================================================

MPY_FUNC_VAR(datetime, is_valid, 3, 6) {
    int32_t year = mpy_int(args[0]);
    uint8_t month = mpy_int(args[1]);
    uint8_t day = mpy_int(args[2]);
    uint8_t hour = n_args > 3 ? mpy_int(args[3]) : 0;
    uint8_t minute = n_args > 4 ? mpy_int(args[4]) : 0;
    uint8_t second = n_args > 5 ? mpy_int(args[5]) : 0;

    return mpy_bool(datetime_is_valid(year, month, day, hour, minute, second));
}
MPY_FUNC_OBJ_VAR(datetime, is_valid, 3, 6);

// ============================================================================
// datetime.is_leap_year(year) -> bool
// ============================================================================

MPY_FUNC_1(datetime, is_leap_year) {
    return mpy_bool(datetime_is_leap_year(mpy_int(arg0)));
}
MPY_FUNC_OBJ_1(datetime, is_leap_year);

// ============================================================================
// datetime.days_in_month(year, month) -> int
// ============================================================================

MPY_FUNC_2(datetime, days_in_month) {
    return mpy_new_int(datetime_days_in_month(mpy_int(arg0), mpy_int(arg1)));
}
MPY_FUNC_OBJ_2(datetime, days_in_month);

// ============================================================================
// datetime.add_days(year, month, day, days) -> (year, month, day)
// ============================================================================

MPY_FUNC_VAR(datetime, add_days, 4, 4) {
    DateTime dt;
    dt.year = mpy_int(args[0]);
    dt.month = mpy_int(args[1]);
    dt.day = mpy_int(args[2]);
    dt.hour = 0;
    dt.minute = 0;
    dt.second = 0;
    dt.microsecond = 0;

    TimeDelta td = { .days = mpy_int(args[3]), .seconds = 0, .microseconds = 0 };
    DateTime result = datetime_add(dt, td);

    return mpy_tuple3(
        mpy_new_int(result.year),
        mpy_new_int(result.month),
        mpy_new_int(result.day)
    );
}
MPY_FUNC_OBJ_VAR(datetime, add_days, 4, 4);

// ============================================================================
// datetime.timedelta(days=0, seconds=0, microseconds=0) -> dict
// ============================================================================

MPY_FUNC_VAR(datetime, timedelta, 0, 3) {
    int32_t days = n_args > 0 ? mpy_int(args[0]) : 0;
    int32_t seconds = n_args > 1 ? mpy_int(args[1]) : 0;
    int32_t microseconds = n_args > 2 ? mpy_int(args[2]) : 0;

    TimeDelta td = timedelta_new(days, seconds, microseconds);

    mp_obj_t dict = mpy_new_dict();
    mpy_dict_store_str(dict, "days", mpy_new_int(td.days));
    mpy_dict_store_str(dict, "seconds", mpy_new_int(td.seconds));
    mpy_dict_store_str(dict, "microseconds", mpy_new_int(td.microseconds));

    return dict;
}
MPY_FUNC_OBJ_VAR(datetime, timedelta, 0, 3);

// ============================================================================
// datetime.timedelta_total_seconds(days, seconds, microseconds) -> float
// ============================================================================

MPY_FUNC_3(datetime, timedelta_total_seconds) {
    TimeDelta td;
    td.days = mpy_int(arg0);
    td.seconds = mpy_int(arg1);
    td.microseconds = mpy_int(arg2);

    int64_t total_us = timedelta_total_microseconds(td);
    return mpy_new_float((double)total_us / 1000000.0);
}
MPY_FUNC_OBJ_3(datetime, timedelta_total_seconds);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(datetime)
    MPY_MODULE_FUNC(datetime, now)
    MPY_MODULE_FUNC(datetime, utcnow)
    MPY_MODULE_FUNC(datetime, fromtimestamp)
    MPY_MODULE_FUNC(datetime, timestamp)
    MPY_MODULE_FUNC(datetime, isoformat)
    MPY_MODULE_FUNC(datetime, date_isoformat)
    MPY_MODULE_FUNC(datetime, weekday)
    MPY_MODULE_FUNC(datetime, isoweekday)
    MPY_MODULE_FUNC(datetime, toordinal)
    MPY_MODULE_FUNC(datetime, is_valid)
    MPY_MODULE_FUNC(datetime, is_leap_year)
    MPY_MODULE_FUNC(datetime, days_in_month)
    MPY_MODULE_FUNC(datetime, add_days)
    MPY_MODULE_FUNC(datetime, timedelta)
    MPY_MODULE_FUNC(datetime, timedelta_total_seconds)
MPY_MODULE_END(datetime)
