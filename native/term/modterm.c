/*
 * modterm - Native terminal module for microcharm
 * 
 * This is an external C module that gets compiled into MicroPython.
 * It provides fast terminal operations for CLI applications.
 * 
 * Usage in Python:
 *   import term
 *   cols, rows = term.size()
 *   term.raw_mode(True)
 *   key = term.read_key()
 */

#include "../bridge/mpy_bridge.h"

#include <unistd.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <stdio.h>

// Store original terminal settings for restoration
static struct termios orig_termios;
static int raw_mode_enabled = 0;

// ============================================================================
// Terminal Size & Mode
// ============================================================================

// term.size() -> (cols, rows)
MPY_FUNC_0(term, size) {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) {
        return mpy_tuple2(mpy_new_int(80), mpy_new_int(24));
    }
    return mpy_tuple2(mpy_new_int(ws.ws_col), mpy_new_int(ws.ws_row));
}
MPY_FUNC_OBJ_0(term, size);

// term.raw_mode(enable: bool) -> None
MPY_FUNC_1(term, raw_mode) {
    int enable = mpy_to_bool(arg0);
    
    if (enable && !raw_mode_enabled) {
        tcgetattr(STDIN_FILENO, &orig_termios);
        struct termios raw = orig_termios;
        raw.c_lflag &= ~(ECHO | ICANON | ISIG | IEXTEN);
        raw.c_iflag &= ~(IXON | ICRNL | BRKINT | INPCK | ISTRIP);
        raw.c_oflag &= ~(OPOST);
        raw.c_cflag |= (CS8);
        raw.c_cc[VMIN] = 0;
        raw.c_cc[VTIME] = 1;  // 100ms timeout
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
        raw_mode_enabled = 1;
    } else if (!enable && raw_mode_enabled) {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
        raw_mode_enabled = 0;
    }
    
    return mpy_none();
}
MPY_FUNC_OBJ_1(term, raw_mode);

// ============================================================================
// Key Reading
// ============================================================================

// term.read_key() -> str or None
MPY_FUNC_0(term, read_key) {
    char buf[8];
    ssize_t n = read(STDIN_FILENO, buf, sizeof(buf) - 1);
    
    if (n <= 0) {
        return mpy_none();
    }
    
    buf[n] = '\0';
    
    // Handle escape sequences for arrow keys
    if (n >= 3 && buf[0] == '\x1b' && buf[1] == '[') {
        switch (buf[2]) {
            case 'A': return mpy_new_str("up");
            case 'B': return mpy_new_str("down");
            case 'C': return mpy_new_str("right");
            case 'D': return mpy_new_str("left");
            case 'H': return mpy_new_str("home");
            case 'F': return mpy_new_str("end");
        }
        if (n >= 4 && buf[3] == '~') {
            switch (buf[2]) {
                case '3': return mpy_new_str("delete");
                case '5': return mpy_new_str("pageup");
                case '6': return mpy_new_str("pagedown");
            }
        }
    }
    
    // Handle special single characters
    if (n == 1) {
        switch (buf[0]) {
            case '\r':
            case '\n': return mpy_new_str("enter");
            case '\x1b': return mpy_new_str("escape");
            case '\x7f':
            case '\b': return mpy_new_str("backspace");
            case '\t': return mpy_new_str("tab");
            case 3: return mpy_new_str("ctrl-c");
        }
    }
    
    return mpy_new_str_len(buf, n);
}
MPY_FUNC_OBJ_0(term, read_key);

// ============================================================================
// Cursor Control
// ============================================================================

// term.cursor_pos(x, y) -> None
MPY_FUNC_2(term, cursor_pos) {
    int x = mpy_int(arg0);
    int y = mpy_int(arg1);
    char buf[32];
    int len = snprintf(buf, sizeof(buf), "\x1b[%d;%dH", y + 1, x + 1);
    write(STDOUT_FILENO, buf, len);
    return mpy_none();
}
MPY_FUNC_OBJ_2(term, cursor_pos);

