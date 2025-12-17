/*
 * modsubprocess - Native subprocess module for microcharm
 * 
 * This module bridges Zig's subprocess implementation to MicroPython.
 * Compatible with Python's subprocess module API.
 * 
 * Usage in Python:
 *   import subprocess
 *   result = subprocess.run(["ls", "-la"], capture_output=True)
 *   print(result.stdout)
 *   print(result.returncode)
 *   
 *   output = subprocess.check_output(["echo", "hello"])
 *   subprocess.call(["ls"])
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// Result struct from Zig
typedef struct {
    int32_t returncode;
    size_t stdout_len;
    size_t stderr_len;
} RunResult;

// External Zig functions
extern RunResult subprocess_run(const char *cmd, size_t cmd_len, int capture_output);
extern RunResult subprocess_shell(const char *cmd, size_t cmd_len, int capture_output);
extern size_t subprocess_get_stdout(char *buf, size_t buf_len);
extern size_t subprocess_get_stderr(char *buf, size_t buf_len);
extern int subprocess_call(const char *cmd, size_t cmd_len);
extern int subprocess_check_call(const char *cmd, size_t cmd_len);
extern int subprocess_check_output(const char *cmd, size_t cmd_len);
extern size_t subprocess_get_output(char *buf, size_t buf_len);
extern int subprocess_getpid(void);
extern int subprocess_getppid(void);

// Helper: convert list of strings to space-separated command
static mp_obj_t args_to_cmd(mp_obj_t args_obj, char *buf, size_t buf_len) {
    size_t pos = 0;
    
    if (mp_obj_is_str(args_obj)) {
        // Already a string
        size_t len;
        const char *str = mpy_str_len(args_obj, &len);
        if (len < buf_len) {
            memcpy(buf, str, len);
            buf[len] = '\0';
            return mp_const_true;
        }
        return mp_const_false;
    }
    
    // Assume it's a list/tuple
    size_t n;
    mp_obj_t *items;
    mp_obj_get_array(args_obj, &n, &items);
    
    for (size_t i = 0; i < n; i++) {
        if (i > 0 && pos < buf_len - 1) {
            buf[pos++] = ' ';
        }
        
        size_t arg_len;
        const char *arg = mpy_str_len(items[i], &arg_len);
        
        if (pos + arg_len >= buf_len - 1) {
            return mp_const_false;
        }
        
        memcpy(buf + pos, arg, arg_len);
        pos += arg_len;
    }
    
    buf[pos] = '\0';
    return mp_const_true;
}

// ============================================================================
// subprocess.run(args, capture_output=False, shell=False) -> CompletedProcess
// ============================================================================

MPY_FUNC_VAR(subprocess, run, 1, 3) {
    char cmd_buf[4096];
    
    // Parse arguments
    mp_obj_t args_obj = args[0];
    int capture_output = 0;
    int shell = 0;
    
    if (n_args >= 2 && args[1] != mp_const_none) {
        capture_output = mp_obj_is_true(args[1]) ? 1 : 0;
    }
    if (n_args >= 3 && args[2] != mp_const_none) {
        shell = mp_obj_is_true(args[2]) ? 1 : 0;
    }
    
    // Convert args to command string
    if (args_to_cmd(args_obj, cmd_buf, sizeof(cmd_buf)) == mp_const_false) {
        mp_raise_ValueError(MP_ERROR_TEXT("command too long"));
    }
    
    size_t cmd_len = strlen(cmd_buf);
    
    // Run the command
    RunResult result;
    if (shell) {
        result = subprocess_shell(cmd_buf, cmd_len, capture_output);
    } else {
        result = subprocess_run(cmd_buf, cmd_len, capture_output);
    }
    
    // Build result dict (CompletedProcess-like)
    mp_obj_t dict = mpy_new_dict();
    mpy_dict_store_str(dict, "returncode", mpy_new_int(result.returncode));
    
    if (capture_output) {
        // Get stdout
        char *stdout_buf = mpy_alloc(result.stdout_len + 1);
        subprocess_get_stdout(stdout_buf, result.stdout_len);
        stdout_buf[result.stdout_len] = '\0';
        mpy_dict_store_str(dict, "stdout", mp_obj_new_bytes((byte *)stdout_buf, result.stdout_len));
        mpy_free(stdout_buf, result.stdout_len + 1);
        
        // Get stderr
        char *stderr_buf = mpy_alloc(result.stderr_len + 1);
        subprocess_get_stderr(stderr_buf, result.stderr_len);
        stderr_buf[result.stderr_len] = '\0';
        mpy_dict_store_str(dict, "stderr", mp_obj_new_bytes((byte *)stderr_buf, result.stderr_len));
        mpy_free(stderr_buf, result.stderr_len + 1);
    } else {
        mpy_dict_store_str(dict, "stdout", mp_const_none);
        mpy_dict_store_str(dict, "stderr", mp_const_none);
    }
    
    return dict;
}
MPY_FUNC_OBJ_VAR(subprocess, run, 1, 3);

// ============================================================================
// subprocess.call(args) -> int
// ============================================================================

MPY_FUNC_1(subprocess, call) {
    char cmd_buf[4096];
    
    if (args_to_cmd(arg0, cmd_buf, sizeof(cmd_buf)) == mp_const_false) {
        mp_raise_ValueError(MP_ERROR_TEXT("command too long"));
    }
    
    int ret = subprocess_call(cmd_buf, strlen(cmd_buf));
    return mpy_new_int(ret);
}
MPY_FUNC_OBJ_1(subprocess, call);

// ============================================================================
// subprocess.check_call(args) -> int (raises on non-zero)
// ============================================================================

MPY_FUNC_1(subprocess, check_call) {
    char cmd_buf[4096];
    
    if (args_to_cmd(arg0, cmd_buf, sizeof(cmd_buf)) == mp_const_false) {
        mp_raise_ValueError(MP_ERROR_TEXT("command too long"));
    }
    
    int ret = subprocess_check_call(cmd_buf, strlen(cmd_buf));
    if (ret != 0) {
        mp_raise_OSError(ret);
    }
    return mpy_new_int(0);
}
MPY_FUNC_OBJ_1(subprocess, check_call);

// ============================================================================
// subprocess.check_output(args, shell=False) -> bytes
// ============================================================================

MPY_FUNC_VAR(subprocess, check_output, 1, 2) {
    char cmd_buf[4096];
    int shell = 0;
    
    if (n_args >= 2 && args[1] != mp_const_none) {
        shell = mp_obj_is_true(args[1]) ? 1 : 0;
    }
    
    if (args_to_cmd(args[0], cmd_buf, sizeof(cmd_buf)) == mp_const_false) {
        mp_raise_ValueError(MP_ERROR_TEXT("command too long"));
    }
    
    size_t cmd_len = strlen(cmd_buf);
    
    // Run with capture
    RunResult result;
    if (shell) {
        result = subprocess_shell(cmd_buf, cmd_len, 1);
    } else {
        result = subprocess_run(cmd_buf, cmd_len, 1);
    }
    
    if (result.returncode != 0) {
        mp_raise_OSError(result.returncode);
    }
    
    // Get output
    char *output_buf = mpy_alloc(result.stdout_len + 1);
    subprocess_get_stdout(output_buf, result.stdout_len);
    mp_obj_t ret = mp_obj_new_bytes((byte *)output_buf, result.stdout_len);
    mpy_free(output_buf, result.stdout_len + 1);
    
    return ret;
}
MPY_FUNC_OBJ_VAR(subprocess, check_output, 1, 2);

// ============================================================================
// subprocess.getoutput(cmd) -> str (shell=True, returns stdout as string)
// ============================================================================

MPY_FUNC_1(subprocess, getoutput) {
    size_t cmd_len;
    const char *cmd = mpy_str_len(arg0, &cmd_len);
    
    RunResult result = subprocess_shell(cmd, cmd_len, 1);
    
    // Get output as string (ignore return code like Python)
    char *output_buf = mpy_alloc(result.stdout_len + 1);
    subprocess_get_stdout(output_buf, result.stdout_len);
    output_buf[result.stdout_len] = '\0';
    
    // Strip trailing newline
    size_t len = result.stdout_len;
    while (len > 0 && (output_buf[len-1] == '\n' || output_buf[len-1] == '\r')) {
        len--;
    }
    
    mp_obj_t ret = mpy_new_str_len(output_buf, len);
    mpy_free(output_buf, result.stdout_len + 1);
    
    return ret;
}
MPY_FUNC_OBJ_1(subprocess, getoutput);

// ============================================================================
// subprocess.getstatusoutput(cmd) -> (status, output)
// ============================================================================

MPY_FUNC_1(subprocess, getstatusoutput) {
    size_t cmd_len;
    const char *cmd = mpy_str_len(arg0, &cmd_len);
    
    RunResult result = subprocess_shell(cmd, cmd_len, 1);
    
    // Get output as string
    char *output_buf = mpy_alloc(result.stdout_len + 1);
    subprocess_get_stdout(output_buf, result.stdout_len);
    output_buf[result.stdout_len] = '\0';
    
    // Strip trailing newline
    size_t len = result.stdout_len;
    while (len > 0 && (output_buf[len-1] == '\n' || output_buf[len-1] == '\r')) {
        len--;
    }
    
    mp_obj_t output = mpy_new_str_len(output_buf, len);
    mpy_free(output_buf, result.stdout_len + 1);
    
    return mpy_tuple2(mpy_new_int(result.returncode), output);
}
MPY_FUNC_OBJ_1(subprocess, getstatusoutput);

// ============================================================================
// subprocess.getpid() -> int
// ============================================================================

MPY_FUNC_0(subprocess, getpid) {
    return mpy_new_int(subprocess_getpid());
}
MPY_FUNC_OBJ_0(subprocess, getpid);

// ============================================================================
// subprocess.getppid() -> int
// ============================================================================

MPY_FUNC_0(subprocess, getppid) {
    return mpy_new_int(subprocess_getppid());
}
MPY_FUNC_OBJ_0(subprocess, getppid);

// ============================================================================
// Constants
// ============================================================================

// PIPE constant (just a marker value)
#define SUBPROCESS_PIPE (-1)
#define SUBPROCESS_STDOUT (-2)
#define SUBPROCESS_DEVNULL (-3)

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(subprocess)
    MPY_MODULE_FUNC(subprocess, run)
    MPY_MODULE_FUNC(subprocess, call)
    MPY_MODULE_FUNC(subprocess, check_call)
    MPY_MODULE_FUNC(subprocess, check_output)
    MPY_MODULE_FUNC(subprocess, getoutput)
    MPY_MODULE_FUNC(subprocess, getstatusoutput)
    MPY_MODULE_FUNC(subprocess, getpid)
    MPY_MODULE_FUNC(subprocess, getppid)
    // Constants
    { MP_ROM_QSTR(MP_QSTR_PIPE), MP_ROM_INT(SUBPROCESS_PIPE) },
    { MP_ROM_QSTR(MP_QSTR_STDOUT), MP_ROM_INT(SUBPROCESS_STDOUT) },
    { MP_ROM_QSTR(MP_QSTR_DEVNULL), MP_ROM_INT(SUBPROCESS_DEVNULL) },
MPY_MODULE_END(subprocess)
