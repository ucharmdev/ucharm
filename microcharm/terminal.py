# microcharm/terminal.py - Terminal utilities
import sys

# ANSI escape sequences
ESC = "\033"
CSI = ESC + "["


def get_size():
    """Get terminal size (cols, rows). Returns (80, 24) as fallback."""
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
    sys.stdout.write(CSI + "2J" + CSI + "H")
    sys.stdout.flush()


def hide_cursor():
    """Hide the terminal cursor."""
    sys.stdout.write(CSI + "?25l")
    sys.stdout.flush()


def show_cursor():
    """Show the terminal cursor."""
    sys.stdout.write(CSI + "?25h")
    sys.stdout.flush()


def move_cursor(x, y):
    """Move cursor to position (1-indexed)."""
    sys.stdout.write(CSI + str(y) + ";" + str(x) + "H")
    sys.stdout.flush()


def move_up(n=1):
    """Move cursor up n lines."""
    sys.stdout.write(CSI + str(n) + "A")
    sys.stdout.flush()


def move_down(n=1):
    """Move cursor down n lines."""
    sys.stdout.write(CSI + str(n) + "B")
    sys.stdout.flush()


def clear_line():
    """Clear current line."""
    sys.stdout.write("\r" + CSI + "K")
    sys.stdout.flush()
