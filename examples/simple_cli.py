#!/usr/bin/env micropython
"""
Example: A simple CLI tool built with ucharm
"""

import sys

sys.path.insert(0, "..")

from ucharm import (
    style,
    box,
    success,
    error,
    warning,
    info,
    select,
    confirm,
    prompt,
    progress,
)
from ucharm.table import key_value
import time


def cmd_greet(name=None):
    """Greet command"""
    if not name:
        name = prompt("What's your name?", default="World")
    print()
    box(
        "Hello, " + str(name) + "!\nWelcome to ucharm.",
        title="Greeting",
        border_color="cyan",
    )
    print()


def cmd_status():
    """Show system status"""
    print()
    info("Checking system status...")
    print()

    # Fake checks with progress
    checks = [
        ("Database", True),
        ("Cache", True),
        ("API", True),
        ("Queue", False),
    ]

    for name, ok in checks:
        time.sleep(0.3)
        if ok:
            success(name + ": Connected")
        else:
            error(name + ": Disconnected")

    print()
    key_value(
        {
            "Uptime": "3 days, 14 hours",
            "Memory": "245 MB / 512 MB",
            "CPU": "12%",
            "Version": "1.0.0",
        }
    )
    print()


def cmd_process(count=50):
    """Process files"""
    print()
    info("Processing " + str(count) + " files...")
    print()

    for i in range(count + 1):
        progress(i, count, label="  Progress", color="green")
        time.sleep(0.05)

    print()
    success("Processed " + str(count) + " files")
    print()


def show_help():
    """Show help message"""
    print()
    box(
        "Commands:\n"
        "  greet [name]    Greet someone\n"
        "  status          Show system status\n"
        "  process [n]     Process n files\n"
        "  help            Show this help",
        title="Simple CLI - Help",
        border_color="cyan",
    )
    print()


def interactive_mode():
    """Run in interactive mode"""
    print()
    box(
        "Simple CLI Example\nBuilt with ucharm",
        title="Welcome",
        border_color="cyan",
    )
    print()

    cmd = select(
        "What would you like to do?",
        ["Greet someone", "Check status", "Process files", "Exit"],
    )

    if cmd == "Greet someone":
        cmd_greet()
    elif cmd == "Check status":
        cmd_status()
    elif cmd == "Process files":
        cmd_process()
    else:
        print()
        info("Goodbye!")
        print()


def main():
    args = sys.argv[1:]

    if not args:
        interactive_mode()
        return

    cmd = args[0]

    if cmd == "greet":
        name = args[1] if len(args) > 1 else None
        cmd_greet(name)
    elif cmd == "status":
        cmd_status()
    elif cmd == "process":
        count = int(args[1]) if len(args) > 1 else 50
        cmd_process(count)
    elif cmd == "help" or cmd == "--help" or cmd == "-h":
        show_help()
    else:
        error("Unknown command: " + cmd)
        show_help()


if __name__ == "__main__":
    main()
