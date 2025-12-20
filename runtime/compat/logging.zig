const std = @import("std");
const pk = @import("pk");
const c = pk.c;

// Log levels (matching Python's logging module)
const NOTSET: i32 = 0;
const DEBUG: i32 = 10;
const INFO: i32 = 20;
const WARNING: i32 = 30;
const ERROR: i32 = 40;
const CRITICAL: i32 = 50;

var tp_logger: c.py_Type = 0;
var tp_handler: c.py_Type = 0;
var tp_stream_handler: c.py_Type = 0;
var tp_file_handler: c.py_Type = 0;
var tp_formatter: c.py_Type = 0;

fn getModule() c.py_GlobalRef {
    return c.py_getmodule("logging") orelse c.py_newmodule("logging");
}

fn getCacheDict(module: c.py_Ref) ?c.py_Ref {
    return c.py_getdict(module, c.py_name("_loggers"));
}

fn getRootLogger(module: c.py_Ref) ?c.py_Ref {
    return c.py_getdict(module, c.py_name("_root"));
}

fn writeLog(level: i32, message: c.py_Ref) void {
    const prefix: []const u8 = switch (level) {
        DEBUG => "DEBUG:",
        INFO => "INFO:",
        WARNING => "WARNING:",
        ERROR => "ERROR:",
        CRITICAL => "CRITICAL:",
        else => "LOG:",
    };

    const sv = c.py_tosv(message);
    if (sv.size > 0) {
        const msg_slice = sv.data[0..@intCast(sv.size)];
        std.debug.print("{s} {s}\n", .{ prefix, msg_slice });
    } else {
        std.debug.print("{s}\n", .{prefix});
    }
}

fn initLoggerObject(logger: c.py_Ref, name: []const u8, parent: ?c.py_Ref) void {
    const module = getModule();
    _ = module;

    // name
    const buf = c.py_newstrn(c.py_r0(), @intCast(name.len));
    if (name.len > 0) @memcpy(@as([*]u8, @ptrCast(buf))[0..name.len], name);
    c.py_setdict(logger, c.py_name("name"), c.py_r0());

    // level
    c.py_newint(c.py_r0(), NOTSET);
    c.py_setdict(logger, c.py_name("level"), c.py_r0());

    // handlers
    c.py_newlist(c.py_r0());
    c.py_setdict(logger, c.py_name("handlers"), c.py_r0());

    // parent
    if (parent) |p| {
        c.py_setdict(logger, c.py_name("parent"), p);
    } else {
        c.py_newnone(c.py_r0());
        c.py_setdict(logger, c.py_name("parent"), c.py_r0());
    }
}

fn getLoggerLevel(logger: c.py_Ref) i32 {
    const level_val = c.py_getdict(logger, c.py_name("level")) orelse return WARNING;
    return @intCast(c.py_toint(level_val.?));
}

fn loggerSetLevel(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "setLevel() takes exactly 1 argument");
    const self = pk.argRef(argv, 0);
    const level: i32 = @intCast(c.py_toint(pk.argRef(argv, 1)));
    c.py_newint(c.py_r0(), level);
    c.py_setdict(self, c.py_name("level"), c.py_r0());
    c.py_newnone(c.py_retval());
    return true;
}

fn loggerGetEffectiveLevel(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "getEffectiveLevel() takes no arguments");
    const self = pk.argRef(argv, 0);
    const level = getLoggerLevel(self);
    c.py_newint(c.py_retval(), level);
    return true;
}

fn loggerAddHandler(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "addHandler() takes exactly 1 argument");
    const self = pk.argRef(argv, 0);
    const handlers = c.py_getdict(self, c.py_name("handlers")) orelse return c.py_exception(c.tp_RuntimeError, "handlers missing");
    c.py_list_append(handlers.?, pk.argRef(argv, 1));
    c.py_newnone(c.py_retval());
    return true;
}

