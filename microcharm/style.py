# microcharm/style.py - Text styling with ANSI codes
"""
Text styling with ANSI codes.
Uses native Zig via libmicrocharm - no Python fallbacks.
"""

# Try to use native ansi module (MicroPython with native modules)
try:
    import ansi as _ansi

    _HAS_NATIVE_MODULE = True
except ImportError:
    _ansi = None
    _HAS_NATIVE_MODULE = False

# Use native shared library (CPython)
if not _HAS_NATIVE_MODULE:
    from ._native import ansi as _ansi


class Color:
    """Color constants for easy access."""

    BLACK = "black"
    RED = "red"
    GREEN = "green"
    YELLOW = "yellow"
    BLUE = "blue"
    MAGENTA = "magenta"
    CYAN = "cyan"
    WHITE = "white"
    BRIGHT_BLACK = "bright_black"
    BRIGHT_RED = "bright_red"
    BRIGHT_GREEN = "bright_green"
    BRIGHT_YELLOW = "bright_yellow"
    BRIGHT_BLUE = "bright_blue"
    BRIGHT_MAGENTA = "bright_magenta"
    BRIGHT_CYAN = "bright_cyan"
    BRIGHT_WHITE = "bright_white"


def style(
    text,
    fg=None,
    bg=None,
    bold=False,
    dim=False,
    italic=False,
    underline=False,
    blink=False,
    reverse=False,
    strikethrough=False,
):
    """
    Style text with colors and formatting.

    Args:
        text: The text to style
        fg: Foreground color (name, hex "#RRGGBB", or RGB tuple)
        bg: Background color (name, hex "#RRGGBB", or RGB tuple)
        bold: Bold text
        dim: Dim/faint text
        italic: Italic text
        underline: Underlined text
        blink: Blinking text
        reverse: Reverse video
        strikethrough: Strikethrough text

    Returns:
        Styled string with ANSI codes
    """
    codes = ""

    # Style attributes
    if bold:
        codes += _ansi.bold()
    if dim:
        codes += _ansi.dim()
    if italic:
        codes += _ansi.italic()
    if underline:
        codes += _ansi.underline()
    if blink:
        codes += "\x1b[5m"
    if reverse:
        codes += "\x1b[7m"
    if strikethrough:
        codes += _ansi.strikethrough()

    # Foreground color
    if fg is not None:
        if isinstance(fg, tuple) and len(fg) == 3:
            codes += _ansi.rgb(fg[0], fg[1], fg[2])
        else:
            codes += _ansi.fg(fg)

    # Background color
    if bg is not None:
        if isinstance(bg, tuple) and len(bg) == 3:
            codes += _ansi.rgb(bg[0], bg[1], bg[2], True)
        else:
            codes += _ansi.bg(bg)

    if codes:
        return codes + str(text) + _ansi.reset()
    return str(text)


# Convenience functions
def colors(text, fg=None, bg=None):
    """Simple color styling without other attributes."""
    return style(text, fg=fg, bg=bg)


def bold(text, fg=None):
    """Bold text with optional color."""
    return style(text, fg=fg, bold=True)


def dim(text, fg=None):
    """Dim text with optional color."""
    return style(text, fg=fg, dim=True)


def italic(text, fg=None):
    """Italic text with optional color."""
    return style(text, fg=fg, italic=True)


def underline(text, fg=None):
    """Underlined text with optional color."""
    return style(text, fg=fg, underline=True)
