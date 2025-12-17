#!/usr/bin/env python3
"""Test script for multiselect component - used by e2e tests."""

import sys

sys.path.insert(0, ".")

from ucharm.input import multiselect

result = multiselect("Select toppings:", ["Cheese", "Pepperoni", "Mushrooms", "Olives"])
if result:
    print(f"SELECTED: {','.join(result)}")
else:
    print("NONE")
