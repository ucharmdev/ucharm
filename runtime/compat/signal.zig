const std = @import("std");
const pk = @import("pk");
const c = pk.c;

const handlers_key: [:0]const u8 = "__handlers__";

// Signal handler sentinel values
const SIG_DFL: i64 = 0;
const SIG_IGN: i64 = 1;

fn ensureHandlers(module: c.py_Ref) c.py_Ref {
    const existing = c.py_getdict(module, c.py_name(handlers_key));
    if (existing) |val| return val;
    c.py_newdict(c.py_r0());
    c.py_setdict(module, c.py_name(handlers_key), c.py_r0());
    return c.py_r0();
}

fn signalFn(ctx: *pk.Context) bool {
    const signum = ctx.argInt(0) orelse return ctx.typeError("signum must be int");
    var handler = ctx.arg(1) orelse return ctx.typeError("handler required");

    const module = c.py_getmodule("signal");
    if (module == null) {
        return ctx.runtimeError("signal module missing");
    }
    const handlers = ensureHandlers(module.?);

    c.py_newint(c.py_r1(), signum);
    _ = c.py_dict_setitem(handlers, c.py_r1(), handler.ref());

    return ctx.returnValue(handler);
}

fn getsignalFn(ctx: *pk.Context) bool {
    const signum = ctx.argInt(0) orelse return ctx.typeError("signum must be int");

    const module = c.py_getmodule("signal");
    if (module == null) {
        return ctx.returnInt(SIG_DFL);
    }

    const handlers = ensureHandlers(module.?);
    c.py_newint(c.py_r1(), signum);
    const found = c.py_dict_getitem(handlers, c.py_r1());
    if (found != 0) {
        // Result is in py_retval() already
        return true;
    } else {
        return ctx.returnInt(SIG_DFL);
    }
}

fn raiseFn(ctx: *pk.Context) bool {
    const signum = ctx.argInt(0) orelse return ctx.typeError("signum must be int");

    // Actually raise the signal
    _ = std.c.raise(@intCast(signum));

    return ctx.returnNone();
}

fn alarmFn(_: *pk.Context) bool {
    // alarm() is Unix-specific, return 0 as if no previous alarm was set
    c.py_newint(c.py_retval(), 0);
    return true;
}

fn pauseFn(ctx: *pk.Context) bool {
    // pause() would block waiting for a signal - just return None
    return ctx.returnNone();
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("signal");

    // Signal handler constants
    _ = builder
        .constInt("SIG_DFL", SIG_DFL)
        .constInt("SIG_IGN", SIG_IGN)
        // Standard signals (POSIX)
        .constInt("SIGHUP", 1)
        .constInt("SIGINT", 2)
        .constInt("SIGQUIT", 3)
        .constInt("SIGILL", 4)
        .constInt("SIGTRAP", 5)
        .constInt("SIGABRT", 6)
        .constInt("SIGBUS", 7)
        .constInt("SIGFPE", 8)
        .constInt("SIGKILL", 9)
        .constInt("SIGUSR1", 10)
        .constInt("SIGSEGV", 11)
        .constInt("SIGUSR2", 12)
        .constInt("SIGPIPE", 13)
        .constInt("SIGALRM", 14)
        .constInt("SIGTERM", 15)
        .constInt("SIGCHLD", 17)
        .constInt("SIGCONT", 18)
        .constInt("SIGSTOP", 19)
        .constInt("SIGTSTP", 20)
        // Functions
        .funcWrapped("signal", 2, 2, signalFn)
        .funcWrapped("getsignal", 1, 1, getsignalFn)
        .funcWrapped("raise_signal", 1, 1, raiseFn)
        .funcWrapped("alarm", 1, 1, alarmFn)
        .funcWrapped("pause", 0, 0, pauseFn);
}
