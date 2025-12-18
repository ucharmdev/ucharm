/*
 * modtime.c - Extension to MicroPython's time module
 *
 * Adds missing CPython-compatible functions:
 *   - time.strftime(format, time_tuple) -> formatted string
 *   - time.strptime(string, format) -> time tuple (basic)
 *   - time.monotonic() -> monotonic time
 *   - time.perf_counter() -> performance counter
 */

#include "py/runtime.h"
#include "py/objstr.h"
#include <time.h>
#include <sys/time.h>

#if defined(__APPLE__)
#include <mach/mach_time.h>
#endif

// time.strftime(format, time_tuple) -> string
static mp_obj_t time_ext_strftime(mp_obj_t format_in, mp_obj_t time_tuple_in) {
    const char *format = mp_obj_str_get_str(format_in);
    
    // Get time tuple elements
    size_t len;
    mp_obj_t *items;
    mp_obj_get_array(time_tuple_in, &len, &items);
    
    if (len < 9) {
        mp_raise_TypeError(MP_ERROR_TEXT("time tuple must have 9 elements"));
    }
    
    struct tm tm_info;
    tm_info.tm_year = mp_obj_get_int(items[0]) - 1900;
    tm_info.tm_mon = mp_obj_get_int(items[1]) - 1;
    tm_info.tm_mday = mp_obj_get_int(items[2]);
    tm_info.tm_hour = mp_obj_get_int(items[3]);
    tm_info.tm_min = mp_obj_get_int(items[4]);
    tm_info.tm_sec = mp_obj_get_int(items[5]);
    tm_info.tm_wday = mp_obj_get_int(items[6]);
    tm_info.tm_yday = mp_obj_get_int(items[7]) - 1;
    tm_info.tm_isdst = mp_obj_get_int(items[8]);
    
    char buffer[256];
    size_t result_len = strftime(buffer, sizeof(buffer), format, &tm_info);
    
    if (result_len == 0 && format[0] != '\0') {
        // strftime failed or buffer too small
        mp_raise_ValueError(MP_ERROR_TEXT("strftime format too long"));
    }
    
    return mp_obj_new_str(buffer, result_len);
}
static MP_DEFINE_CONST_FUN_OBJ_2(time_ext_strftime_obj, time_ext_strftime);

// time.strptime(string, format) -> time tuple (basic implementation)
static mp_obj_t time_ext_strptime(mp_obj_t string_in, mp_obj_t format_in) {
    const char *string = mp_obj_str_get_str(string_in);
    const char *format = mp_obj_str_get_str(format_in);
    
    struct tm tm_info;
    memset(&tm_info, 0, sizeof(tm_info));
    tm_info.tm_isdst = -1;
    
    char *result = strptime(string, format, &tm_info);
    if (result == NULL) {
        mp_raise_ValueError(MP_ERROR_TEXT("time data does not match format"));
    }
    
    mp_obj_t tuple[9];
    tuple[0] = MP_OBJ_NEW_SMALL_INT(tm_info.tm_year + 1900);
    tuple[1] = MP_OBJ_NEW_SMALL_INT(tm_info.tm_mon + 1);
    tuple[2] = MP_OBJ_NEW_SMALL_INT(tm_info.tm_mday);
    tuple[3] = MP_OBJ_NEW_SMALL_INT(tm_info.tm_hour);
    tuple[4] = MP_OBJ_NEW_SMALL_INT(tm_info.tm_min);
    tuple[5] = MP_OBJ_NEW_SMALL_INT(tm_info.tm_sec);
    tuple[6] = MP_OBJ_NEW_SMALL_INT(tm_info.tm_wday);
    tuple[7] = MP_OBJ_NEW_SMALL_INT(tm_info.tm_yday + 1);
    tuple[8] = MP_OBJ_NEW_SMALL_INT(tm_info.tm_isdst);
    
    return mp_obj_new_tuple(9, tuple);
}
static MP_DEFINE_CONST_FUN_OBJ_2(time_ext_strptime_obj, time_ext_strptime);

// time.monotonic() -> float
// Returns monotonically increasing time in seconds
static mp_obj_t time_ext_monotonic(void) {
#if defined(__APPLE__)
    // Use mach_absolute_time on macOS for high precision
    static mach_timebase_info_data_t timebase = {0, 0};
    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }
    uint64_t mach_time = mach_absolute_time();
    uint64_t nanos = mach_time * timebase.numer / timebase.denom;
    return mp_obj_new_float((double)nanos / 1e9);
#else
    // Use clock_gettime on Linux
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return mp_obj_new_float((double)ts.tv_sec + (double)ts.tv_nsec / 1e9);
#endif
}
static MP_DEFINE_CONST_FUN_OBJ_0(time_ext_monotonic_obj, time_ext_monotonic);

// time.perf_counter() -> float
// Returns high-resolution performance counter in seconds
static mp_obj_t time_ext_perf_counter(void) {
#if defined(__APPLE__)
    static mach_timebase_info_data_t timebase = {0, 0};
    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }
    uint64_t mach_time = mach_absolute_time();
    uint64_t nanos = mach_time * timebase.numer / timebase.denom;
    return mp_obj_new_float((double)nanos / 1e9);
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return mp_obj_new_float((double)ts.tv_sec + (double)ts.tv_nsec / 1e9);
#endif
}
static MP_DEFINE_CONST_FUN_OBJ_0(time_ext_perf_counter_obj, time_ext_perf_counter);

// Delegation handler for time module attribute lookup
void time_ext_attr(mp_obj_t self_in, qstr attr, mp_obj_t *dest) {
    (void)self_in;
    if (attr == MP_QSTR_strftime) {
        dest[0] = MP_OBJ_FROM_PTR(&time_ext_strftime_obj);
    } else if (attr == MP_QSTR_strptime) {
        dest[0] = MP_OBJ_FROM_PTR(&time_ext_strptime_obj);
    } else if (attr == MP_QSTR_monotonic) {
        dest[0] = MP_OBJ_FROM_PTR(&time_ext_monotonic_obj);
    } else if (attr == MP_QSTR_perf_counter) {
        dest[0] = MP_OBJ_FROM_PTR(&time_ext_perf_counter_obj);
    }
}

// Declare external reference to mp_module_time
extern const mp_obj_module_t mp_module_time;

// Register as delegate/extension to the time module
MP_REGISTER_MODULE_DELEGATION(mp_module_time, time_ext_attr);
