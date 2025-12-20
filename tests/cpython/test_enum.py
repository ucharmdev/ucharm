"""
Simplified enum module tests for ucharm compatibility testing.
Works on both CPython and pocketpy-ucharm.

Based on CPython's Lib/test/test_enum.py
"""

import sys

# Test tracking
_passed = 0
_failed = 0
_errors = []
_skipped = 0


def test(name, condition):
    global _passed, _failed, _errors
    if condition:
        _passed += 1
        print(f"  PASS: {name}")
    else:
        _failed += 1
        _errors.append(name)
        print(f"  FAIL: {name}")


def skip(name, reason):
    global _skipped
    _skipped += 1
    print(f"  SKIP: {name} ({reason})")


# Try to import enum
try:
    from enum import Enum, IntEnum

    HAS_ENUM = True
except ImportError:
    HAS_ENUM = False
    print("SKIP: enum module not available")

if HAS_ENUM:
    # ============================================================================
    # Basic Enum creation
    # ============================================================================

    print("\n=== Basic Enum creation ===")

    class Color(Enum):
        RED = 1
        GREEN = 2
        BLUE = 3

    test("Enum class created", Color is not None)
    test("RED member exists", hasattr(Color, "RED"))
    test("GREEN member exists", hasattr(Color, "GREEN"))
    test("BLUE member exists", hasattr(Color, "BLUE"))

    # ============================================================================
    # Accessing members
    # ============================================================================

    print("\n=== Accessing members ===")

    test("access by name", Color.RED.name == "RED")
    test("access by value", Color.RED.value == 1)
    test("GREEN name", Color.GREEN.name == "GREEN")
    test("GREEN value", Color.GREEN.value == 2)

    # ============================================================================
    # Comparison
    # ============================================================================

    print("\n=== Comparison ===")

    test("same member equal", Color.RED == Color.RED)
    test("different members not equal", Color.RED != Color.GREEN)
    test("identity same", Color.RED is Color.RED)

    # ============================================================================
    # Iteration
    # ============================================================================

    print("\n=== Iteration ===")

    members = list(Color)
    test("iteration works", len(members) == 3)
    test("RED in iteration", Color.RED in members)
    test("GREEN in iteration", Color.GREEN in members)
    test("BLUE in iteration", Color.BLUE in members)

    # ============================================================================
    # IntEnum
    # ============================================================================

    print("\n=== IntEnum ===")

    class Priority(IntEnum):
        LOW = 1
        MEDIUM = 2
        HIGH = 3

    test("IntEnum created", Priority is not None)
    test("IntEnum value is int", isinstance(Priority.LOW.value, int))
    test("IntEnum comparable to int", Priority.LOW == 1)
    test("IntEnum arithmetic", Priority.LOW + 1 == 2)

    # ============================================================================
    # Using enums in dicts
    # ============================================================================

    print("\n=== Using enums in dicts ===")

    color_names = {
        Color.RED: "red color",
        Color.GREEN: "green color",
        Color.BLUE: "blue color",
    }

    test("enum as dict key", color_names[Color.RED] == "red color")
    test("enum key lookup", Color.GREEN in color_names)

    # ============================================================================
    # Summary
    # ============================================================================

    print("\n" + "=" * 50)
    print(f"Results: {_passed} passed, {_failed} failed, {_skipped} skipped")
    if _errors:
        print("Failed tests:")
        for e in _errors:
            print(f"  - {e}")
        sys.exit(1)
    else:
        print("All tests passed!")
