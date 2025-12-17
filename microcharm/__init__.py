# μcharm (microcharm) - Beautiful CLIs for MicroPython
# Fast startup, tiny binaries, Python syntax
# https://github.com/yourname/microcharm

__version__ = "0.1.0"

from . import args, env, json, path
from .components import box, error, info, progress, rule, spinner, success, warning
from .input import confirm, password, prompt, select
from .style import Color, colors, style
from .table import table
from .terminal import clear, get_size, hide_cursor, show_cursor

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
    # Env
    "env",
    # Path
    "path",
    # JSON
    "json",
]
