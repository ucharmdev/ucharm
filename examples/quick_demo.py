#!/usr/bin/env python3
"""Quick demo for README GIF"""

import sys

sys.path.insert(0, "..")

from ucharm import box, select, confirm, success, style

# Welcome box
box("Welcome to μcharm!", title="Hello", border_color="cyan")
print()

# Interactive select
choice = select(
    "What would you like to do?",
    ["Create a new project", "Run tests", "Deploy to production"],
)

if choice:
    print()
    if confirm("Are you sure?"):
        print()
        success(f"Selected: {style(choice, bold=True)}")
