/*
 * modinput.c - Native interactive input module for ucharm
 * 
 * This module provides interactive terminal input components:
 * - select: Single selection from a list of choices
 * - multiselect: Multiple selection from a list of choices
 * - confirm: Yes/no confirmation prompt
 * - prompt: Text input with optional default
 * - password: Hidden text input
 * 
 * Usage in Python:
 *   import input
 *   choice = input.select("Choose:", ["a", "b", "c"])
 *   confirmed = input.confirm("Continue?", True)
 *   name = input.prompt("Name:", "default")
 *   secret = input.password("Password:")
 *
 * Test Mode:
 *   For automated testing, provide keystrokes via environment variable:
 *   MCHARM_TEST_KEYS="down,down,enter" ./my_app
 *
 *   Key names: up, down, enter, space, escape, backspace, y, n
 *   Single characters are sent as-is.
 */

#include "../bridge/mpy_bridge.h"

#include <sys/types.h>
#include <unistd.h>
#include <termios.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>

// ============================================================================
// Zig Function Declarations
// ============================================================================

ZIG_EXTERN size_t input_strlen(const char *str);
ZIG_EXTERN bool input_streq(const char *a, const char *b);
ZIG_EXTERN bool input_starts_with(const char *str, const char *prefix);
ZIG_EXTERN int input_clamp(int value, int min_val, int max_val);
ZIG_EXTERN int input_wrap_index(int value, int count);

// ============================================================================
// Terminal State
// ============================================================================

static struct termios input_orig_termios;
static int input_raw_mode_enabled = 0;
static int input_tty_fd = -1;  // File descriptor for /dev/tty

// ============================================================================
// Test Mode Support
// ============================================================================

// Test input can come from:
// 1. Environment variable: MCHARM_TEST_KEYS="down,down,enter"
// 2. File descriptor 3: echo -e "down\nenter" | ./app 3<&0

static char *test_keys_buf = NULL;      // Buffer for test keys
static char *test_keys_ptr = NULL;      // Current position in buffer
static int test_mode_initialized = 0;
static int test_mode_source = 0;        // 0=none, 1=env, 2=fd3

#define TEST_FD 3

static void init_test_mode(void) {
    if (test_mode_initialized) return;
    test_mode_initialized = 1;
    
    // Check environment variable first
    const char *env = getenv("MCHARM_TEST_KEYS");
    if (env && *env) {
        test_keys_buf = strdup(env);
        test_keys_ptr = test_keys_buf;
        test_mode_source = 1;
        return;
    }
    
    // Check if fd 3 is readable - use non-blocking check
    // First verify fd 3 is valid and a regular file or pipe
    int flags = fcntl(TEST_FD, F_GETFL);
    if (flags == -1) {
        // fd 3 doesn't exist, that's fine
        return;
    }
    
    // Set non-blocking temporarily to avoid hanging
    fcntl(TEST_FD, F_SETFL, flags | O_NONBLOCK);
    
    char buf[4096];
    ssize_t n = read(TEST_FD, buf, sizeof(buf) - 1);
    
    // Restore original flags
    fcntl(TEST_FD, F_SETFL, flags);
    
    if (n > 0) {
        buf[n] = '\0';
        // Convert newlines to commas for consistent parsing
        for (ssize_t i = 0; i < n; i++) {
            if (buf[i] == '\n') buf[i] = ',';
        }
        // Remove trailing comma if present
        if (n > 0 && buf[n-1] == ',') buf[n-1] = '\0';
        test_keys_buf = strdup(buf);
        test_keys_ptr = test_keys_buf;
        test_mode_source = 2;
    }
}

static int is_test_mode(void) {
    init_test_mode();
    return test_keys_buf != NULL;
}

