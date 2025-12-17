#!/usr/bin/env python3
"""Test script for prompt component - used by e2e tests."""

import sys

sys.path.insert(0, ".")

from ucharm.input import prompt

result = prompt("Enter your name:")
if result:
    print(f"NAME: {result}")
else:
    print("CANCELLED")
