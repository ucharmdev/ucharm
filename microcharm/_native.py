"""
_native.py - ctypes bindings for libmicrocharm shared library

This module provides native Zig functionality to Python.
The native library is REQUIRED - there are no Python fallbacks.
"""

import ctypes
import os
import sys
from ctypes import (
    POINTER,
    Structure,
    c_bool,
    c_char_p,
    c_int16,
    c_int64,
    c_size_t,
    c_uint8,
)

# ============================================================================
# Constants
# ============================================================================

# Alignment constants
ALIGN_LEFT = 0
ALIGN_RIGHT = 1
ALIGN_CENTER = 2

# Border style constants
BORDER_ROUNDED = 0
BORDER_SQUARE = 1
BORDER_DOUBLE = 2
BORDER_HEAVY = 3
BORDER_NONE = 4

# ============================================================================
# Library Loading
# ============================================================================

_lib = None


def _find_library():
    """Find the libmicrocharm shared library."""
    here = os.path.dirname(os.path.abspath(__file__))

    candidates = [
        # Development locations
        os.path.join(here, "..", "native", "dist", "libmicrocharm.dylib"),
        os.path.join(here, "..", "native", "dist", "libmicrocharm.so"),
        os.path.join(
            here, "..", "native", "bridge", "zig-out", "lib", "libmicrocharm.dylib"
        ),
        os.path.join(
            here, "..", "native", "bridge", "zig-out", "lib", "libmicrocharm.so"
        ),
        # Installed location (same directory as this file)
        os.path.join(here, "libmicrocharm.dylib"),
        os.path.join(here, "libmicrocharm.so"),
    ]

    for path in candidates:
        if os.path.exists(path):
            return os.path.abspath(path)
    return None


def _load_library():
    """Load the shared library. Raises RuntimeError if not found."""
    global _lib

    if _lib is not None:
        return _lib

    lib_path = _find_library()
    if lib_path is None:
        raise RuntimeError(
            "libmicrocharm not found. Build it with: cd native/bridge && zig build"
        )

    _lib = ctypes.CDLL(lib_path)
    _setup_functions()
    return _lib


# ============================================================================
# Type Definitions
# ============================================================================


class Color(Structure):
    """RGB color with validity flag."""

    _fields_ = [("r", c_uint8), ("g", c_uint8), ("b", c_uint8), ("valid", c_bool)]


class ColorIndex(Structure):
    """Color index with brightness flag."""

    _fields_ = [("index", c_int16), ("is_bright", c_bool)]


# ============================================================================
# Function Signatures
# ============================================================================