// Map a key name to internal key code
static int map_key_name(const char *key_name, size_t len) {
    if (len == 0) return 0;
    
    // Named keys
    if (len == 2 && strncmp(key_name, "up", 2) == 0) return 'u';
    if (len == 4 && strncmp(key_name, "down", 4) == 0) return 'd';
    if (len == 5 && strncmp(key_name, "enter", 5) == 0) return 'e';
    if (len == 5 && strncmp(key_name, "space", 5) == 0) return 's';
    if (len == 6 && strncmp(key_name, "escape", 6) == 0) return 'q';
    if (len == 9 && strncmp(key_name, "backspace", 9) == 0) return 'b';
    
    // Vim-style navigation
    if (len == 1 && key_name[0] == 'k') return 'u';
    if (len == 1 && key_name[0] == 'j') return 'd';
    
    // Single characters
    if (len == 1) {
        char c = key_name[0];
        if (c == 'y' || c == 'Y' || c == 'n' || c == 'N') return c;
        return c;
    }
    
    return 0;
}

// Read next test key, returns key code or 0 if no more keys
static int read_test_key(void) {
    init_test_mode();
    
    if (!test_keys_ptr || !*test_keys_ptr) return 0;
    
    // Skip leading whitespace and commas
    while (*test_keys_ptr == ',' || *test_keys_ptr == ' ' || *test_keys_ptr == '\t') {
        test_keys_ptr++;
    }
    if (!*test_keys_ptr) return 0;
    
    // Find end of current key (comma or end of string)
    char *end = test_keys_ptr;
    while (*end && *end != ',') end++;
    size_t len = (size_t)(end - test_keys_ptr);
    
    // Trim trailing whitespace
    while (len > 0 && (test_keys_ptr[len-1] == ' ' || test_keys_ptr[len-1] == '\t')) {
        len--;
    }
    
    int key = map_key_name(test_keys_ptr, len);
    
    // Advance pointer
    test_keys_ptr = *end ? end + 1 : end;
    
    return key;
}

// ============================================================================
// ANSI Escape Sequences and Symbols
// ============================================================================

#define SYM_SELECT       "\xe2\x9d\xaf "   // ❯
#define SYM_CHECKBOX_ON  "\xe2\x97\x89"    // ◉
#define SYM_CHECKBOX_OFF "\xe2\x97\x8b"    // ○

#define ANSI_HIDE_CURSOR "\x1b[?25l"
#define ANSI_SHOW_CURSOR "\x1b[?25h"
#define ANSI_CLEAR_LINE  "\x1b[2K\r"
#define ANSI_CURSOR_UP   "\x1b[%dA"
#define ANSI_CYAN        "\x1b[36m"
#define ANSI_BOLD        "\x1b[1m"
#define ANSI_RESET       "\x1b[0m"
#define ANSI_DIM         "\x1b[2m"

// ============================================================================
// Terminal Helpers
// ============================================================================

// Get file descriptor for terminal input
// Uses /dev/tty to work even when stdin is redirected (e.g., via just, make)
static int get_tty_fd(void) {
    if (input_tty_fd < 0) {
        // Open with O_RDWR | O_NOCTTY for terminal control
        input_tty_fd = open("/dev/tty", O_RDWR | O_NOCTTY);
        if (input_tty_fd < 0) {
            // Fallback to stdin if /dev/tty not available
            input_tty_fd = STDIN_FILENO;
        }
    }
    return input_tty_fd;
}

