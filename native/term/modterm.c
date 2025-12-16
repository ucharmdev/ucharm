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

#include "py/runtime.h"
#include "py/obj.h"

#include <unistd.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <string.h>
#include <stdio.h>

// Store original terminal settings for restoration
static struct termios orig_termios;
static int raw_mode_enabled = 0;

// term.size() -> (cols, rows)
static mp_obj_t term_size(void) {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) {
        // Fallback to default
        mp_obj_t items[2] = {
            MP_OBJ_NEW_SMALL_INT(80),
            MP_OBJ_NEW_SMALL_INT(24)
        };
        return mp_obj_new_tuple(2, items);
    }
    mp_obj_t items[2] = {
        MP_OBJ_NEW_SMALL_INT(ws.ws_col),
        MP_OBJ_NEW_SMALL_INT(ws.ws_row)
    };
    return mp_obj_new_tuple(2, items);
}
static MP_DEFINE_CONST_FUN_OBJ_0(term_size_obj, term_size);

// term.raw_mode(enable: bool) -> None
static mp_obj_t term_raw_mode(mp_obj_t enable_obj) {
    int enable = mp_obj_is_true(enable_obj);
    
    if (enable && !raw_mode_enabled) {
        // Save current settings and enable raw mode
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
        // Restore original settings
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
        raw_mode_enabled = 0;
    }
    
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_1(term_raw_mode_obj, term_raw_mode);

// term.read_key() -> str or None
static mp_obj_t term_read_key(void) {
    char buf[8];
    ssize_t n = read(STDIN_FILENO, buf, sizeof(buf) - 1);
    
    if (n <= 0) {
        return mp_const_none;
    }
    
    buf[n] = '\0';
    
    // Handle escape sequences for arrow keys
    if (n >= 3 && buf[0] == '\x1b' && buf[1] == '[') {
        switch (buf[2]) {
            case 'A': return mp_obj_new_str("up", 2);
            case 'B': return mp_obj_new_str("down", 4);
            case 'C': return mp_obj_new_str("right", 5);
            case 'D': return mp_obj_new_str("left", 4);
            case 'H': return mp_obj_new_str("home", 4);
            case 'F': return mp_obj_new_str("end", 3);
        }
        if (n >= 4 && buf[3] == '~') {
            switch (buf[2]) {
                case '3': return mp_obj_new_str("delete", 6);
                case '5': return mp_obj_new_str("pageup", 6);
                case '6': return mp_obj_new_str("pagedown", 8);
            }
        }
    }
    
    // Handle special single characters
    if (n == 1) {
        switch (buf[0]) {
            case '\r':
            case '\n': return mp_obj_new_str("enter", 5);
            case '\x1b': return mp_obj_new_str("escape", 6);
            case '\x7f':
            case '\b': return mp_obj_new_str("backspace", 9);
            case '\t': return mp_obj_new_str("tab", 3);
            case 3: return mp_obj_new_str("ctrl-c", 6);
        }
    }
    
    // Return raw character(s)
    return mp_obj_new_str(buf, n);
}
static MP_DEFINE_CONST_FUN_OBJ_0(term_read_key_obj, term_read_key);

// term.cursor_pos(x, y) -> None
static mp_obj_t term_cursor_pos(mp_obj_t x_obj, mp_obj_t y_obj) {
    int x = mp_obj_get_int(x_obj);
    int y = mp_obj_get_int(y_obj);
    char buf[32];
    int len = snprintf(buf, sizeof(buf), "\x1b[%d;%dH", y + 1, x + 1);
    write(STDOUT_FILENO, buf, len);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_2(term_cursor_pos_obj, term_cursor_pos);

// term.cursor_up(n=1) -> None
static mp_obj_t term_cursor_up(size_t n_args, const mp_obj_t *args) {
    int n = n_args > 0 ? mp_obj_get_int(args[0]) : 1;
    char buf[16];
    int len = snprintf(buf, sizeof(buf), "\x1b[%dA", n);
    write(STDOUT_FILENO, buf, len);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(term_cursor_up_obj, 0, 1, term_cursor_up);

// term.cursor_down(n=1) -> None
static mp_obj_t term_cursor_down(size_t n_args, const mp_obj_t *args) {
    int n = n_args > 0 ? mp_obj_get_int(args[0]) : 1;
    char buf[16];
    int len = snprintf(buf, sizeof(buf), "\x1b[%dB", n);
    write(STDOUT_FILENO, buf, len);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(term_cursor_down_obj, 0, 1, term_cursor_down);

// term.cursor_left(n=1) -> None
static mp_obj_t term_cursor_left(size_t n_args, const mp_obj_t *args) {
    int n = n_args > 0 ? mp_obj_get_int(args[0]) : 1;
    char buf[16];
    int len = snprintf(buf, sizeof(buf), "\x1b[%dD", n);
    write(STDOUT_FILENO, buf, len);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(term_cursor_left_obj, 0, 1, term_cursor_left);

// term.cursor_right(n=1) -> None
static mp_obj_t term_cursor_right(size_t n_args, const mp_obj_t *args) {
    int n = n_args > 0 ? mp_obj_get_int(args[0]) : 1;
    char buf[16];
    int len = snprintf(buf, sizeof(buf), "\x1b[%dC", n);
    write(STDOUT_FILENO, buf, len);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(term_cursor_right_obj, 0, 1, term_cursor_right);

// term.clear() -> None
static mp_obj_t term_clear(void) {
    write(STDOUT_FILENO, "\x1b[2J\x1b[H", 7);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_0(term_clear_obj, term_clear);

// term.clear_line() -> None
static mp_obj_t term_clear_line(void) {
    write(STDOUT_FILENO, "\x1b[2K\r", 5);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_0(term_clear_line_obj, term_clear_line);

// term.hide_cursor() -> None
static mp_obj_t term_hide_cursor(void) {
    write(STDOUT_FILENO, "\x1b[?25l", 6);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_0(term_hide_cursor_obj, term_hide_cursor);

// term.show_cursor() -> None
static mp_obj_t term_show_cursor(void) {
    write(STDOUT_FILENO, "\x1b[?25h", 6);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_0(term_show_cursor_obj, term_show_cursor);

// term.is_tty() -> bool
static mp_obj_t term_is_tty(void) {
    return mp_obj_new_bool(isatty(STDOUT_FILENO));
}
static MP_DEFINE_CONST_FUN_OBJ_0(term_is_tty_obj, term_is_tty);

// term.write(text) -> None (direct write, no buffering)
static mp_obj_t term_write(mp_obj_t text_obj) {
    size_t len;
    const char *text = mp_obj_str_get_data(text_obj, &len);
    write(STDOUT_FILENO, text, len);
    return mp_const_none;
}
static MP_DEFINE_CONST_FUN_OBJ_1(term_write_obj, term_write);

// Module globals table
static const mp_rom_map_elem_t term_module_globals_table[] = {
    { MP_ROM_QSTR(MP_QSTR___name__), MP_ROM_QSTR(MP_QSTR_term) },
    { MP_ROM_QSTR(MP_QSTR_size), MP_ROM_PTR(&term_size_obj) },
    { MP_ROM_QSTR(MP_QSTR_raw_mode), MP_ROM_PTR(&term_raw_mode_obj) },
    { MP_ROM_QSTR(MP_QSTR_read_key), MP_ROM_PTR(&term_read_key_obj) },
    { MP_ROM_QSTR(MP_QSTR_cursor_pos), MP_ROM_PTR(&term_cursor_pos_obj) },
    { MP_ROM_QSTR(MP_QSTR_cursor_up), MP_ROM_PTR(&term_cursor_up_obj) },
    { MP_ROM_QSTR(MP_QSTR_cursor_down), MP_ROM_PTR(&term_cursor_down_obj) },
    { MP_ROM_QSTR(MP_QSTR_cursor_left), MP_ROM_PTR(&term_cursor_left_obj) },
    { MP_ROM_QSTR(MP_QSTR_cursor_right), MP_ROM_PTR(&term_cursor_right_obj) },
    { MP_ROM_QSTR(MP_QSTR_clear), MP_ROM_PTR(&term_clear_obj) },
    { MP_ROM_QSTR(MP_QSTR_clear_line), MP_ROM_PTR(&term_clear_line_obj) },
    { MP_ROM_QSTR(MP_QSTR_hide_cursor), MP_ROM_PTR(&term_hide_cursor_obj) },
    { MP_ROM_QSTR(MP_QSTR_show_cursor), MP_ROM_PTR(&term_show_cursor_obj) },
    { MP_ROM_QSTR(MP_QSTR_is_tty), MP_ROM_PTR(&term_is_tty_obj) },
    { MP_ROM_QSTR(MP_QSTR_write), MP_ROM_PTR(&term_write_obj) },
};
static MP_DEFINE_CONST_DICT(term_module_globals, term_module_globals_table);

// Module definition
const mp_obj_module_t mp_module_term = {
    .base = { &mp_type_module },
    .globals = (mp_obj_dict_t *)&term_module_globals,
};

// Register the module
MP_REGISTER_MODULE(MP_QSTR_term, mp_module_term);