def _setup_functions():
    """Set up function signatures for type safety."""
    # Version
    _lib.microcharm_version.argtypes = []
    _lib.microcharm_version.restype = c_char_p

    # ANSI functions
    _lib.ansi_color_name_to_index.argtypes = [c_char_p]
    _lib.ansi_color_name_to_index.restype = ColorIndex
    _lib.ansi_parse_hex_color.argtypes = [c_char_p]
    _lib.ansi_parse_hex_color.restype = Color
    _lib.ansi_is_hex_color.argtypes = [c_char_p]
    _lib.ansi_is_hex_color.restype = c_bool
    _lib.ansi_fg_256.argtypes = [c_uint8, c_char_p]
    _lib.ansi_fg_256.restype = c_size_t
    _lib.ansi_bg_256.argtypes = [c_uint8, c_char_p]
    _lib.ansi_bg_256.restype = c_size_t
    _lib.ansi_fg_rgb.argtypes = [c_uint8, c_uint8, c_uint8, c_char_p]
    _lib.ansi_fg_rgb.restype = c_size_t
    _lib.ansi_bg_rgb.argtypes = [c_uint8, c_uint8, c_uint8, c_char_p]
    _lib.ansi_bg_rgb.restype = c_size_t
    _lib.ansi_fg_standard.argtypes = [c_uint8, c_char_p]
    _lib.ansi_fg_standard.restype = c_size_t
    _lib.ansi_bg_standard.argtypes = [c_uint8, c_char_p]
    _lib.ansi_bg_standard.restype = c_size_t

    # Args functions
    _lib.args_is_valid_int.argtypes = [c_char_p]
    _lib.args_is_valid_int.restype = c_bool
    _lib.args_is_valid_float.argtypes = [c_char_p]
    _lib.args_is_valid_float.restype = c_bool
    _lib.args_parse_int.argtypes = [c_char_p]
    _lib.args_parse_int.restype = c_int64
    _lib.args_is_long_flag.argtypes = [c_char_p]
    _lib.args_is_long_flag.restype = c_bool
    _lib.args_is_short_flag.argtypes = [c_char_p]
    _lib.args_is_short_flag.restype = c_bool
    _lib.args_is_negative_number.argtypes = [c_char_p]
    _lib.args_is_negative_number.restype = c_bool
    _lib.args_get_flag_name.argtypes = [c_char_p]
    _lib.args_get_flag_name.restype = c_char_p
    _lib.args_is_negated_flag.argtypes = [c_char_p]
    _lib.args_is_negated_flag.restype = c_bool
    _lib.args_is_truthy.argtypes = [c_char_p]
    _lib.args_is_truthy.restype = c_bool
    _lib.args_is_falsy.argtypes = [c_char_p]
    _lib.args_is_falsy.restype = c_bool

    # UI functions
    _lib.ui_visible_len.argtypes = [c_char_p]
    _lib.ui_visible_len.restype = c_size_t
    _lib.ui_byte_len.argtypes = [c_char_p]
    _lib.ui_byte_len.restype = c_size_t
    _lib.ui_pad.argtypes = [c_char_p, c_char_p, c_size_t, c_uint8]
    _lib.ui_pad.restype = c_size_t
    _lib.ui_repeat_str.argtypes = [c_char_p, c_char_p, c_size_t]
    _lib.ui_repeat_str.restype = c_size_t
    _lib.ui_progress_bar.argtypes = [
        c_char_p,
        c_size_t,
        c_size_t,
        c_size_t,
        c_char_p,
        c_char_p,
    ]
    _lib.ui_progress_bar.restype = c_size_t
    _lib.ui_percent_str.argtypes = [c_char_p, c_size_t, c_size_t]
    _lib.ui_percent_str.restype = c_size_t
    _lib.ui_box_char_tl.argtypes = [c_uint8]
    _lib.ui_box_char_tl.restype = c_char_p
    _lib.ui_box_char_tr.argtypes = [c_uint8]
    _lib.ui_box_char_tr.restype = c_char_p
    _lib.ui_box_char_bl.argtypes = [c_uint8]
    _lib.ui_box_char_bl.restype = c_char_p
    _lib.ui_box_char_br.argtypes = [c_uint8]
    _lib.ui_box_char_br.restype = c_char_p
    _lib.ui_box_char_h.argtypes = [c_uint8]
    _lib.ui_box_char_h.restype = c_char_p
    _lib.ui_box_char_v.argtypes = [c_uint8]
    _lib.ui_box_char_v.restype = c_char_p
    _lib.ui_box_top.argtypes = [c_char_p, c_size_t, c_uint8]
    _lib.ui_box_top.restype = c_size_t
    _lib.ui_box_bottom.argtypes = [c_char_p, c_size_t, c_uint8]
    _lib.ui_box_bottom.restype = c_size_t
    _lib.ui_box_middle.argtypes = [c_char_p, c_char_p, c_size_t, c_uint8, c_size_t]
    _lib.ui_box_middle.restype = c_size_t
    _lib.ui_rule.argtypes = [c_char_p, c_size_t, c_char_p]
    _lib.ui_rule.restype = c_size_t
    _lib.ui_rule_with_title.argtypes = [c_char_p, c_size_t, c_char_p, c_char_p]
    _lib.ui_rule_with_title.restype = c_size_t
    _lib.ui_spinner_frame.argtypes = [c_size_t]
    _lib.ui_spinner_frame.restype = c_char_p
    _lib.ui_spinner_frame_count.argtypes = []
    _lib.ui_spinner_frame_count.restype = c_size_t
    _lib.ui_symbol_success.argtypes = []
    _lib.ui_symbol_success.restype = c_char_p
    _lib.ui_symbol_error.argtypes = []
    _lib.ui_symbol_error.restype = c_char_p
    _lib.ui_symbol_warning.argtypes = []
    _lib.ui_symbol_warning.restype = c_char_p
    _lib.ui_symbol_info.argtypes = []
    _lib.ui_symbol_info.restype = c_char_p
    _lib.ui_symbol_bullet.argtypes = []
    _lib.ui_symbol_bullet.restype = c_char_p
    _lib.ui_table_char_v.argtypes = []
    _lib.ui_table_char_v.restype = c_char_p
    _lib.ui_table_top.argtypes = [c_char_p, POINTER(c_size_t), c_size_t]
    _lib.ui_table_top.restype = c_size_t
    _lib.ui_table_divider.argtypes = [c_char_p, POINTER(c_size_t), c_size_t]
    _lib.ui_table_divider.restype = c_size_t
    _lib.ui_table_bottom.argtypes = [c_char_p, POINTER(c_size_t), c_size_t]
    _lib.ui_table_bottom.restype = c_size_t
    _lib.ui_table_cell.argtypes = [c_char_p, c_char_p, c_size_t, c_uint8, c_size_t]
    _lib.ui_table_cell.restype = c_size_t
    _lib.ui_select_indicator.argtypes = []
    _lib.ui_select_indicator.restype = c_char_p
    _lib.ui_checkbox_on.argtypes = []
    _lib.ui_checkbox_on.restype = c_char_p
    _lib.ui_checkbox_off.argtypes = []
    _lib.ui_checkbox_off.restype = c_char_p
    _lib.ui_prompt_question.argtypes = []
    _lib.ui_prompt_question.restype = c_char_p
    _lib.ui_prompt_success.argtypes = []
    _lib.ui_prompt_success.restype = c_char_p
    _lib.ui_cursor_up.argtypes = [c_char_p, c_size_t]
    _lib.ui_cursor_up.restype = c_size_t
    _lib.ui_cursor_down.argtypes = [c_char_p, c_size_t]
    _lib.ui_cursor_down.restype = c_size_t
    _lib.ui_clear_line.argtypes = []
    _lib.ui_clear_line.restype = c_char_p
    _lib.ui_hide_cursor.argtypes = []
    _lib.ui_hide_cursor.restype = c_char_p
    _lib.ui_show_cursor.argtypes = []
    _lib.ui_show_cursor.restype = c_char_p

    # Env functions
    _lib.env_get.argtypes = [c_char_p]
    _lib.env_get.restype = c_char_p
    _lib.env_has.argtypes = [c_char_p]
    _lib.env_has.restype = c_bool
    _lib.env_get_or.argtypes = [c_char_p, c_char_p]
    _lib.env_get_or.restype = c_char_p
    _lib.env_is_truthy.argtypes = [c_char_p]
    _lib.env_is_truthy.restype = c_bool
    _lib.env_is_falsy.argtypes = [c_char_p]
    _lib.env_is_falsy.restype = c_bool
    _lib.env_get_int.argtypes = [c_char_p, c_int64]
    _lib.env_get_int.restype = c_int64
    _lib.env_is_ci.argtypes = []
    _lib.env_is_ci.restype = c_bool
    _lib.env_is_debug.argtypes = []
    _lib.env_is_debug.restype = c_bool
    _lib.env_no_color.argtypes = []
    _lib.env_no_color.restype = c_bool
    _lib.env_force_color.argtypes = []
    _lib.env_force_color.restype = c_bool
    _lib.env_get_term.argtypes = []
    _lib.env_get_term.restype = c_char_p
    _lib.env_is_dumb_term.argtypes = []
    _lib.env_is_dumb_term.restype = c_bool
    _lib.env_get_home.argtypes = []
    _lib.env_get_home.restype = c_char_p
    _lib.env_get_user.argtypes = []
    _lib.env_get_user.restype = c_char_p
    _lib.env_get_shell.argtypes = []
    _lib.env_get_shell.restype = c_char_p
    _lib.env_get_pwd.argtypes = []
    _lib.env_get_pwd.restype = c_char_p
    _lib.env_get_path.argtypes = []
    _lib.env_get_path.restype = c_char_p
    _lib.env_get_editor.argtypes = []
    _lib.env_get_editor.restype = c_char_p

    # Path functions
    _lib.path_basename.argtypes = [c_char_p, c_char_p, c_size_t]
    _lib.path_basename.restype = c_size_t
    _lib.path_dirname.argtypes = [c_char_p, c_char_p, c_size_t]
    _lib.path_dirname.restype = c_size_t
    _lib.path_extname.argtypes = [c_char_p, c_char_p, c_size_t]
    _lib.path_extname.restype = c_size_t
    _lib.path_stem.argtypes = [c_char_p, c_char_p, c_size_t]
    _lib.path_stem.restype = c_size_t
    _lib.path_join.argtypes = [c_char_p, c_char_p, c_char_p, c_size_t]
    _lib.path_join.restype = c_size_t
    _lib.path_join3.argtypes = [c_char_p, c_char_p, c_char_p, c_char_p, c_size_t]
    _lib.path_join3.restype = c_size_t
    _lib.path_is_absolute.argtypes = [c_char_p]
    _lib.path_is_absolute.restype = c_bool
    _lib.path_is_relative.argtypes = [c_char_p]
    _lib.path_is_relative.restype = c_bool
    _lib.path_has_extension.argtypes = [c_char_p]
    _lib.path_has_extension.restype = c_bool
    _lib.path_has_ext.argtypes = [c_char_p, c_char_p]
    _lib.path_has_ext.restype = c_bool
    _lib.path_normalize.argtypes = [c_char_p, c_char_p, c_size_t]
    _lib.path_normalize.restype = c_size_t
    _lib.path_component_count.argtypes = [c_char_p]
    _lib.path_component_count.restype = c_size_t
    _lib.path_component.argtypes = [c_char_p, c_size_t, c_char_p, c_size_t]
    _lib.path_component.restype = c_size_t
    _lib.path_relative.argtypes = [c_char_p, c_char_p, c_char_p, c_size_t]
    _lib.path_relative.restype = c_size_t


