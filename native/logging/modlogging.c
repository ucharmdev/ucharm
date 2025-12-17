/*
 * modlogging - Native logging module for microcharm
 * 
 * Provides Python's logging functionality:
 * - debug, info, warning, error, critical functions
 * - basicConfig for setup
 * - setLevel/getLogger for configuration
 * 
 * Usage in Python:
 *   import logging
 *   
 *   logging.basicConfig(level=logging.INFO)
 *   logging.info("Hello %s", "world")
 *   logging.warning("Something happened")
 */

#include "../bridge/mpy_bridge.h"
#include <time.h>

// Zig functions
extern void logging_set_level(uint32_t level);
extern uint32_t logging_get_level(void);
extern bool logging_is_enabled(uint32_t level);
extern size_t logging_level_name(uint32_t level, char *out, size_t out_max);
extern int32_t logging_parse_level(const char *name, size_t name_len);
extern size_t logging_format_timestamp(int64_t timestamp, char *out, size_t out_max);
extern size_t logging_format_basic(uint32_t level, const char *msg, size_t msg_len,
                                   char *out, size_t out_max);

// Log level constants
#define LOG_NOTSET   0
#define LOG_DEBUG    10
#define LOG_INFO     20
#define LOG_WARNING  30
#define LOG_ERROR    40
#define LOG_CRITICAL 50

// Current format and stream
static mp_obj_t log_format = MP_OBJ_NULL;
static mp_obj_t log_stream = MP_OBJ_NULL;

// Helper to format and output a log message
static void do_log(uint32_t level, size_t n_args, const mp_obj_t *args) {
    if (!logging_is_enabled(level)) {
        return;
    }
    
    // Get message
    mp_obj_t msg_obj;
    if (n_args == 1) {
        msg_obj = args[0];
    } else {
        // Format string with args
        msg_obj = mp_obj_str_binary_op(MP_BINARY_OP_MODULO, args[0], 
                                        mp_obj_new_tuple(n_args - 1, args + 1));
    }
    
    size_t msg_len;
    const char *msg = mpy_str_len(msg_obj, &msg_len);
    
    // Format output
    char buffer[1024];
    size_t out_len = 0;
    
    // Add timestamp
    time_t now = time(NULL);
    out_len = logging_format_timestamp((int64_t)now, buffer, sizeof(buffer));
    
    // Add separator
    if (out_len + 3 < sizeof(buffer)) {
        buffer[out_len++] = ' ';
        buffer[out_len++] = '-';
        buffer[out_len++] = ' ';
    }
    
    // Add level
    out_len += logging_level_name(level, buffer + out_len, sizeof(buffer) - out_len);
    
    // Add separator
    if (out_len + 3 < sizeof(buffer)) {
        buffer[out_len++] = ' ';
        buffer[out_len++] = '-';
        buffer[out_len++] = ' ';
    }
    
    // Add message
    size_t msg_copy = msg_len;
    if (out_len + msg_copy >= sizeof(buffer)) {
        msg_copy = sizeof(buffer) - out_len - 1;
    }
    memcpy(buffer + out_len, msg, msg_copy);
    out_len += msg_copy;
    
    // Add newline
    if (out_len < sizeof(buffer)) {
        buffer[out_len++] = '\n';
    }
    
    // Output to stream or stdout
    if (log_stream != MP_OBJ_NULL && log_stream != mp_const_none) {
        mp_obj_t write_method = mp_load_attr(log_stream, MP_QSTR_write);
        mp_call_function_1(write_method, mpy_new_str_len(buffer, out_len));
    } else {
        // Write to stdout using mp_printf
        mp_obj_t str = mpy_new_str_len(buffer, out_len);
        mp_obj_print_helper(&mp_sys_stdout_print, str, PRINT_STR);
    }
}

// ============================================================================
// Logging functions
// ============================================================================