// term.cursor_up(n=1) -> None
MPY_FUNC_VAR(term, cursor_up, 0, 1) {
    int count = n_args > 0 ? mpy_int(args[0]) : 1;
    char buf[16];
    int len = snprintf(buf, sizeof(buf), "\x1b[%dA", count);
    write(STDOUT_FILENO, buf, len);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(term, cursor_up, 0, 1);

// term.cursor_down(n=1) -> None
MPY_FUNC_VAR(term, cursor_down, 0, 1) {
    int count = n_args > 0 ? mpy_int(args[0]) : 1;
    char buf[16];
    int len = snprintf(buf, sizeof(buf), "\x1b[%dB", count);
    write(STDOUT_FILENO, buf, len);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(term, cursor_down, 0, 1);

// term.cursor_left(n=1) -> None
MPY_FUNC_VAR(term, cursor_left, 0, 1) {
    int count = n_args > 0 ? mpy_int(args[0]) : 1;
    char buf[16];
    int len = snprintf(buf, sizeof(buf), "\x1b[%dD", count);
    write(STDOUT_FILENO, buf, len);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(term, cursor_left, 0, 1);

// term.cursor_right(n=1) -> None
MPY_FUNC_VAR(term, cursor_right, 0, 1) {
    int count = n_args > 0 ? mpy_int(args[0]) : 1;
    char buf[16];
    int len = snprintf(buf, sizeof(buf), "\x1b[%dC", count);
    write(STDOUT_FILENO, buf, len);
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(term, cursor_right, 0, 1);

// ============================================================================
// Screen Control
// ============================================================================

// term.clear() -> None
MPY_FUNC_0(term, clear) {
    write(STDOUT_FILENO, "\x1b[2J\x1b[H", 7);
    return mpy_none();
}
MPY_FUNC_OBJ_0(term, clear);

// term.clear_line() -> None
MPY_FUNC_0(term, clear_line) {
    write(STDOUT_FILENO, "\x1b[2K\r", 5);
    return mpy_none();
}
MPY_FUNC_OBJ_0(term, clear_line);

// term.hide_cursor() -> None
MPY_FUNC_0(term, hide_cursor) {
    write(STDOUT_FILENO, "\x1b[?25l", 6);
    return mpy_none();
}
MPY_FUNC_OBJ_0(term, hide_cursor);

// term.show_cursor() -> None
MPY_FUNC_0(term, show_cursor) {
    write(STDOUT_FILENO, "\x1b[?25h", 6);
    return mpy_none();
}
MPY_FUNC_OBJ_0(term, show_cursor);

// ============================================================================
// Utilities
// ============================================================================

// term.is_tty() -> bool
MPY_FUNC_0(term, is_tty) {
    return mpy_bool(isatty(STDOUT_FILENO));
}
MPY_FUNC_OBJ_0(term, is_tty);

// term.write(text) -> None (direct write, no buffering)
MPY_FUNC_1(term, write) {
    size_t len;
    const char *text = mpy_str_len(arg0, &len);
    write(STDOUT_FILENO, text, len);
    return mpy_none();
}
MPY_FUNC_OBJ_1(term, write);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(term)
    MPY_MODULE_FUNC(term, size)
    MPY_MODULE_FUNC(term, raw_mode)
    MPY_MODULE_FUNC(term, read_key)
    MPY_MODULE_FUNC(term, cursor_pos)
    MPY_MODULE_FUNC(term, cursor_up)
    MPY_MODULE_FUNC(term, cursor_down)
    MPY_MODULE_FUNC(term, cursor_left)
    MPY_MODULE_FUNC(term, cursor_right)
    MPY_MODULE_FUNC(term, clear)
    MPY_MODULE_FUNC(term, clear_line)
    MPY_MODULE_FUNC(term, hide_cursor)
    MPY_MODULE_FUNC(term, show_cursor)
    MPY_MODULE_FUNC(term, is_tty)
    MPY_MODULE_FUNC(term, write)
MPY_MODULE_END(term)