# ============================================================================
# Helper
# ============================================================================


def _b(s):
    """Convert string to bytes."""
    return s.encode("utf-8") if isinstance(s, str) else s


def _s(b):
    """Convert bytes to string."""
    return b.decode("utf-8") if isinstance(b, bytes) else b


# ============================================================================
# Public API
# ============================================================================


def version():
    """Get native library version."""
    return _s(_load_library().microcharm_version())


# ============================================================================
# ANSI Module
# ============================================================================


class ansi:
    """Native ANSI color code generation."""

    @staticmethod
    def fg(color):
        """Generate foreground color code."""
        lib = _load_library()
        buf = ctypes.create_string_buffer(32)

        if isinstance(color, int):
            if color < 16:
                length = lib.ansi_fg_standard(color, buf)
            else:
                length = lib.ansi_fg_256(color, buf)
            return buf.value[:length].decode("utf-8")

        color_bytes = _b(color)
        if lib.ansi_is_hex_color(color_bytes):
            c = lib.ansi_parse_hex_color(color_bytes)
            if c.valid:
                length = lib.ansi_fg_rgb(c.r, c.g, c.b, buf)
                return buf.value[:length].decode("utf-8")
        else:
            ci = lib.ansi_color_name_to_index(color_bytes)
            if ci.index >= 0:
                length = lib.ansi_fg_standard(ci.index, buf)
                return buf.value[:length].decode("utf-8")
        return ""

    @staticmethod
    def bg(color):
        """Generate background color code."""
        lib = _load_library()
        buf = ctypes.create_string_buffer(32)

        if isinstance(color, int):
            if color < 16:
                length = lib.ansi_bg_standard(color, buf)
            else:
                length = lib.ansi_bg_256(color, buf)
            return buf.value[:length].decode("utf-8")

        color_bytes = _b(color)
        if lib.ansi_is_hex_color(color_bytes):
            c = lib.ansi_parse_hex_color(color_bytes)
            if c.valid:
                length = lib.ansi_bg_rgb(c.r, c.g, c.b, buf)
                return buf.value[:length].decode("utf-8")
        else:
            ci = lib.ansi_color_name_to_index(color_bytes)
            if ci.index >= 0:
                length = lib.ansi_bg_standard(ci.index, buf)
                return buf.value[:length].decode("utf-8")
        return ""

    @staticmethod
    def rgb(r, g, b, is_bg=False):
        """Generate RGB color code."""
        lib = _load_library()
        buf = ctypes.create_string_buffer(32)
        if is_bg:
            length = lib.ansi_bg_rgb(r, g, b, buf)
        else:
            length = lib.ansi_fg_rgb(r, g, b, buf)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def reset():
        return "\x1b[0m"

    @staticmethod
    def bold():
        return "\x1b[1m"

    @staticmethod
    def dim():
        return "\x1b[2m"

    @staticmethod
    def italic():
        return "\x1b[3m"

    @staticmethod
    def underline():
        return "\x1b[4m"

    @staticmethod
    def strikethrough():
        return "\x1b[9m"


