# microcharm/style.py - Text styling with ANSI codes


class Color:
    """Color constants for easy access."""

    # Standard colors
    BLACK = "black"
    RED = "red"
    GREEN = "green"
    YELLOW = "yellow"
    BLUE = "blue"
    MAGENTA = "magenta"
    CYAN = "cyan"
    WHITE = "white"

    # Bright colors
    BRIGHT_BLACK = "bright_black"
    BRIGHT_RED = "bright_red"
    BRIGHT_GREEN = "bright_green"
    BRIGHT_YELLOW = "bright_yellow"
    BRIGHT_BLUE = "bright_blue"
    BRIGHT_MAGENTA = "bright_magenta"
    BRIGHT_CYAN = "bright_cyan"
    BRIGHT_WHITE = "bright_white"


# Color code mappings
_FG_COLORS = {
    "black": 30,
    "red": 31,
    "green": 32,
    "yellow": 33,
    "blue": 34,
    "magenta": 35,
    "cyan": 36,
    "white": 37,
    "bright_black": 90,
    "bright_red": 91,
    "bright_green": 92,
    "bright_yellow": 93,
    "bright_blue": 94,
    "bright_magenta": 95,
    "bright_cyan": 96,
    "bright_white": 97,
}

_BG_COLORS = {
    "black": 40,
    "red": 41,
    "green": 42,
    "yellow": 43,
    "blue": 44,
    "magenta": 45,
    "cyan": 46,
    "white": 47,
    "bright_black": 100,
    "bright_red": 101,
    "bright_green": 102,
    "bright_yellow": 103,
    "bright_blue": 104,
    "bright_magenta": 105,
    "bright_cyan": 106,
    "bright_white": 107,
}


def _parse_color(color):
    """Parse color - supports names, RGB tuples, and hex strings."""
    if color is None:
        return None

    if isinstance(color, str):
        # Named color
        if color in _FG_COLORS:
            return ("named", color)
        # Hex color
        if color.startswith("#") and len(color) == 7:
            r = int(color[1:3], 16)
            g = int(color[3:5], 16)
            b = int(color[5:7], 16)
            return ("rgb", (r, g, b))

    if isinstance(color, tuple) and len(color) == 3:
        return ("rgb", color)

    return None


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
    codes = []

    # Style attributes
    if bold:
        codes.append("1")
    if dim:
        codes.append("2")
    if italic:
        codes.append("3")
    if underline:
        codes.append("4")
    if blink:
        codes.append("5")
    if reverse:
        codes.append("7")
    if strikethrough:
        codes.append("9")

    # Foreground color
    fg_parsed = _parse_color(fg)
    if fg_parsed:
        if fg_parsed[0] == "named":
            codes.append(str(_FG_COLORS[fg_parsed[1]]))
        elif fg_parsed[0] == "rgb":
            r, g, b = fg_parsed[1]
            codes.append("38;2;" + str(r) + ";" + str(g) + ";" + str(b))

    # Background color
    bg_parsed = _parse_color(bg)
    if bg_parsed:
        if bg_parsed[0] == "named":
            codes.append(str(_BG_COLORS[bg_parsed[1]]))
        elif bg_parsed[0] == "rgb":
            r, g, b = bg_parsed[1]
            codes.append("48;2;" + str(r) + ";" + str(g) + ";" + str(b))

    if codes:
        return "\033[" + ";".join(codes) + "m" + str(text) + "\033[0m"
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