fn loggerLogWithLevel(self: c.py_Ref, level: i32, message: c.py_Ref) void {
    const eff = getLoggerLevel(self);
    if (level >= eff) writeLog(level, message);
}

fn loggerDebug(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "debug() requires a message");
    loggerLogWithLevel(pk.argRef(argv, 0), DEBUG, pk.argRef(argv, 1));
    c.py_newnone(c.py_retval());
    return true;
}

fn loggerInfo(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "info() requires a message");
    loggerLogWithLevel(pk.argRef(argv, 0), INFO, pk.argRef(argv, 1));
    c.py_newnone(c.py_retval());
    return true;
}

fn loggerWarning(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "warning() requires a message");
    loggerLogWithLevel(pk.argRef(argv, 0), WARNING, pk.argRef(argv, 1));
    c.py_newnone(c.py_retval());
    return true;
}

fn loggerError(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "error() requires a message");
    loggerLogWithLevel(pk.argRef(argv, 0), ERROR, pk.argRef(argv, 1));
    c.py_newnone(c.py_retval());
    return true;
}

fn loggerCritical(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "critical() requires a message");
    loggerLogWithLevel(pk.argRef(argv, 0), CRITICAL, pk.argRef(argv, 1));
    c.py_newnone(c.py_retval());
    return true;
}

fn getOrCreateLoggerByName(name: []const u8) bool {
    const module = getModule();
    const cache = getCacheDict(module) orelse return c.py_exception(c.tp_RuntimeError, "logger cache missing");
    const name_z = std.heap.page_allocator.dupeZ(u8, name) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    defer std.heap.page_allocator.free(name_z);

    const found = c.py_dict_getitem_by_str(cache.?, name_z);
    if (found < 0) return false;
    if (found > 0) {
        pk.setRetval(c.py_retval());
        return true;
    }

    // Create logger.
    _ = c.py_newobject(c.py_retval(), tp_logger, -1, 0);
    const logger_obj = c.py_retval();

    // parent
    var parent: ?c.py_Ref = null;
    if (name.len == 0) {
        parent = null;
    } else if (std.mem.lastIndexOfScalar(u8, name, '.')) |dot| {
        const parent_name = name[0..dot];
        if (!getOrCreateLoggerByName(parent_name)) return false;
        parent = c.py_retval();
    } else {
        parent = getRootLogger(module).?;
    }

    initLoggerObject(logger_obj, name, parent);
    if (!c.py_dict_setitem_by_str(cache.?, name_z, logger_obj)) return false;
    pk.setRetval(logger_obj);
    return true;
}

fn getLogger(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc > 1) return c.py_exception(c.tp_TypeError, "getLogger() takes at most 1 argument");
    const module = getModule();

    if (argc == 0) {
        const root = getRootLogger(module) orelse return c.py_exception(c.tp_RuntimeError, "root logger missing");
        pk.setRetval(root.?);
        return true;
    }

    const arg0 = pk.argRef(argv, 0);
    if (c.py_isnone(arg0)) {
        const root = getRootLogger(module) orelse return c.py_exception(c.tp_RuntimeError, "root logger missing");
        pk.setRetval(root.?);
        return true;
    }

    const name_c = c.py_tostr(arg0) orelse return c.py_exception(c.tp_TypeError, "name must be a string");
    const name = std.mem.span(name_c);
    return getOrCreateLoggerByName(name);
}

fn basicConfig(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    c.py_newnone(c.py_retval());
    return true;
}

fn modLog(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "log() requires level and message");
    const level: i32 = @intCast(c.py_toint(pk.argRef(argv, 0)));
    writeLog(level, pk.argRef(argv, 1));
    c.py_newnone(c.py_retval());
    return true;
}

fn modDebug(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "debug() requires a message");
    writeLog(DEBUG, pk.argRef(argv, 0));
    c.py_newnone(c.py_retval());
    return true;
}