# ============================================================================
# UI Module
# ============================================================================


class ui:
    """Native UI rendering utilities."""

    @staticmethod
    def visible_len(s):
        """Get visible length of string (excluding ANSI codes)."""
        return _load_library().ui_visible_len(_b(s))

    @staticmethod
    def pad(text, width, align=ALIGN_LEFT):
        """Pad text to width with alignment."""
        buf = ctypes.create_string_buffer(width * 4 + len(text) + 1)
        length = _load_library().ui_pad(buf, _b(text), width, align)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def progress_bar(current, total, width, fill_char="█", empty_char="░"):
        """Generate a progress bar string."""
        buf = ctypes.create_string_buffer(width * 4 + 1)
        length = _load_library().ui_progress_bar(
            buf, current, total, width, _b(fill_char), _b(empty_char)
        )
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def percent_str(current, total):
        """Generate percentage string (e.g., '42%')."""
        buf = ctypes.create_string_buffer(8)
        length = _load_library().ui_percent_str(buf, current, total)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def box_top(width, style=BORDER_ROUNDED):
        """Build top border of box."""
        buf = ctypes.create_string_buffer(width * 4 + 20)
        length = _load_library().ui_box_top(buf, width, style)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def box_bottom(width, style=BORDER_ROUNDED):
        """Build bottom border of box."""
        buf = ctypes.create_string_buffer(width * 4 + 20)
        length = _load_library().ui_box_bottom(buf, width, style)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def box_middle(content, width, style=BORDER_ROUNDED, padding=1):
        """Build middle row of box."""
        buf = ctypes.create_string_buffer(width * 4 + len(content) + 50)
        length = _load_library().ui_box_middle(buf, _b(content), width, style, padding)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def box_chars(style=BORDER_ROUNDED):
        """Get box characters for a style."""
        lib = _load_library()
        return {
            "tl": _s(lib.ui_box_char_tl(style)),
            "tr": _s(lib.ui_box_char_tr(style)),
            "bl": _s(lib.ui_box_char_bl(style)),
            "br": _s(lib.ui_box_char_br(style)),
            "h": _s(lib.ui_box_char_h(style)),
            "v": _s(lib.ui_box_char_v(style)),
        }

    @staticmethod
    def rule(width, char="─"):
        """Build a horizontal rule."""
        buf = ctypes.create_string_buffer(width * 4 + 1)
        length = _load_library().ui_rule(buf, width, _b(char))
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def rule_with_title(width, title, char="─"):
        """Build a horizontal rule with centered title."""
        buf = ctypes.create_string_buffer(width * 4 + len(title) + 10)
        length = _load_library().ui_rule_with_title(buf, width, _b(title), _b(char))
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def spinner_frame(index):
        """Get spinner animation frame."""
        return _s(_load_library().ui_spinner_frame(index))

    @staticmethod
    def spinner_frame_count():
        """Get total number of spinner frames."""
        return _load_library().ui_spinner_frame_count()

    @staticmethod
    def symbol_success():
        return _s(_load_library().ui_symbol_success())

    @staticmethod
    def symbol_error():
        return _s(_load_library().ui_symbol_error())

    @staticmethod
    def symbol_warning():
        return _s(_load_library().ui_symbol_warning())

    @staticmethod
    def symbol_info():
        return _s(_load_library().ui_symbol_info())

    @staticmethod
    def symbol_bullet():
        return _s(_load_library().ui_symbol_bullet())

    @staticmethod
    def table_top(col_widths):
        """Build table top border."""
        arr = (c_size_t * len(col_widths))(*col_widths)
        buf = ctypes.create_string_buffer(
            sum(col_widths) * 4 + len(col_widths) * 4 + 20
        )
        length = _load_library().ui_table_top(buf, arr, len(col_widths))
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def table_divider(col_widths):
        """Build table divider row."""
        arr = (c_size_t * len(col_widths))(*col_widths)
        buf = ctypes.create_string_buffer(
            sum(col_widths) * 4 + len(col_widths) * 4 + 20
        )
        length = _load_library().ui_table_divider(buf, arr, len(col_widths))
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def table_bottom(col_widths):
        """Build table bottom border."""
        arr = (c_size_t * len(col_widths))(*col_widths)
        buf = ctypes.create_string_buffer(
            sum(col_widths) * 4 + len(col_widths) * 4 + 20
        )
        length = _load_library().ui_table_bottom(buf, arr, len(col_widths))
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def table_cell(content, width, align=ALIGN_LEFT, padding=1):
        """Build a table cell."""
        buf = ctypes.create_string_buffer(width * 4 + len(content) + 10)
        length = _load_library().ui_table_cell(buf, _b(content), width, align, padding)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def table_v():
        """Get table vertical bar character."""
        return _s(_load_library().ui_table_char_v())

    @staticmethod
    def select_indicator():
        return _s(_load_library().ui_select_indicator())

    @staticmethod
    def checkbox_on():
        return _s(_load_library().ui_checkbox_on())

    @staticmethod
    def checkbox_off():
        return _s(_load_library().ui_checkbox_off())

    @staticmethod
    def prompt_question():
        return _s(_load_library().ui_prompt_question())

    @staticmethod
    def prompt_success():
        return _s(_load_library().ui_prompt_success())

    @staticmethod
    def cursor_up(n):
        """Get cursor up escape sequence."""
        buf = ctypes.create_string_buffer(16)
        length = _load_library().ui_cursor_up(buf, n)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def cursor_down(n):
        """Get cursor down escape sequence."""
        buf = ctypes.create_string_buffer(16)
        length = _load_library().ui_cursor_down(buf, n)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def clear_line():
        return _s(_load_library().ui_clear_line())

    @staticmethod
    def hide_cursor():
        return _s(_load_library().ui_hide_cursor())

    @staticmethod
    def show_cursor():
        return _s(_load_library().ui_show_cursor())