static void enable_raw_mode(void) {
    if (!input_raw_mode_enabled) {
        int stdin_fd = STDIN_FILENO;
        int tty_fd = get_tty_fd();
        
        // Check if stdin is a tty
        if (isatty(stdin_fd)) {
            // Normal case: stdin is a tty, use it for termios
            tcgetattr(stdin_fd, &input_orig_termios);
            struct termios raw = input_orig_termios;
            raw.c_lflag &= ~(ECHO | ICANON | ISIG | IEXTEN);
            raw.c_iflag &= ~(IXON | ICRNL | BRKINT | INPCK | ISTRIP);
            raw.c_oflag &= ~(OPOST);
            raw.c_cflag |= (CS8);
            raw.c_cc[VMIN] = 0;
            raw.c_cc[VTIME] = 1;
            tcsetattr(stdin_fd, TCSANOW, &raw);
        } else {
            // When stdin is not a tty (e.g., under just, make), we are a background process.
            // We need to become the foreground process group to read from the terminal.
            // First, ignore SIGTTOU and SIGTTIN to prevent being stopped.
            struct sigaction sa_new;
            sa_new.sa_handler = SIG_IGN;
            sigemptyset(&sa_new.sa_mask);
            sa_new.sa_flags = 0;
            sigaction(SIGTTOU, &sa_new, NULL);
            sigaction(SIGTTIN, &sa_new, NULL);
            
            // Try to become the foreground process group
            pid_t our_pgrp = getpgrp();
            pid_t fg_pgrp = tcgetpgrp(tty_fd);
            if (our_pgrp != fg_pgrp) {
                tcsetpgrp(tty_fd, our_pgrp);
            }
            
            // Use /dev/tty for both termios and reading
            tcgetattr(tty_fd, &input_orig_termios);
            struct termios raw = input_orig_termios;
            raw.c_lflag &= ~(ECHO | ICANON | ISIG | IEXTEN);
            raw.c_iflag &= ~(IXON | ICRNL | BRKINT | INPCK | ISTRIP);
            raw.c_oflag &= ~(OPOST);
            raw.c_cflag |= (CS8);
            raw.c_cc[VMIN] = 0;
            raw.c_cc[VTIME] = 1;
            tcsetattr(tty_fd, TCSANOW, &raw);
        }
        input_raw_mode_enabled = 1;
    }
}

static void disable_raw_mode(void) {
    if (input_raw_mode_enabled) {
        int fd = get_tty_fd();
        tcsetattr(fd, TCSAFLUSH, &input_orig_termios);
        input_raw_mode_enabled = 0;
    }
}

static void hide_cursor(void) {
    write(STDOUT_FILENO, ANSI_HIDE_CURSOR, strlen(ANSI_HIDE_CURSOR));
}

static void show_cursor(void) {
    write(STDOUT_FILENO, ANSI_SHOW_CURSOR, strlen(ANSI_SHOW_CURSOR));
}

static void clear_line(void) {
    write(STDOUT_FILENO, ANSI_CLEAR_LINE, strlen(ANSI_CLEAR_LINE));
}

static void cursor_up(int n) {
    char buf[16];
    int len = snprintf(buf, sizeof(buf), ANSI_CURSOR_UP, n);
    write(STDOUT_FILENO, buf, len);
}

static void write_str(const char *str) {
    write(STDOUT_FILENO, str, strlen(str));
}

static void write_newline(void) {
    write(STDOUT_FILENO, "\n", 1);
}

// Read a key and return a key code
static int read_key(void) {
    // Check test mode first
    if (is_test_mode()) {
        return read_test_key();
    }
    
    char buf[8];
    int fd = get_tty_fd();
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    
    if (n <= 0) return 0;
    
    buf[n] = '\0';
    
    // Handle escape sequences (arrow keys, etc.)
    if (buf[0] == '\x1b') {
        // If we only got the escape byte, try to read more
        if (n == 1) {
            // Wait a bit for the rest of the escape sequence
            ssize_t n2 = read(fd, buf + 1, sizeof(buf) - 2);
            if (n2 > 0) {
                n += n2;
                buf[n] = '\0';
            } else {
                // Just escape key pressed alone
                return 'q';
            }
        }
        
        // Now check for escape sequences
        if (n >= 3 && buf[1] == '[') {
            switch (buf[2]) {
                case 'A': return 'u';  // up
                case 'B': return 'd';  // down
                case 'C': return 0;    // right (ignore)
                case 'D': return 0;    // left (ignore)
            }
        }
        
        // Unknown escape sequence, ignore
        return 0;
    }
    
    // Handle single characters
    if (n == 1) {
        switch (buf[0]) {
            case '\r':
            case '\n': return 'e';  // enter
            case ' ':  return 's';  // space
            case 'j':  return 'd';  // vim down
            case 'k':  return 'u';  // vim up
            case 'q': return 'q';   // quit
            case '\x03': return 'q';  // ctrl-c
            case 'y': return 'y';
            case 'Y': return 'Y';
            case 'n': return 'n';
            case 'N': return 'N';
            case '\x7f':
            case '\b': return 'b';  // backspace
        }
        return buf[0];
    }
    
    return 0;
}

