#!/usr/bin/env micropython
"""
microcharm demo - showcasing all features
"""

import sys

sys.path.insert(0, "..")

from microcharm import (
    style,
    box,
    spinner,
    progress,
    rule,
    success,
    error,
    warning,
    info,
    select,
    confirm,
    prompt,
    table,
    Color,
)
from microcharm.table import key_value
import time


def main():
    # Welcome
    print()
    box(
        "microcharm v0.1.0\n"
        + "Beautiful CLIs for MicroPython\n"
        + "Fast startup | Tiny binaries | Python syntax",
        title="Welcome",
        border_color="cyan",
    )
    print()

    # Styling demo
    rule("Styling", color="magenta")
    print()
    print(
        "  "
        + style("Bold", bold=True)
        + "  "
        + style("Dim", dim=True)
        + "  "
        + style("Italic", italic=True)
        + "  "
        + style("Underline", underline=True)
    )
    print()
    print(
        "  "
        + style("Red", fg="red")
        + "  "
        + style("Green", fg="green")
        + "  "
        + style("Blue", fg="blue")
        + "  "
        + style("Yellow", fg="yellow")
        + "  "
        + style("Cyan", fg="cyan")
        + "  "
        + style("Magenta", fg="magenta")
    )
    print()
    print(
        "  "
        + style("RGB Color!", fg="#FF6B6B", bold=True)
        + "  "
        + style("Another!", fg="#4ECDC4")
        + "  "
        + style("And more!", fg="#FFE66D")
    )
    print()

    # Status messages
    rule("Status Messages", color="magenta")
    print()
    success("Operation completed successfully")
    info("Here's some useful information")
    warning("This might need your attention")
    error("Something went wrong")
    print()

    # Progress indicators
    rule("Progress Indicators", color="magenta")
    print()
    spinner("Installing dependencies", duration=1.5)
    spinner("Compiling assets", duration=1)
    print()

    print(style("  Downloading:", bold=True))
    for i in range(101):
        progress(i, 100, label="  ", color="green")
        time.sleep(0.015)
    print()

    # Tables
    rule("Tables", color="magenta")
    print()
    table(
        [
            ["MicroPython", "~5ms", "652KB"],
            ["CPython", "~30ms", "84MB"],
            ["Node.js", "~40ms", "~100MB"],
            ["Go binary", "~2ms", "~10MB"],
        ],
        headers=["Runtime", "Startup", "Size"],
        header_style={"bold": True, "fg": "cyan"},
    )
    print()

    # Key-value display
    key_value(
        {
            "Version": "0.1.0",
            "Platform": "MicroPython",
            "Author": "Your Name",
        }
    )
    print()

    # Boxes
    rule("Box Styles", color="magenta")
    print()
    box("Rounded corners (default)", border="rounded", border_color="cyan")
    box("Square corners", border="square", border_color="green")
    box("Double lines", border="double", border_color="yellow")
    box("Heavy lines", border="heavy", border_color="red")
    print()

    # Interactive demo
    if confirm("Run interactive demo?", default=True):
        print()
        rule("Interactive Input", color="magenta")
        print()

        lang = select(
            "What's your favorite language?",
            ["Python", "Go", "Rust", "JavaScript", "Other"],
        )

        if lang:
            print()
            name = prompt("What's your name?", default="Developer")
            print()

            if name:
                box(
                    f"Hello, {name}!\n"
                    + f"Great choice picking {lang}.\n"
                    + "Happy coding!",
                    title="Summary",
                    border_color="green",
                )

    print()
    success("Demo complete!")
    print()


if __name__ == "__main__":
    main()
