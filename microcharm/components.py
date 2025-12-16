# microcharm/components.py - UI components
import sys
import time
from .style import style

# Box drawing characters
BOX_CHARS = {
    "rounded": {"tl": "╭", "tr": "╮", "bl": "╰", "br": "╯", "h": "─", "v": "│"},
    "square": {"tl": "┌", "tr": "┐", "bl": "└", "br": "┘", "h": "─", "v": "│"},
    "double": {"tl": "╔", "tr": "╗", "bl": "╚", "br": "╝", "h": "═", "v": "║"},
    "heavy": {"tl": "┏", "tr": "┓", "bl": "┗", "br": "┛", "h": "━", "v": "┃"},
}


def _visible_len(s):
    """Get visible length of string (excluding ANSI codes)."""
    import re

    # This is a simplified version - MicroPython re is limited
    result = s
    while "\033[" in result:
        start = result.find("\033[")
        end = start + 2
        while end < len(result) and result[end] not in "mHJK":
            end += 1
        if end < len(result):
            result = result[:start] + result[end + 1 :]
        else:
            break
    return len(result)


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
    chars = BOX_CHARS.get(border, BOX_CHARS["rounded"])
    lines = content.split("\n")

    # Calculate width based on content
    max_content_width = max(_visible_len(l) for l in lines)

    # Title takes: "─ title ─" so title + 4 chars (dash, space, space, dash)
    title_width = len(title) + 4 if title else 0

    # Inner width is the wider of content or title, plus padding on both sides
    inner_width = max(max_content_width, title_width - 2) + (padding * 2)

    def bc(t):
        """Apply border color."""
        return style(t, fg=border_color) if border_color else t

    # Top border
    if title:
        title_text = " " + title + " "
        title_styled = style(title_text, bold=True)
        # Top line: ╭─ title ─────╮
        # We need: tl + h + title_text + remaining h's + tr
        remaining = inner_width - len(title_text) - 1  # -1 for the first ─
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
        visible = _visible_len(line)
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
        title_str = " " + title + " "
        side_len = (width - len(title_str)) // 2
        line = char * side_len + title_str + char * side_len
        # Adjust for odd widths
        if len(line) < width:
            line += char
    else:
        line = char * width

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

    Usage:
        # Timed spinner
        spinner("Loading...", duration=2)

        # Context manager
        with spinner("Processing..."):
            do_work()
    """
    frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    if done_message is None:
        done_message = message

    if duration is not None:
        # Simple timed spinner
        start = time.time()
        i = 0
        while time.time() - start < duration:
            frame = frames[i % len(frames)]
            sys.stdout.write("\r" + style(frame, fg="cyan") + " " + message)
            sys.stdout.flush()
            time.sleep(0.08)
            i += 1
        sys.stdout.write(
            "\r" + style("✓", fg="green", bold=True) + " " + done_message + "   \n"
        )
        sys.stdout.flush()
    else:
        # Return a spinner context manager
        return SpinnerContext(message, done_message, frames)


class SpinnerContext:
    """Context manager for spinner."""

    def __init__(self, message, done_message, frames):
        self.message = message
        self.done_message = done_message
        self.frames = frames
        self.running = False
        self.i = 0

    def __enter__(self):
        self.running = True
        # Start spinner in simple mode - just show first frame
        sys.stdout.write(style(self.frames[0], fg="cyan") + " " + self.message)
        sys.stdout.flush()
        return self

    def __exit__(self, *args):
        self.running = False
        sys.stdout.write(
            "\r" + style("✓", fg="green", bold=True) + " " + self.done_message + "   \n"
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
    if total == 0:
        ratio = 0
    else:
        ratio = current / total

    filled = int(width * ratio)
    bar = fill_char * filled + empty_char * (width - filled)
    bar_styled = style(bar, fg=color)

    output = "\r"
    if label:
        output += label + " "
    output += bar_styled
    if show_percent:
        percent = int(100 * ratio)
        output += " " + str(percent) + "%"

    sys.stdout.write(output)
    sys.stdout.flush()

    if current >= total:
        print()


def success(message):
    """Print a success message with green checkmark."""
    print(style("✓ ", fg="green", bold=True) + message)


def error(message):
    """Print an error message with red X."""
    print(style("✗ ", fg="red", bold=True) + message)


def warning(message):
    """Print a warning message with yellow symbol."""
    print(style("⚠ ", fg="yellow", bold=True) + message)


def info(message):
    """Print an info message with blue symbol."""
    print(style("ℹ ", fg="blue", bold=True) + message)


def debug(message):
    """Print a debug message with dim styling."""
    print(style("● " + message, dim=True))
