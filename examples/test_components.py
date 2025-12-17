#!/usr/bin/env python3
"""Test script for UI components - used by e2e tests."""

import sys

sys.path.insert(0, ".")

from ucharm.components import box, error, info, progress, rule, success, warning
from ucharm.style import style
from ucharm.table import table

# Test box
print("=== BOX TEST ===")
box("Hello World", title="Test Box")

# Test rule
print("\n=== RULE TEST ===")
rule("Section Title")

# Test status messages
print("\n=== STATUS TEST ===")
success("This is success")
error("This is error")
warning("This is warning")
info("This is info")

# Test styled text
print("\n=== STYLE TEST ===")
print(style("Bold text", bold=True))
print(style("Red text", fg="red"))
print(style("Combined", fg="cyan", bold=True))

# Test table
print("\n=== TABLE TEST ===")
table([["Alice", "25"], ["Bob", "30"]], headers=["Name", "Age"])

# Test progress (static)
print("\n=== PROGRESS TEST ===")
progress(50, 100, width=20, label="Loading")
print()  # newline after progress

print("\n=== ALL TESTS COMPLETE ===")
