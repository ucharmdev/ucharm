# microcharm/terminal.py - Terminal utilities
import sys

# Try to use native term module (much faster)
try:
    import term as _term

    _HAS_NATIVE = True
except ImportError:
    _term = None
    _HAS_NATIVE = False

# ANSI escape sequences (fallback)
ESC = "\033"
CSI = ESC + "["


def get_size():
    """Get terminal size (cols, rows). Returns (80, 24) as fallback."""
    # Use native module if available
    if _HAS_NATIVE:
        return _term.size()

    # Try environment variables first
    import os

    try:
        cols = int(os.getenv("COLUMNS", 0))
        rows = int(os.getenv("LINES", 0))
        if cols and rows:
            return (cols, rows)
    except:
        pass

    # Try ANSI cursor position trick
    # Save cursor, move to 999,999, query position, restore
    try:
        import termios

        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            new = old[:]
            new[3] = new[3] & ~termios.ECHO & ~termios.ICANON
            termios.tcsetattr(fd, termios.TCSADRAIN, new)

            # Save cursor, move far, query position
            sys.stdout.write(CSI + "s" + CSI + "999;999H" + CSI + "6n")
            sys.stdout.flush()

            # Read response: ESC [ rows ; cols R
            response = ""
            while True:
                ch = sys.stdin.read(1)
                response += ch
                if ch == "R":
                    break

            # Restore cursor
            sys.stdout.write(CSI + "u")
            sys.stdout.flush()

            # Parse response
            if response.startswith(ESC + "[") and response.endswith("R"):
                parts = response[2:-1].split(";")
                rows, cols = int(parts[0]), int(parts[1])
                return (cols, rows)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
    except:
        pass

    # Fallback
    return (80, 24)


def clear():
    """Clear the terminal screen."""
    if _HAS_NATIVE:
        _term.clear()
    else:
        sys.stdout.write(CSI + "2J" + CSI + "H")
        sys.stdout.flush()


def hide_cursor():
    """Hide the terminal cursor."""
    if _HAS_NATIVE:
        _term.hide_cursor()
    else:
        sys.stdout.write(CSI + "?25l")
        sys.stdout.flush()


def show_cursor():
    """Show the terminal cursor."""
    if _HAS_NATIVE:
        _term.show_cursor()
    else:
        sys.stdout.write(CSI + "?25h")
        sys.stdout.flush()


def move_cursor(x, y):
    """Move cursor to position (1-indexed)."""
    if _HAS_NATIVE:
        # Native uses 0-indexed, convert
        _term.cursor_pos(x - 1, y - 1)
    else:
        sys.stdout.write(CSI + str(y) + ";" + str(x) + "H")
        sys.stdout.flush()


def move_up(n=1):
    """Move cursor up n lines."""
    if _HAS_NATIVE:
        _term.cursor_up(n)
    else:
        sys.stdout.write(CSI + str(n) + "A")
        sys.stdout.flush()


def move_down(n=1):
    """Move cursor down n lines."""
    if _HAS_NATIVE:
        _term.cursor_down(n)
    else:
        sys.stdout.write(CSI + str(n) + "B")
        sys.stdout.flush()


def clear_line():
    """Clear current line."""
    if _HAS_NATIVE:
        _term.clear_line()
    else:
        sys.stdout.write("\r" + CSI + "K")
        sys.stdout.flush()


def is_tty():
    """Check if stdout is a TTY."""
    if _HAS_NATIVE:
        return _term.is_tty()
    try:
        return sys.stdout.isatty()
    except:
        return False


def write(text):
    """Write text directly to terminal (unbuffered)."""
    if _HAS_NATIVE:
        _term.write(text)
    else:
        sys.stdout.write(text)
        sys.stdout.flush()