fn modInfo(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "info() requires a message");
    writeLog(INFO, pk.argRef(argv, 0));
    c.py_newnone(c.py_retval());
    return true;
}

fn modWarning(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "warning() requires a message");
    writeLog(WARNING, pk.argRef(argv, 0));
    c.py_newnone(c.py_retval());
    return true;
}

fn modError(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "error() requires a message");
    writeLog(ERROR, pk.argRef(argv, 0));
    c.py_newnone(c.py_retval());
    return true;
}

fn modCritical(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "critical() requires a message");
    writeLog(CRITICAL, pk.argRef(argv, 0));
    c.py_newnone(c.py_retval());
    return true;
}

// Handler API (minimal)
fn handlerNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    _ = c.py_newobject(c.py_retval(), tp_handler, -1, 0);
    c.py_newint(c.py_r0(), NOTSET);
    c.py_setdict(c.py_retval(), c.py_name("level"), c.py_r0());
    c.py_newnone(c.py_r0());
    c.py_setdict(c.py_retval(), c.py_name("formatter"), c.py_r0());
    return true;
}

fn handlerSetLevel(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "setLevel() takes exactly 1 argument");
    const self = pk.argRef(argv, 0);
    const level: i32 = @intCast(c.py_toint(pk.argRef(argv, 1)));
    c.py_newint(c.py_r0(), level);
    c.py_setdict(self, c.py_name("level"), c.py_r0());
    c.py_newnone(c.py_retval());
    return true;
}

fn handlerSetFormatter(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "setFormatter() takes exactly 1 argument");
    const self = pk.argRef(argv, 0);
    c.py_setdict(self, c.py_name("formatter"), pk.argRef(argv, 1));
    c.py_newnone(c.py_retval());
    return true;
}

fn streamHandlerNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    _ = c.py_newobject(c.py_retval(), tp_stream_handler, -1, 0);
    c.py_newint(c.py_r0(), NOTSET);
    c.py_setdict(c.py_retval(), c.py_name("level"), c.py_r0());
    c.py_newnone(c.py_r0());
    c.py_setdict(c.py_retval(), c.py_name("formatter"), c.py_r0());
    return true;
}

fn fileHandlerNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    _ = c.py_newobject(c.py_retval(), tp_file_handler, -1, 0);
    c.py_newint(c.py_r0(), NOTSET);
    c.py_setdict(c.py_retval(), c.py_name("level"), c.py_r0());
    c.py_newnone(c.py_r0());
    c.py_setdict(c.py_retval(), c.py_name("formatter"), c.py_r0());
    return true;
}

// Formatter (minimal)
fn formatterNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // __new__(cls, fmt=None)
    if (argc > 2) return c.py_exception(c.tp_TypeError, "Formatter() takes at most 1 argument");
    _ = c.py_newobject(c.py_retval(), tp_formatter, -1, 0);
    if (argc == 2) {
        c.py_setdict(c.py_retval(), c.py_name("fmt"), pk.argRef(argv, 1));
    } else {
        c.py_newnone(c.py_r0());
        c.py_setdict(c.py_retval(), c.py_name("fmt"), c.py_r0());
    }
    return true;
}