# ============================================================================
# Env Module
# ============================================================================


class env:
    """Native environment variable access."""

    @staticmethod
    def get(name, default=None):
        """Get environment variable value."""
        result = _load_library().env_get(_b(name))
        if result is None:
            return default
        return _s(result)

    @staticmethod
    def has(name):
        """Check if environment variable is set."""
        return _load_library().env_has(_b(name))

    @staticmethod
    def get_or(name, default):
        """Get environment variable with default."""
        return _s(_load_library().env_get_or(_b(name), _b(default)))

    @staticmethod
    def is_truthy(name):
        """Check if environment variable is truthy."""
        return _load_library().env_is_truthy(_b(name))

    @staticmethod
    def is_falsy(name):
        """Check if environment variable is falsy."""
        return _load_library().env_is_falsy(_b(name))

    @staticmethod
    def get_int(name, default=0):
        """Get environment variable as integer."""
        return _load_library().env_get_int(_b(name), default)

    @staticmethod
    def is_ci():
        """Check if running in CI environment."""
        return _load_library().env_is_ci()

    @staticmethod
    def is_debug():
        """Check if DEBUG mode is enabled."""
        return _load_library().env_is_debug()

    @staticmethod
    def no_color():
        """Check if NO_COLOR is set."""
        return _load_library().env_no_color()

    @staticmethod
    def force_color():
        """Check if FORCE_COLOR is set."""
        return _load_library().env_force_color()

    @staticmethod
    def get_term():
        """Get TERM environment variable."""
        result = _load_library().env_get_term()
        return _s(result) if result else None

    @staticmethod
    def is_dumb_term():
        """Check if terminal is dumb."""
        return _load_library().env_is_dumb_term()

    @staticmethod
    def home():
        """Get HOME directory."""
        result = _load_library().env_get_home()
        return _s(result) if result else None

    @staticmethod
    def user():
        """Get current username."""
        result = _load_library().env_get_user()
        return _s(result) if result else None

    @staticmethod
    def shell():
        """Get current shell."""
        result = _load_library().env_get_shell()
        return _s(result) if result else None

    @staticmethod
    def pwd():
        """Get PWD environment variable."""
        result = _load_library().env_get_pwd()
        return _s(result) if result else None

    @staticmethod
    def path():
        """Get PATH environment variable."""
        result = _load_library().env_get_path()
        return _s(result) if result else None

    @staticmethod
    def editor():
        """Get VISUAL or EDITOR environment variable."""
        result = _load_library().env_get_editor()
        return _s(result) if result else None