MPY_FUNC_VAR(logging, debug, 1, 10) {
    do_log(LOG_DEBUG, n_args, args);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(logging, debug, 1, 10);

MPY_FUNC_VAR(logging, info, 1, 10) {
    do_log(LOG_INFO, n_args, args);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(logging, info, 1, 10);

MPY_FUNC_VAR(logging, warning, 1, 10) {
    do_log(LOG_WARNING, n_args, args);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(logging, warning, 1, 10);

MPY_FUNC_VAR(logging, error, 1, 10) {
    do_log(LOG_ERROR, n_args, args);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(logging, error, 1, 10);

MPY_FUNC_VAR(logging, critical, 1, 10) {
    do_log(LOG_CRITICAL, n_args, args);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(logging, critical, 1, 10);

// Alias
MPY_FUNC_VAR(logging, warn, 1, 10) {
    do_log(LOG_WARNING, n_args, args);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(logging, warn, 1, 10);

MPY_FUNC_VAR(logging, fatal, 1, 10) {
    do_log(LOG_CRITICAL, n_args, args);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(logging, fatal, 1, 10);

// ============================================================================
// Configuration functions
// ============================================================================

// logging.setLevel(level)
MPY_FUNC_1(logging, setLevel) {
    uint32_t level;
    
    if (mp_obj_is_int(arg0)) {
        level = mpy_int(arg0);
    } else {
        // Parse level name
        size_t len;
        const char *name = mpy_str_len(arg0, &len);
        int32_t parsed = logging_parse_level(name, len);
        if (parsed < 0) {
            mp_raise_ValueError(MP_ERROR_TEXT("Unknown level name"));
        }
        level = (uint32_t)parsed;
    }
    
    logging_set_level(level);
    return mpy_none();
}
MPY_FUNC_OBJ_1(logging, setLevel);

// logging.getLevel()
MPY_FUNC_0(logging, getLevel) {
    return mpy_new_int(logging_get_level());
}
MPY_FUNC_OBJ_0(logging, getLevel);

// logging.getLevelName(level)
MPY_FUNC_1(logging, getLevelName) {
    uint32_t level = mpy_int(arg0);
    char buffer[16];
    size_t len = logging_level_name(level, buffer, sizeof(buffer));
    return mpy_new_str_len(buffer, len);
}
MPY_FUNC_OBJ_1(logging, getLevelName);

// logging.basicConfig(level=WARNING, format=None, stream=None)
static mp_obj_t logging_basicConfig(size_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    // Parse keyword arguments
    mp_map_elem_t *elem;
    
    // level
    elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_level), MP_MAP_LOOKUP);
    if (elem != NULL && elem->value != mp_const_none) {
        uint32_t level;
        if (mp_obj_is_int(elem->value)) {
            level = mpy_int(elem->value);
        } else {
            size_t len;
            const char *name = mpy_str_len(elem->value, &len);
            int32_t parsed = logging_parse_level(name, len);
            if (parsed < 0) {
                mp_raise_ValueError(MP_ERROR_TEXT("Unknown level name"));
            }
            level = (uint32_t)parsed;
        }
        logging_set_level(level);
    }
    
    // format
    elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_format), MP_MAP_LOOKUP);
    if (elem != NULL) {
        log_format = elem->value;
    }
    
    // stream
    elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_stream), MP_MAP_LOOKUP);
    if (elem != NULL) {
        log_stream = elem->value;
    }
    
    return mpy_none();
}
static MP_DEFINE_CONST_FUN_OBJ_KW(mod_logging_basicConfig_obj, 0, logging_basicConfig);

// logging.disable(level=CRITICAL)
MPY_FUNC_VAR(logging, disable, 0, 1) {
    uint32_t level = (n_args >= 1) ? mpy_int(args[0]) : LOG_CRITICAL;
    logging_set_level(level + 1);  // Disable this level and below
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(logging, disable, 0, 1);

// logging.isEnabledFor(level)
MPY_FUNC_1(logging, isEnabledFor) {
    uint32_t level = mpy_int(arg0);
    return mpy_bool(logging_is_enabled(level));
}
MPY_FUNC_OBJ_1(logging, isEnabledFor);

// logging.log(level, msg, *args)
MPY_FUNC_VAR(logging, log, 2, 12) {
    uint32_t level = mpy_int(args[0]);
    do_log(level, n_args - 1, args + 1);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(logging, log, 2, 12);

// ============================================================================
// Simple Logger class
// ============================================================================

typedef struct _logging_logger_obj_t {
    mp_obj_base_t base;
    mp_obj_t name;
    uint32_t level;
} logging_logger_obj_t;

static mp_obj_t logger_debug(size_t n_args, const mp_obj_t *args);
static mp_obj_t logger_info(size_t n_args, const mp_obj_t *args);
static mp_obj_t logger_warning(size_t n_args, const mp_obj_t *args);
static mp_obj_t logger_error(size_t n_args, const mp_obj_t *args);
static mp_obj_t logger_critical(size_t n_args, const mp_obj_t *args);
static mp_obj_t logger_setLevel(mp_obj_t self, mp_obj_t level);

static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(logger_debug_obj, 2, 11, logger_debug);
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(logger_info_obj, 2, 11, logger_info);
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(logger_warning_obj, 2, 11, logger_warning);
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(logger_error_obj, 2, 11, logger_error);
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(logger_critical_obj, 2, 11, logger_critical);
static MP_DEFINE_CONST_FUN_OBJ_2(logger_setLevel_obj, logger_setLevel);

static const mp_rom_map_elem_t logger_locals_dict_table[] = {
    { MP_ROM_QSTR(MP_QSTR_debug), MP_ROM_PTR(&logger_debug_obj) },
    { MP_ROM_QSTR(MP_QSTR_info), MP_ROM_PTR(&logger_info_obj) },
    { MP_ROM_QSTR(MP_QSTR_warning), MP_ROM_PTR(&logger_warning_obj) },
    { MP_ROM_QSTR(MP_QSTR_error), MP_ROM_PTR(&logger_error_obj) },
    { MP_ROM_QSTR(MP_QSTR_critical), MP_ROM_PTR(&logger_critical_obj) },
    { MP_ROM_QSTR(MP_QSTR_setLevel), MP_ROM_PTR(&logger_setLevel_obj) },
};
static MP_DEFINE_CONST_DICT(logger_locals_dict, logger_locals_dict_table);

static mp_obj_t logger_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    logging_logger_type,
    MP_QSTR_Logger,
    MP_TYPE_FLAG_NONE,
    make_new, logger_make_new,
    locals_dict, &logger_locals_dict
);

static mp_obj_t logger_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 0, 1, false);
    
    logging_logger_obj_t *self = mp_obj_malloc(logging_logger_obj_t, &logging_logger_type);
    self->name = (n_args >= 1) ? args[0] : mpy_new_str("root");
    self->level = LOG_NOTSET;  // Use root level
    
    return MP_OBJ_FROM_PTR(self);
}