pub fn register() void {
    const module = getModule();

    // Cache dict
    c.py_newdict(c.py_r0());
    c.py_setdict(module, c.py_name("_loggers"), c.py_r0());

    // Logger type
    tp_logger = c.py_newtype("Logger", c.tp_object, module, null);
    c.py_bindmethod(tp_logger, "setLevel", loggerSetLevel);
    c.py_bindmethod(tp_logger, "getEffectiveLevel", loggerGetEffectiveLevel);
    c.py_bindmethod(tp_logger, "addHandler", loggerAddHandler);
    c.py_bindmethod(tp_logger, "debug", loggerDebug);
    c.py_bindmethod(tp_logger, "info", loggerInfo);
    c.py_bindmethod(tp_logger, "warning", loggerWarning);
    c.py_bindmethod(tp_logger, "error", loggerError);
    c.py_bindmethod(tp_logger, "critical", loggerCritical);

    // Root logger instance
    _ = c.py_newobject(c.py_r1(), tp_logger, -1, 0);
    const root = c.py_r1();
    initLoggerObject(root, "", null);
    c.py_setdict(module, c.py_name("_root"), root);
    const cache = getCacheDict(module).?;
    _ = c.py_dict_setitem_by_str(cache, "", root);

    // Handlers + Formatter
    tp_handler = c.py_newtype("Handler", c.tp_object, module, null);
    c.py_bind(c.py_tpobject(tp_handler), "__new__(cls)", handlerNew);
    c.py_bindmethod(tp_handler, "setLevel", handlerSetLevel);
    c.py_bindmethod(tp_handler, "setFormatter", handlerSetFormatter);
    c.py_setdict(module, c.py_name("Handler"), c.py_tpobject(tp_handler));

    tp_stream_handler = c.py_newtype("StreamHandler", tp_handler, module, null);
    c.py_bind(c.py_tpobject(tp_stream_handler), "__new__(cls)", streamHandlerNew);
    c.py_bindmethod(tp_stream_handler, "setLevel", handlerSetLevel);
    c.py_bindmethod(tp_stream_handler, "setFormatter", handlerSetFormatter);
    c.py_setdict(module, c.py_name("StreamHandler"), c.py_tpobject(tp_stream_handler));

    tp_file_handler = c.py_newtype("FileHandler", tp_handler, module, null);
    c.py_bind(c.py_tpobject(tp_file_handler), "__new__(cls, filename=None)", fileHandlerNew);
    c.py_bindmethod(tp_file_handler, "setLevel", handlerSetLevel);
    c.py_bindmethod(tp_file_handler, "setFormatter", handlerSetFormatter);
    c.py_setdict(module, c.py_name("FileHandler"), c.py_tpobject(tp_file_handler));

    tp_formatter = c.py_newtype("Formatter", c.tp_object, module, null);
    c.py_bind(c.py_tpobject(tp_formatter), "__new__(cls, fmt=None)", formatterNew);
    c.py_setdict(module, c.py_name("Formatter"), c.py_tpobject(tp_formatter));

    // Module-level functions
    c.py_bind(module, "getLogger(name=None)", getLogger);
    c.py_bind(module, "basicConfig(**kwargs)", basicConfig);
    c.py_bind(module, "debug(msg, *args, **kwargs)", modDebug);
    c.py_bind(module, "info(msg, *args, **kwargs)", modInfo);
    c.py_bind(module, "warning(msg, *args, **kwargs)", modWarning);
    c.py_bind(module, "error(msg, *args, **kwargs)", modError);
    c.py_bind(module, "critical(msg, *args, **kwargs)", modCritical);
    c.py_bind(module, "log(level, msg, *args, **kwargs)", modLog);

    // Constants
    c.py_newint(c.py_r0(), NOTSET);
    c.py_setdict(module, c.py_name("NOTSET"), c.py_r0());
    c.py_newint(c.py_r0(), DEBUG);
    c.py_setdict(module, c.py_name("DEBUG"), c.py_r0());
    c.py_newint(c.py_r0(), INFO);
    c.py_setdict(module, c.py_name("INFO"), c.py_r0());
    c.py_newint(c.py_r0(), WARNING);
    c.py_setdict(module, c.py_name("WARNING"), c.py_r0());
    c.py_setdict(module, c.py_name("WARN"), c.py_r0());
    c.py_newint(c.py_r0(), ERROR);
    c.py_setdict(module, c.py_name("ERROR"), c.py_r0());
    c.py_newint(c.py_r0(), CRITICAL);
    c.py_setdict(module, c.py_name("CRITICAL"), c.py_r0());
    c.py_setdict(module, c.py_name("FATAL"), c.py_r0());
}