// ============================================================================
// input.select(prompt, choices, default=0) -> str or None
// ============================================================================

MPY_FUNC_VAR(input, select, 2, 3) {
    const char *prompt_str = mpy_str(args[0]);
    mp_obj_t choices_obj = args[1];
    int default_idx = (n_args > 2) ? mpy_int(args[2]) : 0;
    
    size_t choices_len;
    mp_obj_t *choices_items;
    mp_obj_list_get(choices_obj, &choices_len, &choices_items);
    
    if (choices_len == 0) {
        return mpy_none();
    }
    
    int selected = input_clamp(default_idx, 0, (int)choices_len - 1);
    
    write_str(ANSI_CYAN ANSI_BOLD "? " ANSI_RESET);
    write_str(prompt_str);
    write_newline();
    
    hide_cursor();
    
    for (size_t i = 0; i < choices_len; i++) {
        const char *choice = mpy_str(choices_items[i]);
        if ((int)i == selected) {
            write_str(ANSI_CYAN "  " SYM_SELECT);
            write_str(choice);
            write_str(ANSI_RESET);
        } else {
            write_str("    ");
            write_str(choice);
        }
        write_newline();
    }
    
    enable_raw_mode();
    
    int result_idx = -1;
    
    while (1) {
        int key = read_key();
        
        // Skip if no key pressed (timeout)
        if (key == 0) {
            continue;
        }
        
        if (key == 'd') {
            selected = input_wrap_index(selected + 1, (int)choices_len);
        } else if (key == 'u') {
            selected = input_wrap_index(selected - 1, (int)choices_len);
        } else if (key == 'e' || key == 's') {
            result_idx = selected;
            break;
        } else if (key == 'q') {
            break;
        } else {
            // Unknown key, don't redraw
            continue;
        }
        
        // Only redraw when selection changed
        cursor_up((int)choices_len);
        for (size_t i = 0; i < choices_len; i++) {
            clear_line();
            const char *choice = mpy_str(choices_items[i]);
            if ((int)i == selected) {
                write_str(ANSI_CYAN "  " SYM_SELECT);
                write_str(choice);
                write_str(ANSI_RESET);
            } else {
                write_str("    ");
                write_str(choice);
            }
            write_newline();
        }
    }
    
    disable_raw_mode();
    show_cursor();
    
    if (result_idx >= 0 && (size_t)result_idx < choices_len) {
        return choices_items[result_idx];
    }
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(input, select, 2, 3);

// ============================================================================
// input.multiselect(prompt, choices, defaults=None) -> list
// ============================================================================

MPY_FUNC_VAR(input, multiselect, 2, 3) {
    const char *prompt_str = mpy_str(args[0]);
    mp_obj_t choices_obj = args[1];
    mp_obj_t defaults_obj = (n_args > 2) ? args[2] : mpy_none();
    
    size_t choices_len;
    mp_obj_t *choices_items;
    mp_obj_list_get(choices_obj, &choices_len, &choices_items);
    
    if (choices_len == 0) {
        return mpy_new_list();
    }
    
    int selected_state[256];
    memset(selected_state, 0, sizeof(selected_state));
    
    if (defaults_obj != mpy_none() && mp_obj_is_type(defaults_obj, &mp_type_list)) {
        size_t defaults_len;
        mp_obj_t *defaults_items;
        mp_obj_list_get(defaults_obj, &defaults_len, &defaults_items);
        
        for (size_t d = 0; d < defaults_len; d++) {
            const char *default_str = mpy_str(defaults_items[d]);
            for (size_t c = 0; c < choices_len && c < 256; c++) {
                const char *choice_str = mpy_str(choices_items[c]);
                if (input_streq(default_str, choice_str)) {
                    selected_state[c] = 1;
                    break;
                }
            }
        }
    }
    
    int cursor = 0;
    
    write_str(ANSI_CYAN ANSI_BOLD "? " ANSI_RESET);
    write_str(prompt_str);
    write_str(ANSI_DIM " (space to toggle, enter to confirm)" ANSI_RESET);
    write_newline();
    
    hide_cursor();
    
    for (size_t i = 0; i < choices_len && i < 256; i++) {
        const char *choice = mpy_str(choices_items[i]);
        if ((int)i == cursor) {
            write_str(ANSI_CYAN "  ");
        } else {
            write_str("  ");
        }
        write_str(selected_state[i] ? SYM_CHECKBOX_ON " " : SYM_CHECKBOX_OFF " ");
        write_str(choice);
        if ((int)i == cursor) {
            write_str(ANSI_RESET);
        }
        write_newline();
    }
    
    enable_raw_mode();
    
    int confirmed = 0;
    
    while (1) {
        int key = read_key();
        
        // Skip if no key pressed (timeout)
        if (key == 0) {
            continue;
        }
        
        if (key == 'd') {
            cursor = input_wrap_index(cursor + 1, (int)choices_len);
        } else if (key == 'u') {
            cursor = input_wrap_index(cursor - 1, (int)choices_len);
        } else if (key == 's') {
            if ((size_t)cursor < 256) {
                selected_state[cursor] = !selected_state[cursor];
            }
        } else if (key == 'e') {
            confirmed = 1;
            break;
        } else if (key == 'q') {
            break;
        } else {
            // Unknown key, don't redraw
            continue;
        }
        
        // Only redraw when selection changed
        cursor_up((int)(choices_len < 256 ? choices_len : 256));
        for (size_t i = 0; i < choices_len && i < 256; i++) {
            clear_line();
            const char *choice = mpy_str(choices_items[i]);
            if ((int)i == cursor) {
                write_str(ANSI_CYAN "  ");
            } else {
                write_str("  ");
            }
            write_str(selected_state[i] ? SYM_CHECKBOX_ON " " : SYM_CHECKBOX_OFF " ");
            write_str(choice);
            if ((int)i == cursor) {
                write_str(ANSI_RESET);
            }
            write_newline();
        }
    }
    
    disable_raw_mode();
    show_cursor();
    
    mp_obj_t result = mpy_new_list();
    if (confirmed) {
        for (size_t i = 0; i < choices_len && i < 256; i++) {
            if (selected_state[i]) {
                mpy_list_append(result, choices_items[i]);
            }
        }
    }
    
    return result;
}
MPY_FUNC_OBJ_VAR(input, multiselect, 2, 3);

// ============================================================================
// input.confirm(prompt, default=True) -> bool
// ============================================================================

static mp_obj_t input_confirm_func(size_t n_args, const mp_obj_t *pos_args, mp_map_t *kw_args) {
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_prompt, MP_ARG_REQUIRED | MP_ARG_OBJ, {.u_obj = mp_const_none} },
        { MP_QSTR_default, MP_ARG_BOOL, {.u_bool = true} },
    };
    
    mp_arg_val_t args[2];
    mp_arg_parse_all(n_args, pos_args, kw_args, 2, allowed_args, args);
    
    const char *prompt_str = mpy_str(args[0].u_obj);
    int default_val = args[1].u_bool;
    
    write_str(ANSI_CYAN ANSI_BOLD "? " ANSI_RESET);
    write_str(prompt_str);
    write_str(" ");
    write_str(ANSI_DIM);
    write_str(default_val ? "(Y/n)" : "(y/N)");
    write_str(ANSI_RESET " ");
    fflush(stdout);
    
    enable_raw_mode();
    
    int result = default_val;
    
    while (1) {
        int key = read_key();
        
        // Skip if no key pressed (timeout)
        if (key == 0) {
            continue;
        }
        
        if (key == 'y' || key == 'Y') {
            result = 1;
            break;
        } else if (key == 'n' || key == 'N') {
            result = 0;
            break;
        } else if (key == 'e') {
            result = default_val;
            break;
        } else if (key == 'q') {
            result = 0;
            break;
        }
    }
    
    disable_raw_mode();
    
    write_str(ANSI_CYAN);
    write_str(result ? "Yes" : "No");
    write_str(ANSI_RESET);
    write_newline();
    
    return mpy_bool(result);
}
MP_DEFINE_CONST_FUN_OBJ_KW(input_confirm_obj, 1, input_confirm_func);

