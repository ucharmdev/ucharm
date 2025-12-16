# microcharm/input.py - Interactive input components
import sys
from .style import style
from .terminal import move_up, clear_line, hide_cursor, show_cursor

# Try to use native term module
try:
    import term as _term

    _HAS_NATIVE = True
except ImportError:
    _term = None
    _HAS_NATIVE = False


def _read_key(vim_nav=False):
    """Read a keypress, handling escape sequences for special keys.

    Args:
        vim_nav: If True, j/k are mapped to down/up for menu navigation
    """
    # Use native module if available (much faster, handles raw mode internally)
    if _HAS_NATIVE:
        _term.raw_mode(True)
        try:
            key = _term.read_key()
            if key is None:
                return None

            # Handle Ctrl+C
            if key == "ctrl-c":
                raise KeyboardInterrupt()

            # Map space character
            if key == " ":
                return "space"

            # Vim-style navigation
            if vim_nav:
                if key == "j":
                    return "down"
                if key == "k":
                    return "up"

            return key
        finally:
            _term.raw_mode(False)

    # Fallback to pure Python implementation
    import termios

    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        termios.setraw(fd)

        ch = sys.stdin.read(1)

        # Handle Ctrl+C
        if ch == "\x03":
            raise KeyboardInterrupt()

        # If escape, read the rest of the sequence
        if ch == "\x1b":
            # Read next two chars (escape sequences are ESC [ X)
            ch2 = sys.stdin.read(1)
            if ch2 == "[":
                ch3 = sys.stdin.read(1)
                if ch3 == "A":
                    return "up"
                elif ch3 == "B":
                    return "down"
                elif ch3 == "C":
                    return "right"
                elif ch3 == "D":
                    return "left"
                elif ch3 == "H":
                    return "home"
                elif ch3 == "F":
                    return "end"
            return "escape"

        if ch == "\n" or ch == "\r":
            return "enter"
        if ch == "\x7f" or ch == "\x08":
            return "backspace"
        if ch == "\t":
            return "tab"
        if ch == " ":
            return "space"

        # Vim-style navigation (only in menus)
        if vim_nav:
            if ch == "j":
                return "down"
            if ch == "k":
                return "up"

        return ch
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, old)


def select(prompt, options, default=0):
    """
    Interactive selection menu.

    Args:
        prompt: Question/prompt text
        options: List of options to choose from
        default: Default selected index

    Returns:
        Selected option (string), or None if cancelled
    """
    selected = default

    print(style("? ", fg="cyan", bold=True) + style(prompt, bold=True))

    hide_cursor()
    try:
        while True:
            # Draw options
            for i, opt in enumerate(options):
                if i == selected:
                    print(
                        "  " + style("> ", fg="cyan") + style(opt, fg="cyan", bold=True)
                    )
                else:
                    print("    " + style(opt, dim=True))

            try:
                key = _read_key(vim_nav=True)
            except KeyboardInterrupt:
                # Clean up and exit
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                print(
                    style("? ", fg="cyan", bold=True)
                    + style(prompt, bold=True)
                    + style(" (cancelled)", dim=True)
                )
                show_cursor()
                sys.exit(130)  # Standard exit code for Ctrl+C

            if key == "up":
                selected = (selected - 1) % len(options)
            elif key == "down":
                selected = (selected + 1) % len(options)
            elif key == "enter":
                # Clear options and show result
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                print(
                    style("* ", fg="green", bold=True)
                    + style(prompt, bold=True)
                    + " "
                    + style(options[selected], fg="cyan")
                )
                return options[selected]
            elif key == "escape":
                # Cancel
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                print(
                    style("? ", fg="cyan", bold=True)
                    + style(prompt, bold=True)
                    + style(" (cancelled)", dim=True)
                )
                return None

            # Move cursor back up to redraw
            for _ in range(len(options)):
                move_up(1)
                clear_line()
    finally:
        show_cursor()


