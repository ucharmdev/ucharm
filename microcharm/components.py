# microcharm/components.py - UI components
"""
UI components for building beautiful CLI applications.
All rendering is done natively in Zig via libmicrocharm.
"""

import sys
import time

from ._native import BORDER_DOUBLE, BORDER_HEAVY, BORDER_ROUNDED, BORDER_SQUARE, ui
from .style import style

# Border style name mapping
_BORDER_STYLES = {
    "rounded": BORDER_ROUNDED,
    "square": BORDER_SQUARE,
    "double": BORDER_DOUBLE,
    "heavy": BORDER_HEAVY,
}


def box(content, title=None, border="rounded", border_color=None, padding=1):
    """
    Draw a box around content.

    Args:
        content: String content (can be multiline)
        title: Optional title for the box
        border: Border style ("rounded", "square", "double", "heavy")
        border_color: Color for the border
        padding: Horizontal padding inside the box
    """
    border_style = _BORDER_STYLES.get(border, BORDER_ROUNDED)
    chars = ui.box_chars(border_style)
    lines = content.split("\n")

    # Calculate width based on content
    max_content_width = max(ui.visible_len(line) for line in lines)
    title_width = len(title) + 4 if title else 0
    inner_width = max(max_content_width, title_width - 2) + (padding * 2)

    def bc(t):
        """Apply border color."""
        return style(t, fg=border_color) if border_color else t

    # Top border
    if title:
        title_text = " " + title + " "
        title_styled = style(title_text, bold=True)
        remaining = inner_width - len(title_text) - 1
        top = (
            bc(chars["tl"] + chars["h"])
            + title_styled
            + bc(chars["h"] * remaining + chars["tr"])
        )
    else:
        top = bc(chars["tl"] + chars["h"] * inner_width + chars["tr"])
    print(top)

    # Content lines
    pad = " " * padding
    content_width = inner_width - (padding * 2)
    for line in lines:
        visible = ui.visible_len(line)
        right_pad = " " * (content_width - visible)
        print(bc(chars["v"]) + pad + line + right_pad + pad + bc(chars["v"]))

    # Bottom border
    print(bc(chars["bl"] + chars["h"] * inner_width + chars["br"]))


def rule(title=None, char="─", color=None, width=None):
    """
    Print a horizontal rule.

    Args:
        title: Optional centered title
        char: Character to use for the rule
        color: Color for the rule
        width: Width of rule (defaults to terminal width)
    """
    if width is None:
        try:
            from .terminal import get_size

            width, _ = get_size()
        except:
            width = 80

    if title:
        line = ui.rule_with_title(width, title, char)
    else:
        line = ui.rule(width, char)

    if color:
        line = style(line, fg=color)
    print(line)


def spinner(message, duration=None, done_message=None):
    """
    Show a spinner animation.

    Args:
        message: Message to show next to spinner
        duration: If set, run for this many seconds. Otherwise returns a context manager.
        done_message: Message to show when done (defaults to same message with checkmark)
    """
    if done_message is None:
        done_message = message

    frame_count = ui.spinner_frame_count()
    success_sym = ui.symbol_success()

    if duration is not None:
        start = time.time()
        i = 0
        while time.time() - start < duration:
            frame = ui.spinner_frame(i % frame_count)
            sys.stdout.write("\r" + style(frame, fg="cyan") + " " + message)
            sys.stdout.flush()
            time.sleep(0.08)
            i += 1
        sys.stdout.write(
            "\r"
            + style(success_sym, fg="green", bold=True)
            + " "
            + done_message
            + "   \n"
        )
        sys.stdout.flush()
    else:
        return SpinnerContext(message, done_message)


class SpinnerContext:
    """Context manager for spinner."""

    def __init__(self, message, done_message):
        self.message = message
        self.done_message = done_message
        self.frame_count = ui.spinner_frame_count()

    def __enter__(self):
        frame = ui.spinner_frame(0)
        sys.stdout.write(style(frame, fg="cyan") + " " + self.message)
        sys.stdout.flush()
        return self

    def __exit__(self, *args):
        success_sym = ui.symbol_success()
        sys.stdout.write(
            "\r"
            + style(success_sym, fg="green", bold=True)
            + " "
            + self.done_message
            + "   \n"
        )
        sys.stdout.flush()


def progress(
    current,
    total,
    width=30,
    label="",
    show_percent=True,
    fill_char="█",
    empty_char="░",
    color="cyan",
):
    """
    Show a progress bar.

    Args:
        current: Current progress value
        total: Total/max value
        width: Width of the bar in characters
        label: Label to show before the bar
        show_percent: Whether to show percentage
        fill_char: Character for filled portion
        empty_char: Character for empty portion
        color: Color of the progress bar
    """
    bar = ui.progress_bar(current, total, width, fill_char, empty_char)
    bar_styled = style(bar, fg=color)

    output = "\r"
    if label:
        output += label + " "
    output += bar_styled
    if show_percent:
        output += " " + ui.percent_str(current, total)

    sys.stdout.write(output)
    sys.stdout.flush()

    if current >= total:
        print()


def success(message):
    """Print a success message with green checkmark."""
    print(style(ui.symbol_success() + " ", fg="green", bold=True) + message)


def error(message):
    """Print an error message with red X."""
    print(style(ui.symbol_error() + " ", fg="red", bold=True) + message)


def warning(message):
    """Print a warning message with yellow symbol."""
    print(style(ui.symbol_warning() + " ", fg="yellow", bold=True) + message)


def info(message):
    """Print an info message with blue symbol."""
    print(style(ui.symbol_info() + " ", fg="blue", bold=True) + message)


def debug(message):
    """Print a debug message with dim styling."""
    print(style(ui.symbol_bullet() + " " + message, dim=True))