// ============================================================================
// input.prompt(message, default=None) -> str
// ============================================================================

MPY_FUNC_VAR(input, prompt, 1, 2) {
    const char *message_str = mpy_str(args[0]);
    const char *default_str = (n_args > 1 && args[1] != mpy_none()) ? mpy_str(args[1]) : NULL;
    
    write_str(ANSI_CYAN ANSI_BOLD "? " ANSI_RESET);
    write_str(message_str);
    if (default_str) {
        write_str(ANSI_DIM " (");
        write_str(default_str);
        write_str(")" ANSI_RESET);
    }
    write_str(" ");
    fflush(stdout);
    
    static char input_buf[1024];
    size_t input_len = 0;
    
    enable_raw_mode();
    
    while (input_len < sizeof(input_buf) - 1) {
        char c;
        ssize_t n = read(STDIN_FILENO, &c, 1);
        if (n <= 0) continue;
        
        if (c == '\r' || c == '\n') {
            break;
        } else if (c == '\x1b' || c == '\x03') {
            disable_raw_mode();
            write_newline();
            return default_str ? mpy_new_str(default_str) : mpy_new_str("");
        } else if (c == '\x7f' || c == '\b') {
            if (input_len > 0) {
                input_len--;
                write_str("\b \b");
            }
        } else if (c >= 32 && c < 127) {
            input_buf[input_len++] = c;
            write(STDOUT_FILENO, &c, 1);
        }
    }
    
    disable_raw_mode();
    write_newline();
    
    input_buf[input_len] = '\0';
    
    if (input_len == 0 && default_str) {
        return mpy_new_str(default_str);
    }
    
    return mpy_new_str(input_buf);
}
MPY_FUNC_OBJ_VAR(input, prompt, 1, 2);