static void logger_do_log(logging_logger_obj_t *self, uint32_t level, size_t n_args, const mp_obj_t *args) {
    uint32_t effective_level = (self->level != LOG_NOTSET) ? self->level : logging_get_level();
    if (level < effective_level) return;
    do_log(level, n_args - 1, args + 1);  // Skip self
}

static mp_obj_t logger_debug(size_t n_args, const mp_obj_t *args) {
    logger_do_log(MP_OBJ_TO_PTR(args[0]), LOG_DEBUG, n_args, args);
    return mpy_none();
}

static mp_obj_t logger_info(size_t n_args, const mp_obj_t *args) {
    logger_do_log(MP_OBJ_TO_PTR(args[0]), LOG_INFO, n_args, args);
    return mpy_none();
}

static mp_obj_t logger_warning(size_t n_args, const mp_obj_t *args) {
    logger_do_log(MP_OBJ_TO_PTR(args[0]), LOG_WARNING, n_args, args);
    return mpy_none();
}

static mp_obj_t logger_error(size_t n_args, const mp_obj_t *args) {
    logger_do_log(MP_OBJ_TO_PTR(args[0]), LOG_ERROR, n_args, args);
    return mpy_none();
}

static mp_obj_t logger_critical(size_t n_args, const mp_obj_t *args) {
    logger_do_log(MP_OBJ_TO_PTR(args[0]), LOG_CRITICAL, n_args, args);
    return mpy_none();
}

static mp_obj_t logger_setLevel(mp_obj_t self_in, mp_obj_t level) {
    logging_logger_obj_t *self = MP_OBJ_TO_PTR(self_in);
    self->level = mpy_int(level);
    return mpy_none();
}

// logging.getLogger(name=None)
MPY_FUNC_VAR(logging, getLogger, 0, 1) {
    mp_obj_t name = (n_args >= 1) ? args[0] : mpy_new_str("root");
    mp_obj_t make_args[1] = {name};
    return logger_make_new(&logging_logger_type, 1, 0, make_args);
}
MPY_FUNC_OBJ_VAR(logging, getLogger, 0, 1);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(logging)
    // Logging functions
    MPY_MODULE_FUNC(logging, debug)
    MPY_MODULE_FUNC(logging, info)
    MPY_MODULE_FUNC(logging, warning)
    MPY_MODULE_FUNC(logging, warn)
    MPY_MODULE_FUNC(logging, error)
    MPY_MODULE_FUNC(logging, critical)
    MPY_MODULE_FUNC(logging, fatal)
    MPY_MODULE_FUNC(logging, log)
    
    // Configuration
    { MP_ROM_QSTR(MP_QSTR_basicConfig), MP_ROM_PTR(&mod_logging_basicConfig_obj) },
    MPY_MODULE_FUNC(logging, setLevel)
    MPY_MODULE_FUNC(logging, getLevel)
    MPY_MODULE_FUNC(logging, getLevelName)
    MPY_MODULE_FUNC(logging, disable)
    MPY_MODULE_FUNC(logging, isEnabledFor)
    MPY_MODULE_FUNC(logging, getLogger)
    
    // Logger class
    { MP_ROM_QSTR(MP_QSTR_Logger), MP_ROM_PTR(&logging_logger_type) },
    
    // Log level constants
    MPY_MODULE_INT(NOTSET, 0)
    MPY_MODULE_INT(DEBUG, 10)
    MPY_MODULE_INT(INFO, 20)
    MPY_MODULE_INT(WARNING, 30)
    MPY_MODULE_INT(WARN, 30)
    MPY_MODULE_INT(ERROR, 40)
    MPY_MODULE_INT(CRITICAL, 50)
    MPY_MODULE_INT(FATAL, 50)
MPY_MODULE_END(logging)
