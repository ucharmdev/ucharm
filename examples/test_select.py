#!/usr/bin/env python3
"""Test script for select component - used by e2e tests."""

import sys

sys.path.insert(0, ".")

from microcharm.input import select

result = select("Choose a color:", ["Red", "Green", "Blue"])
if result:
    print(f"SELECTED: {result}")
else:
    print("CANCELLED")