// ============================================================================
// input.password(message) -> str
// ============================================================================

MPY_FUNC_1(input, password) {
    const char *message_str = mpy_str(arg0);
    
    write_str(ANSI_CYAN ANSI_BOLD "? " ANSI_RESET);
    write_str(message_str);
    write_str(" ");
    fflush(stdout);
    
    static char input_buf[1024];
    size_t input_len = 0;
    
    enable_raw_mode();
    
    while (input_len < sizeof(input_buf) - 1) {
        char c;
        ssize_t n = read(STDIN_FILENO, &c, 1);
        if (n <= 0) continue;
        
        if (c == '\r' || c == '\n') {
            break;
        } else if (c == '\x1b' || c == '\x03') {
            disable_raw_mode();
            write_newline();
            return mpy_new_str("");
        } else if (c == '\x7f' || c == '\b') {
            if (input_len > 0) {
                input_len--;
            }
        } else if (c >= 32 && c < 127) {
            input_buf[input_len++] = c;
        }
    }
    
    disable_raw_mode();
    write_newline();
    
    input_buf[input_len] = '\0';
    
    return mpy_new_str(input_buf);
}
MPY_FUNC_OBJ_1(input, password);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(input)
    MPY_MODULE_FUNC(input, select)
    MPY_MODULE_FUNC(input, multiselect)
    { MP_ROM_QSTR(MP_QSTR_confirm), MP_ROM_PTR(&input_confirm_obj) },
    MPY_MODULE_FUNC(input, prompt)
    MPY_MODULE_FUNC(input, password)
MPY_MODULE_END(input)
