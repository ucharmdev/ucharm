/*
 * modsignal - Native signal handling module for ucharm
 * 
 * This module bridges Zig's signal implementation to MicroPython.
 * Compatible with Python's signal module API.
 * 
 * Usage in Python:
 *   import signal
 *   
 *   def handler(signum):
 *       print(f"Received signal {signum}")
 *   
 *   signal.signal(signal.SIGINT, handler)
 *   signal.alarm(5)  # SIGALRM in 5 seconds
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// External Zig functions
extern int signal_signal(int sig, int handler);
extern int signal_pending_check(int sig);
extern uint32_t signal_get_count(int sig);
extern void signal_reset_count(int sig);
extern int signal_kill(int pid, int sig);
extern int signal_raise(int sig);
extern void signal_pause(void);
extern uint32_t signal_alarm(uint32_t seconds);
extern int signal_getpid(void);
extern int signal_getppid(void);
extern int signal_block(int sig);
extern int signal_unblock(int sig);
extern int signal_is_blocked(int sig);

// Signal constants
extern int signal_get_SIGINT(void);
extern int signal_get_SIGTERM(void);
extern int signal_get_SIGKILL(void);
extern int signal_get_SIGSTOP(void);
extern int signal_get_SIGCONT(void);
extern int signal_get_SIGCHLD(void);
extern int signal_get_SIGUSR1(void);
extern int signal_get_SIGUSR2(void);
extern int signal_get_SIGALRM(void);
extern int signal_get_SIGHUP(void);
extern int signal_get_SIGPIPE(void);
extern int signal_get_SIGQUIT(void);
extern int signal_get_SIGABRT(void);
extern int signal_get_SIGWINCH(void);

// Python callback storage
#define MAX_SIGNALS 32
static mp_obj_t python_handlers[MAX_SIGNALS];
static bool handlers_initialized = false;

static void init_handlers(void) {
    if (!handlers_initialized) {
        for (int i = 0; i < MAX_SIGNALS; i++) {
            python_handlers[i] = mp_const_none;
        }
        handlers_initialized = true;
    }
}

// ============================================================================
// signal.signal(sig, handler) -> old_handler
// ============================================================================

MPY_FUNC_2(signal, signal) {
    init_handlers();
    
    int sig = mpy_int(arg0);
    if (sig < 0 || sig >= MAX_SIGNALS) {
        mp_raise_ValueError(MP_ERROR_TEXT("invalid signal number"));
    }
    
    // Get old handler
    mp_obj_t old_handler = python_handlers[sig];
    
    // Determine handler type
    int handler_type;
    if (arg1 == mp_const_none) {
        handler_type = 0;  // SIG_DFL
        python_handlers[sig] = mp_const_none;
    } else if (mp_obj_is_int(arg1)) {
        int h = mpy_int(arg1);
        if (h == 0) {
            handler_type = 0;  // SIG_DFL
        } else if (h == 1) {
            handler_type = 1;  // SIG_IGN
        } else {
            handler_type = 2;  // Custom
        }
        python_handlers[sig] = arg1;
    } else if (mp_obj_is_callable(arg1)) {
        handler_type = 2;  // Custom Python handler
        python_handlers[sig] = arg1;
    } else {
        mp_raise_TypeError(MP_ERROR_TEXT("handler must be callable, int, or None"));
    }
    
    if (signal_signal(sig, handler_type) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    
    return old_handler;
}
MPY_FUNC_OBJ_2(signal, signal);

// ============================================================================
// signal.getsignal(sig) -> handler
// ============================================================================

MPY_FUNC_1(signal, getsignal) {
    init_handlers();
    
    int sig = mpy_int(arg0);
    if (sig < 0 || sig >= MAX_SIGNALS) {
        mp_raise_ValueError(MP_ERROR_TEXT("invalid signal number"));
    }
    
    return python_handlers[sig];
}
MPY_FUNC_OBJ_1(signal, getsignal);

// ============================================================================
// signal.check_pending(sig) -> bool
// ============================================================================

MPY_FUNC_1(signal, check_pending) {
    int sig = mpy_int(arg0);
    return mpy_bool(signal_pending_check(sig) == 1);
}
MPY_FUNC_OBJ_1(signal, check_pending);

// ============================================================================
// signal.dispatch(sig) -> bool (call handler if pending)
// ============================================================================

MPY_FUNC_1(signal, dispatch) {
    init_handlers();
    
    int sig = mpy_int(arg0);
    if (sig < 0 || sig >= MAX_SIGNALS) {
        return mpy_bool(false);
    }
    
    if (signal_pending_check(sig)) {
        mp_obj_t handler = python_handlers[sig];
        if (handler != mp_const_none && mp_obj_is_callable(handler)) {
            mp_call_function_1(handler, mpy_new_int(sig));
        }
        return mpy_bool(true);
    }
    
    return mpy_bool(false);
}
MPY_FUNC_OBJ_1(signal, dispatch);

// ============================================================================
// signal.dispatch_all() -> int (number of signals dispatched)
// ============================================================================

MPY_FUNC_0(signal, dispatch_all) {
    init_handlers();
    
    int count = 0;
    for (int sig = 0; sig < MAX_SIGNALS; sig++) {
        if (signal_pending_check(sig)) {
            mp_obj_t handler = python_handlers[sig];
            if (handler != mp_const_none && mp_obj_is_callable(handler)) {
                mp_call_function_1(handler, mpy_new_int(sig));
            }
            count++;
        }
    }
    
    return mpy_new_int(count);
}
MPY_FUNC_OBJ_0(signal, dispatch_all);

// ============================================================================
// signal.kill(pid, sig) -> None
// ============================================================================

MPY_FUNC_2(signal, kill) {
    int pid = mpy_int(arg0);
    int sig = mpy_int(arg1);
    
    if (signal_kill(pid, sig) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    
    return mpy_none();
}
MPY_FUNC_OBJ_2(signal, kill);

// ============================================================================
// signal.raise_signal(sig) -> None
// ============================================================================

MPY_FUNC_1(signal, raise_signal) {
    int sig = mpy_int(arg0);
    
    if (signal_raise(sig) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    
    return mpy_none();
}
MPY_FUNC_OBJ_1(signal, raise_signal);

// ============================================================================
// signal.pause() -> None
// ============================================================================

MPY_FUNC_0(signal, pause) {
    signal_pause();
    return mpy_none();
}
MPY_FUNC_OBJ_0(signal, pause);

// ============================================================================
// signal.alarm(seconds) -> int (previous alarm)
// ============================================================================

MPY_FUNC_1(signal, alarm) {
    uint32_t seconds = mpy_int(arg0);
    uint32_t prev = signal_alarm(seconds);
    return mpy_new_int(prev);
}
MPY_FUNC_OBJ_1(signal, alarm);

// ============================================================================
// signal.getpid() -> int
// ============================================================================

MPY_FUNC_0(signal, getpid) {
    return mpy_new_int(signal_getpid());
}
MPY_FUNC_OBJ_0(signal, getpid);

// ============================================================================
// signal.getppid() -> int
// ============================================================================

MPY_FUNC_0(signal, getppid) {
    return mpy_new_int(signal_getppid());
}
MPY_FUNC_OBJ_0(signal, getppid);

// ============================================================================
// signal.block(sig) -> None
// ============================================================================

MPY_FUNC_1(signal, block) {
    int sig = mpy_int(arg0);
    if (signal_block(sig) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_1(signal, block);

// ============================================================================
// signal.unblock(sig) -> None
// ============================================================================

MPY_FUNC_1(signal, unblock) {
    int sig = mpy_int(arg0);
    if (signal_unblock(sig) < 0) {
        mp_raise_OSError(MP_EIO);
    }
    return mpy_none();
}
MPY_FUNC_OBJ_1(signal, unblock);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(signal)
    // Functions
    MPY_MODULE_FUNC(signal, signal)
    MPY_MODULE_FUNC(signal, getsignal)
    MPY_MODULE_FUNC(signal, check_pending)
    MPY_MODULE_FUNC(signal, dispatch)
    MPY_MODULE_FUNC(signal, dispatch_all)
    MPY_MODULE_FUNC(signal, kill)
    MPY_MODULE_FUNC(signal, raise_signal)
    MPY_MODULE_FUNC(signal, pause)
    MPY_MODULE_FUNC(signal, alarm)
    MPY_MODULE_FUNC(signal, getpid)
    MPY_MODULE_FUNC(signal, getppid)
    MPY_MODULE_FUNC(signal, block)
    MPY_MODULE_FUNC(signal, unblock)
    
    // Constants - handler types
    { MP_ROM_QSTR(MP_QSTR_SIG_DFL), MP_ROM_INT(0) },
    { MP_ROM_QSTR(MP_QSTR_SIG_IGN), MP_ROM_INT(1) },
    
    // Signal numbers (initialized at runtime would be better, but use common values)
    { MP_ROM_QSTR(MP_QSTR_SIGINT), MP_ROM_INT(2) },
    { MP_ROM_QSTR(MP_QSTR_SIGTERM), MP_ROM_INT(15) },
    { MP_ROM_QSTR(MP_QSTR_SIGKILL), MP_ROM_INT(9) },
    { MP_ROM_QSTR(MP_QSTR_SIGSTOP), MP_ROM_INT(17) },
    { MP_ROM_QSTR(MP_QSTR_SIGCONT), MP_ROM_INT(19) },
    { MP_ROM_QSTR(MP_QSTR_SIGCHLD), MP_ROM_INT(20) },
    { MP_ROM_QSTR(MP_QSTR_SIGUSR1), MP_ROM_INT(30) },
    { MP_ROM_QSTR(MP_QSTR_SIGUSR2), MP_ROM_INT(31) },
    { MP_ROM_QSTR(MP_QSTR_SIGALRM), MP_ROM_INT(14) },
    { MP_ROM_QSTR(MP_QSTR_SIGHUP), MP_ROM_INT(1) },
    { MP_ROM_QSTR(MP_QSTR_SIGPIPE), MP_ROM_INT(13) },
    { MP_ROM_QSTR(MP_QSTR_SIGQUIT), MP_ROM_INT(3) },
    { MP_ROM_QSTR(MP_QSTR_SIGABRT), MP_ROM_INT(6) },
    { MP_ROM_QSTR(MP_QSTR_SIGWINCH), MP_ROM_INT(28) },
MPY_MODULE_END(signal)
