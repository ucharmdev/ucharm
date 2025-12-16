#!/usr/bin/env micropython
"""Debug key input"""

import sys

sys.path.insert(0, "..")

import termios
import os


def read_key():
    """Read a keypress, handling escape sequences."""
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
            # Set non-blocking to read rest of escape sequence
            import ffi

            libc = ffi.open("libc.dylib")

            # Use fcntl to set non-blocking
            fcntl_func = libc.func("i", "fcntl", "iii")
            F_GETFL = 3
            F_SETFL = 4
            O_NONBLOCK = 0x0004

            flags = fcntl_func(fd, F_GETFL, 0)
            fcntl_func(fd, F_SETFL, flags | O_NONBLOCK)

            seq = ch
            try:
                for _ in range(5):
                    try:
                        c = sys.stdin.read(1)
                        if c:
                            seq += c
                    except:
                        break
            finally:
                # Restore blocking mode
                fcntl_func(fd, F_SETFL, flags)

            return seq

        return ch
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, old)


print("Press keys to see their codes. Ctrl+C to quit.")
print()

try:
    while True:
        key = read_key()
        codes = [ord(c) for c in key]

        print("Key:", repr(key), "Codes:", codes, end="")

        # Identify common sequences
        if key == "\x1b[A":
            print(" = UP")
        elif key == "\x1b[B":
            print(" = DOWN")
        elif key == "\x1b[C":
            print(" = RIGHT")
        elif key == "\x1b[D":
            print(" = LEFT")
        elif key == "\r":
            print(" = ENTER")
        elif key == " ":
            print(" = SPACE")
        elif key == "j":
            print(" = j (vim down)")
        elif key == "k":
            print(" = k (vim up)")
        else:
            print()

except KeyboardInterrupt:
    print("\nBye!")
