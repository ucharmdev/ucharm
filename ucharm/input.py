# ucharm/input.py - Interactive input components
"""
Interactive input components for CLI applications.
Uses native Zig via libucharm for rendering.

Test Mode:
    For automated testing, you can provide keystrokes via:

    1. File descriptor 3:
       ./my_app 3< keystrokes.txt
       echo -e "down\\ndown\\nenter" | ./my_app 3<&0

    2. Environment variable:
       MCHARM_TEST_KEYS="down,down,enter" ./my_app

    Key names: up, down, left, right, enter, space, escape, backspace, tab
    Single characters are sent as-is.
"""

import os
import sys

from ._native import ui
from .style import style
from .terminal import clear_line, hide_cursor, move_up, show_cursor

# Try to use native term module for key reading
try:
    import term as _term

    _HAS_NATIVE_TERM = True
except ImportError:
    _term = None
    _HAS_NATIVE_TERM = False

# Test input state
_test_keys = None  # List of keys to send, or None for normal mode
_test_key_index = 0  # Current position in _test_keys


def _init_test_input():
    """Initialize test input from env var or fd 3. Called once on first _read_key."""
    global _test_keys

    # Already initialized?
    if _test_keys is not None:
        return

    # Check environment variable first
    # Use os.getenv() which works in both CPython and MicroPython
    env_keys = os.getenv("MCHARM_TEST_KEYS", "")
    if env_keys:
        # Parse comma-separated key names
        _test_keys = []
        for k in env_keys.split(","):
            k = k.strip()
            if k:
                _test_keys.append(k)
        return

    # Check if fd 3 is open and readable (CPython only - MicroPython lacks os.read)
    if hasattr(os, "read"):
        try:
            # Read all data from fd 3
            data = b""
            while True:
                try:
                    chunk = os.read(3, 4096)
                    if not chunk:
                        break
                    data += chunk
                except:
                    break
            if data:
                # Parse as lines of key names
                _test_keys = []
                for line in data.decode("utf-8").strip().split("\n"):
                    line = line.strip()
                    if line:
                        _test_keys.append(line)
        except OSError:
            # fd 3 not available, normal mode
            pass


def _read_test_key():
    """Read a key from test input. Returns None if no test input available."""
    global _test_keys, _test_key_index

    _init_test_input()

    # Read from pre-parsed key list (env var or fd 3)
    if _test_keys is not None:
        if _test_key_index >= len(_test_keys):
            return None
        key = _test_keys[_test_key_index]
        _test_key_index += 1
        return key

    return None


def _is_test_mode():
    """Check if we're in test mode (env var or fd 3)."""
    _init_test_input()
    return _test_keys is not None