# ============================================================================
# Path Module
# ============================================================================


class path:
    """Native path manipulation utilities."""

    @staticmethod
    def basename(p):
        """Get base name of path."""
        buf = ctypes.create_string_buffer(4096)
        length = _load_library().path_basename(_b(p), buf, 4096)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def dirname(p):
        """Get directory name of path."""
        buf = ctypes.create_string_buffer(4096)
        length = _load_library().path_dirname(_b(p), buf, 4096)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def extname(p):
        """Get file extension (including dot)."""
        buf = ctypes.create_string_buffer(256)
        length = _load_library().path_extname(_b(p), buf, 256)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def stem(p):
        """Get file name without extension."""
        buf = ctypes.create_string_buffer(4096)
        length = _load_library().path_stem(_b(p), buf, 4096)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def join(*parts):
        """Join path components."""
        if len(parts) == 0:
            return ""
        if len(parts) == 1:
            return parts[0]

        buf = ctypes.create_string_buffer(4096)
        lib = _load_library()

        if len(parts) == 2:
            length = lib.path_join(_b(parts[0]), _b(parts[1]), buf, 4096)
        elif len(parts) == 3:
            length = lib.path_join3(_b(parts[0]), _b(parts[1]), _b(parts[2]), buf, 4096)
        else:
            # For more than 3, chain joins
            result = parts[0]
            for p in parts[1:]:
                length = lib.path_join(_b(result), _b(p), buf, 4096)
                result = buf.value[:length].decode("utf-8")
            return result

        return buf.value[:length].decode("utf-8")

    @staticmethod
    def is_absolute(p):
        """Check if path is absolute."""
        return _load_library().path_is_absolute(_b(p))

    @staticmethod
    def is_relative(p):
        """Check if path is relative."""
        return _load_library().path_is_relative(_b(p))

    @staticmethod
    def has_extension(p):
        """Check if path has an extension."""
        return _load_library().path_has_extension(_b(p))

    @staticmethod
    def has_ext(p, ext):
        """Check if path has specific extension."""
        return _load_library().path_has_ext(_b(p), _b(ext))

    @staticmethod
    def normalize(p):
        """Normalize path (resolve . and ..)."""
        buf = ctypes.create_string_buffer(4096)
        length = _load_library().path_normalize(_b(p), buf, 4096)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def component_count(p):
        """Get number of path components."""
        return _load_library().path_component_count(_b(p))

    @staticmethod
    def component(p, index):
        """Get specific path component by index."""
        buf = ctypes.create_string_buffer(4096)
        length = _load_library().path_component(_b(p), index, buf, 4096)
        return buf.value[:length].decode("utf-8")

    @staticmethod
    def relative(from_path, to_path):
        """Calculate relative path from one path to another."""
        buf = ctypes.create_string_buffer(4096)
        length = _load_library().path_relative(_b(from_path), _b(to_path), buf, 4096)
        return buf.value[:length].decode("utf-8")