def multiselect(prompt, options, defaults=None):
    """
    Interactive multi-selection menu.

    Args:
        prompt: Question/prompt text
        options: List of options to choose from
        defaults: List of indices to pre-select

    Returns:
        List of selected options (strings)
    """
    selected_idx = 0
    checked = set(defaults or [])

    print(
        style("? ", fg="cyan", bold=True)
        + style(prompt, bold=True)
        + style(" (space to select, enter to confirm)", dim=True)
    )

    hide_cursor()
    try:
        while True:
            # Draw options
            for i, opt in enumerate(options):
                checkbox = (
                    style("[x]", fg="cyan") if i in checked else style("[ ]", dim=True)
                )
                if i == selected_idx:
                    print(
                        "  "
                        + style("> ", fg="cyan")
                        + checkbox
                        + " "
                        + style(
                            opt, fg="cyan" if i in checked else None, bold=i in checked
                        )
                    )
                else:
                    print("    " + checkbox + " " + opt)

            try:
                key = _read_key(vim_nav=True)
            except KeyboardInterrupt:
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                print(
                    style("? ", fg="cyan", bold=True)
                    + style(prompt, bold=True)
                    + style(" (cancelled)", dim=True)
                )
                show_cursor()
                sys.exit(130)

            if key == "up":
                selected_idx = (selected_idx - 1) % len(options)
            elif key == "down":
                selected_idx = (selected_idx + 1) % len(options)
            elif key == "space":
                if selected_idx in checked:
                    checked.remove(selected_idx)
                else:
                    checked.add(selected_idx)
            elif key == "enter":
                # Clear and show result
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                selected = [options[i] for i in sorted(checked)]
                result_str = ", ".join(selected) if selected else "(none)"
                print(
                    style("* ", fg="green", bold=True)
                    + style(prompt, bold=True)
                    + " "
                    + style(result_str, fg="cyan")
                )
                return selected
            elif key == "escape":
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                print(
                    style("? ", fg="cyan", bold=True)
                    + style(prompt, bold=True)
                    + style(" (cancelled)", dim=True)
                )
                return []

            # Redraw
            for _ in range(len(options)):
                move_up(1)
                clear_line()
    finally:
        show_cursor()


def confirm(prompt, default=True):
    """
    Yes/no confirmation prompt.

    Args:
        prompt: Question text
        default: Default value if enter is pressed

    Returns:
        Boolean
    """
    hint = "Y/n" if default else "y/N"
    sys.stdout.write(
        style("? ", fg="cyan", bold=True)
        + style(prompt, bold=True)
        + " "
        + style("(" + hint + ") ", dim=True)
    )
    sys.stdout.flush()

    while True:
        try:
            key = _read_key()
        except KeyboardInterrupt:
            print(style("(cancelled)", dim=True))
            sys.exit(130)

        if key == "y":
            print(style("Yes", fg="green"))
            return True
        elif key == "n":
            print(style("No", fg="red"))
            return False
        elif key == "enter":
            if default:
                print(style("Yes", fg="green"))
            else:
                print(style("No", fg="red"))
            return default
        elif key == "escape":
            print(style("(cancelled)", dim=True))
            return None


def prompt(message, default=None, validator=None):
    """
    Text input prompt.

    Args:
        message: Prompt message
        default: Default value
        validator: Optional function to validate input (returns True/error message)

    Returns:
        Entered text
    """
    default_hint = ""
    if default is not None:
        default_hint = style(" (" + str(default) + ")", dim=True)

    sys.stdout.write(
        style("? ", fg="cyan", bold=True)
        + style(message, bold=True)
        + default_hint
        + " "
    )
    sys.stdout.flush()

    buffer = ""

    while True:
        try:
            key = _read_key()
        except KeyboardInterrupt:
            print(style(" (cancelled)", dim=True))
            sys.exit(130)

        if key == "enter":
            print()
            result = buffer if buffer else default

            if validator:
                valid = validator(result)
                if valid is not True:
                    error_msg = valid if isinstance(valid, str) else "Invalid input"
                    print(style("  x " + error_msg, fg="red"))
                    sys.stdout.write(
                        style("? ", fg="cyan", bold=True)
                        + style(message, bold=True)
                        + default_hint
                        + " "
                        + buffer
                    )
                    sys.stdout.flush()
                    continue

            # Reprint with checkmark
            move_up(1)
            clear_line()
            print(
                style("* ", fg="green", bold=True)
                + style(message, bold=True)
                + " "
                + style(str(result), fg="cyan")
            )
            return result

        elif key == "backspace":
            if buffer:
                buffer = buffer[:-1]
                sys.stdout.write("\b \b")
                sys.stdout.flush()

        elif key == "escape":
            print(style("(cancelled)", dim=True))
            return None

        elif (
            isinstance(key, str) and len(key) == 1 and ord(key) >= 32 and ord(key) < 127
        ):
            buffer += key
            sys.stdout.write(key)
            sys.stdout.flush()


def password(message):
    """
    Password input (hidden).

    Args:
        message: Prompt message

    Returns:
        Entered password
    """
    sys.stdout.write(
        style("? ", fg="cyan", bold=True) + style(message, bold=True) + " "
    )
    sys.stdout.flush()

    buffer = ""

    while True:
        try:
            key = _read_key()
        except KeyboardInterrupt:
            print(style(" (cancelled)", dim=True))
            sys.exit(130)

        if key == "enter":
            print()
            move_up(1)
            clear_line()
            hidden = "*" * len(buffer) if buffer else "(empty)"
            print(
                style("* ", fg="green", bold=True)
                + style(message, bold=True)
                + " "
                + style(hidden, dim=True)
            )
            return buffer

        elif key == "backspace":
            if buffer:
                buffer = buffer[:-1]
                sys.stdout.write("\b \b")
                sys.stdout.flush()

        elif key == "escape":
            print(style(" (cancelled)", dim=True))
            return None

        elif isinstance(key, str) and len(key) == 1:
            buffer += key
            sys.stdout.write("*")
            sys.stdout.flush()
