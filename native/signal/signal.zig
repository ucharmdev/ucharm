const std = @import("std");
const c = std.c;

// Signal module - provides signal handling for CLI applications
// Compatible with Python's signal module API

// Signal handler storage
const MAX_SIGNALS: usize = 32;
var signal_pending: [MAX_SIGNALS]bool = [_]bool{false} ** MAX_SIGNALS;
var signal_count: [MAX_SIGNALS]u32 = [_]u32{0} ** MAX_SIGNALS;

// Default handler that sets pending flag
fn defaultHandler(sig: c_int) callconv(.c) void {
    const s: usize = @intCast(sig);
    if (s < MAX_SIGNALS) {
        signal_pending[s] = true;
        signal_count[s] +%= 1;
    }
}

// External C functions
extern fn sigaction(sig: c_int, act: ?*const c.Sigaction, oact: ?*c.Sigaction) c_int;
extern fn sigprocmask(how: c_int, set: ?*const c.sigset_t, oset: ?*c.sigset_t) c_int;
extern fn sigemptyset(set: *c.sigset_t) c_int;
extern fn sigaddset(set: *c.sigset_t, signo: c_int) c_int;
extern fn sigismember(set: *const c.sigset_t, signo: c_int) c_int;
extern fn pause() c_int;

const SIG_BLOCK: c_int = 1;
const SIG_UNBLOCK: c_int = 2;
const SIG_SETMASK: c_int = 3;

/// Register a signal handler
/// Returns 0 on success, -1 on error
pub export fn signal_signal(sig: i32, handler: i32) i32 {
    var act: c.Sigaction = undefined;
    var empty_set: c.sigset_t = undefined;
    _ = sigemptyset(&empty_set);

    act.mask = empty_set;
    act.flags = 0;

    if (handler == 0) {
        // SIG_DFL
        act.handler = .{ .handler = c.SIG.DFL };
    } else if (handler == 1) {
        // SIG_IGN
        act.handler = .{ .handler = c.SIG.IGN };
    } else {
        // Custom handler - use our default handler that sets pending
        act.handler = .{ .handler = defaultHandler };
    }

    const result = sigaction(sig, &act, null);
    if (result < 0) return -1;
    return 0;
}

/// Check if a signal is pending and clear it
/// Returns 1 if signal was pending, 0 if not
pub export fn signal_pending_check(sig: i32) i32 {
    const s: usize = @intCast(sig);
    if (s >= MAX_SIGNALS) return 0;

    if (signal_pending[s]) {
        signal_pending[s] = false;
        return 1;
    }
    return 0;
}

/// Get count of times signal was received
pub export fn signal_get_count(sig: i32) u32 {
    const s: usize = @intCast(sig);
    if (s >= MAX_SIGNALS) return 0;
    return signal_count[s];
}

/// Reset signal count
pub export fn signal_reset_count(sig: i32) void {
    const s: usize = @intCast(sig);
    if (s < MAX_SIGNALS) {
        signal_count[s] = 0;
    }
}

/// Send a signal to a process
/// Returns 0 on success, -1 on error
pub export fn signal_kill(pid: i32, sig: i32) i32 {
    const result = c.kill(pid, sig);
    if (result < 0) return -1;
    return 0;
}

/// Raise a signal in the current process
/// Returns 0 on success, -1 on error
pub export fn signal_raise(sig: i32) i32 {
    const result = c.raise(sig);
    if (result < 0) return -1;
    return 0;
}

/// Pause until a signal is received
pub export fn signal_pause() void {
    _ = pause();
}

/// Set an alarm to deliver SIGALRM after seconds
/// Returns the number of seconds remaining on previous alarm
pub export fn signal_alarm(seconds: u32) u32 {
    return c.alarm(seconds);
}

/// Get the current process ID
pub export fn signal_getpid() i32 {
    return c.getpid();
}

/// Get the parent process ID
pub export fn signal_getppid() i32 {
    return c.getppid();
}

/// Block a signal
pub export fn signal_block(sig: i32) i32 {
    var set: c.sigset_t = undefined;
    _ = sigemptyset(&set);
    _ = sigaddset(&set, sig);
    const result = sigprocmask(SIG_BLOCK, &set, null);
    if (result < 0) return -1;
    return 0;
}

/// Unblock a signal
pub export fn signal_unblock(sig: i32) i32 {
    var set: c.sigset_t = undefined;
    _ = sigemptyset(&set);
    _ = sigaddset(&set, sig);
    const result = sigprocmask(SIG_UNBLOCK, &set, null);
    if (result < 0) return -1;
    return 0;
}

/// Check if a signal is blocked
pub export fn signal_is_blocked(sig: i32) i32 {
    var current_set: c.sigset_t = undefined;
    const result = sigprocmask(SIG_SETMASK, null, &current_set);
    if (result < 0) return -1;
    return sigismember(&current_set, sig);
}

// Signal number constants
pub export fn signal_get_SIGINT() i32 {
    return c.SIG.INT;
}
pub export fn signal_get_SIGTERM() i32 {
    return c.SIG.TERM;
}
pub export fn signal_get_SIGKILL() i32 {
    return c.SIG.KILL;
}
pub export fn signal_get_SIGSTOP() i32 {
    return c.SIG.STOP;
}
pub export fn signal_get_SIGCONT() i32 {
    return c.SIG.CONT;
}
pub export fn signal_get_SIGCHLD() i32 {
    return c.SIG.CHLD;
}
pub export fn signal_get_SIGUSR1() i32 {
    return c.SIG.USR1;
}
pub export fn signal_get_SIGUSR2() i32 {
    return c.SIG.USR2;
}
pub export fn signal_get_SIGALRM() i32 {
    return c.SIG.ALRM;
}
pub export fn signal_get_SIGHUP() i32 {
    return c.SIG.HUP;
}
pub export fn signal_get_SIGPIPE() i32 {
    return c.SIG.PIPE;
}
pub export fn signal_get_SIGQUIT() i32 {
    return c.SIG.QUIT;
}
pub export fn signal_get_SIGABRT() i32 {
    return c.SIG.ABRT;
}
pub export fn signal_get_SIGWINCH() i32 {
    return c.SIG.WINCH;
}