def _read_key(vim_nav=False):
    """Read a keypress, handling escape sequences for special keys.

    In test mode (fd 3 or MCHARM_TEST_KEYS), reads from test input instead.
    """
    # Check for test input first
    test_key = _read_test_key()
    if test_key is not None:
        # Handle vim navigation in test mode too
        if vim_nav:
            if test_key == "j":
                return "down"
            if test_key == "k":
                return "up"
        return test_key

    # If in test mode but no more keys, return None (or could raise)
    if _is_test_mode():
        return None

    # Normal interactive mode
    if _HAS_NATIVE_TERM:
        _term.raw_mode(True)
        try:
            key = _term.read_key()
            if key is None:
                return None
            if key == "ctrl-c":
                raise KeyboardInterrupt()
            if key == " ":
                return "space"
            if vim_nav:
                if key == "j":
                    return "down"
                if key == "k":
                    return "up"
            return key
        finally:
            _term.raw_mode(False)

    # Fallback to pure Python
    import termios

    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        termios.setraw(fd)
        ch = sys.stdin.read(1)

        if ch == "\x03":
            raise KeyboardInterrupt()
        if ch == "\x1b":
            ch2 = sys.stdin.read(1)
            if ch2 == "[":
                ch3 = sys.stdin.read(1)
                key_map = {
                    "A": "up",
                    "B": "down",
                    "C": "right",
                    "D": "left",
                    "H": "home",
                    "F": "end",
                }
                return key_map.get(ch3, "escape")
            return "escape"
        if ch in ("\n", "\r"):
            return "enter"
        if ch in ("\x7f", "\x08"):
            return "backspace"
        if ch == "\t":
            return "tab"
        if ch == " ":
            return "space"
        if vim_nav and ch == "j":
            return "down"
        if vim_nav and ch == "k":
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
    q_sym = ui.prompt_question()
    s_sym = ui.prompt_success()
    sel_sym = ui.select_indicator()

    print(style(q_sym, fg="cyan", bold=True) + style(prompt, bold=True))

    hide_cursor()
    try:
        while True:
            for i, opt in enumerate(options):
                if i == selected:
                    print(
                        "  "
                        + style(sel_sym, fg="cyan")
                        + style(opt, fg="cyan", bold=True)
                    )
                else:
                    print("    " + style(opt, dim=True))

            try:
                key = _read_key(vim_nav=True)
            except KeyboardInterrupt:
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                print(
                    style(q_sym, fg="cyan", bold=True)
                    + style(prompt, bold=True)
                    + style(" (cancelled)", dim=True)
                )
                show_cursor()
                sys.exit(130)

            if key == "up":
                selected = (selected - 1) % len(options)
            elif key == "down":
                selected = (selected + 1) % len(options)
            elif key == "enter":
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                print(
                    style(s_sym, fg="green", bold=True)
                    + style(prompt, bold=True)
                    + " "
                    + style(options[selected], fg="cyan")
                )
                return options[selected]
            elif key == "escape":
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                print(
                    style(q_sym, fg="cyan", bold=True)
                    + style(prompt, bold=True)
                    + style(" (cancelled)", dim=True)
                )
                return None

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
    q_sym = ui.prompt_question()
    s_sym = ui.prompt_success()
    sel_sym = ui.select_indicator()
    cb_on = ui.checkbox_on()
    cb_off = ui.checkbox_off()

    print(
        style(q_sym, fg="cyan", bold=True)
        + style(prompt, bold=True)
        + style(" (space to select, enter to confirm)", dim=True)
    )

    hide_cursor()
    try:
        while True:
            for i, opt in enumerate(options):
                checkbox = (
                    style(cb_on, fg="cyan") if i in checked else style(cb_off, dim=True)
                )
                if i == selected_idx:
                    print(
                        "  "
                        + style(sel_sym, fg="cyan")
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
                    style(q_sym, fg="cyan", bold=True)
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
                for _ in range(len(options)):
                    move_up(1)
                    clear_line()
                move_up(1)
                clear_line()
                selected = [options[i] for i in sorted(checked)]
                result_str = ", ".join(selected) if selected else "(none)"
                print(
                    style(s_sym, fg="green", bold=True)
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
                    style(q_sym, fg="cyan", bold=True)
                    + style(prompt, bold=True)
                    + style(" (cancelled)", dim=True)
                )
                return []

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
    q_sym = ui.prompt_question()
    hint = "Y/n" if default else "y/N"
    sys.stdout.write(
        style(q_sym, fg="cyan", bold=True)
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
            print(style("Yes", fg="green") if default else style("No", fg="red"))
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
    q_sym = ui.prompt_question()
    s_sym = ui.prompt_success()
    default_hint = (
        style(" (" + str(default) + ")", dim=True) if default is not None else ""
    )

    sys.stdout.write(
        style(q_sym, fg="cyan", bold=True)
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
                        style(q_sym, fg="cyan", bold=True)
                        + style(message, bold=True)
                        + default_hint
                        + " "
                        + buffer
                    )
                    sys.stdout.flush()
                    continue

            move_up(1)
            clear_line()
            print(
                style(s_sym, fg="green", bold=True)
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

        elif isinstance(key, str) and len(key) == 1 and 32 <= ord(key) < 127:
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
    q_sym = ui.prompt_question()
    s_sym = ui.prompt_success()

    sys.stdout.write(
        style(q_sym, fg="cyan", bold=True) + style(message, bold=True) + " "
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
                style(s_sym, fg="green", bold=True)
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
