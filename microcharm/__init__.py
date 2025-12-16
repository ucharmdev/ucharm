# μcharm (microcharm) - Beautiful CLIs for MicroPython
# Fast startup, tiny binaries, Python syntax
# https://github.com/yourname/microcharm

__version__ = "0.1.0"

from .style import style, colors, Color
from .components import box, spinner, progress, success, error, warning, info, rule
from .input import select, confirm, prompt, password
from .table import table
from .terminal import get_size, clear, hide_cursor, show_cursor
from . import args

__all__ = [
    # Styling
    "style",
    "colors",
    "Color",
    # Components
    "box",
    "spinner",
    "progress",
    "success",
    "error",
    "warning",
    "info",
    "rule",
    # Input
    "select",
    "confirm",
    "prompt",
    "password",
    # Table
    "table",
    # Terminal
    "get_size",
    "clear",
    "hide_cursor",
    "show_cursor",
    # Args
    "args",
]
