"""
Simplified typing module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

The typing module provides type hints for Python code.
In ucharm, typing is implemented as no-ops for MicroPython compatibility.

Based on CPython's Lib/test/test_typing.py
"""

import typing
import sys

# Test tracking
_passed = 0
_failed = 0
_skipped = 0
_errors = []


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


# ============================================================================
# Basic type aliases exist
# ============================================================================

print("\n=== Basic type aliases ===")

test("Any exists", hasattr(typing, "Any"))
test("Optional exists", hasattr(typing, "Optional"))
test("Union exists", hasattr(typing, "Union"))
test("List exists", hasattr(typing, "List"))
test("Dict exists", hasattr(typing, "Dict"))
test("Set exists", hasattr(typing, "Set"))
test("Tuple exists", hasattr(typing, "Tuple"))
test("Callable exists", hasattr(typing, "Callable"))

# ============================================================================
# Generic types exist
# ============================================================================

print("\n=== Generic types ===")

test("Generic exists", hasattr(typing, "Generic"))
test("TypeVar exists", hasattr(typing, "TypeVar"))
test("Sequence exists", hasattr(typing, "Sequence"))
test("Mapping exists", hasattr(typing, "Mapping"))
test("Iterable exists", hasattr(typing, "Iterable"))
test("Iterator exists", hasattr(typing, "Iterator"))

# ============================================================================
# Special forms exist
# ============================================================================

print("\n=== Special forms ===")

test("ClassVar exists", hasattr(typing, "ClassVar"))
test("Final exists", hasattr(typing, "Final"))
test("Literal exists", hasattr(typing, "Literal"))
test("Annotated exists", hasattr(typing, "Annotated"))
test("NoReturn exists", hasattr(typing, "NoReturn"))
test("Never exists", hasattr(typing, "Never"))

# ============================================================================
# TypeVar basic usage
# ============================================================================

print("\n=== TypeVar usage ===")

if hasattr(typing, "TypeVar"):
    # Creating TypeVars should work (even if they return None as no-ops)
    try:
        T = typing.TypeVar("T")
        # In ucharm, TypeVar returns None (no-op), in CPython it returns a TypeVar object
        # Both are acceptable behaviors
        test("TypeVar callable", callable(typing.TypeVar))
    except Exception as e:
        test("TypeVar callable", False)
else:
    skip("TypeVar callable", "TypeVar not available")

# ============================================================================
# Optional and Union
# ============================================================================

print("\n=== Optional and Union ===")

# In ucharm, typing types are None (no-ops for MicroPython compatibility)
# In CPython, they are actual type objects
# Both are acceptable - we just test they exist (which we already did above)
test("Optional in typing", "Optional" in dir(typing))
test("Union in typing", "Union" in dir(typing))

# ============================================================================
# Protocol and runtime_checkable
# ============================================================================

print("\n=== Protocol ===")

test("Protocol exists", hasattr(typing, "Protocol"))
test("runtime_checkable exists", hasattr(typing, "runtime_checkable"))

# ============================================================================
# Async types
# ============================================================================

print("\n=== Async types ===")

test("Awaitable exists", hasattr(typing, "Awaitable"))
test("Coroutine exists", hasattr(typing, "Coroutine"))
test("AsyncGenerator exists", hasattr(typing, "AsyncGenerator"))
test("AsyncIterator exists", hasattr(typing, "AsyncIterator"))
test("AsyncIterable exists", hasattr(typing, "AsyncIterable"))

# ============================================================================
# IO types
# ============================================================================

print("\n=== IO types ===")

test("IO exists", hasattr(typing, "IO"))
test("TextIO exists", hasattr(typing, "TextIO"))
test("BinaryIO exists", hasattr(typing, "BinaryIO"))

# ============================================================================
# Utility functions
# ============================================================================

print("\n=== Utility functions ===")

test("cast exists", hasattr(typing, "cast"))
test("overload exists", hasattr(typing, "overload"))
test("final exists", hasattr(typing, "final"))
test("no_type_check exists", hasattr(typing, "no_type_check"))

# Test cast (should work as identity in runtime)
if hasattr(typing, "cast"):
    try:
        result = typing.cast(int, "hello")
        test("cast returns value", result == "hello")  # cast is no-op at runtime
    except Exception:
        test("cast returns value", False)
else:
    skip("cast returns value", "cast not available")

# ============================================================================
# TYPE_CHECKING constant
# ============================================================================

print("\n=== TYPE_CHECKING ===")

test("TYPE_CHECKING exists", hasattr(typing, "TYPE_CHECKING"))
if hasattr(typing, "TYPE_CHECKING"):
    test("TYPE_CHECKING is False at runtime", typing.TYPE_CHECKING == False)
else:
    skip("TYPE_CHECKING is False at runtime", "TYPE_CHECKING not available")

# ============================================================================
# get_args and get_origin
# ============================================================================

print("\n=== Type introspection ===")

test("get_args exists", hasattr(typing, "get_args"))
test("get_origin exists", hasattr(typing, "get_origin"))
test("get_type_hints exists", hasattr(typing, "get_type_hints"))

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
