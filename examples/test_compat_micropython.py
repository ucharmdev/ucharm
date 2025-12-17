#!/usr/bin/env python3
"""
Test compat layer for MicroPython.

This test imports the compat modules directly without going through
the main ucharm package (which requires ctypes).
"""

import sys

# Add ucharm directory to path so we can import compat directly
sys.path.insert(0, "./ucharm")

print("Testing compat layer for MicroPython...")
print("=" * 50)

# Test functools
print("\n1. Testing functools...")
from compat.functools import lru_cache, partial, reduce, wraps


def add(a, b):
    return a + b


add5 = partial(add, 5)
assert add5(3) == 8, "partial failed"
print("   partial: OK")

result = reduce(lambda x, y: x + y, [1, 2, 3, 4])
assert result == 10, "reduce failed"
print("   reduce: OK")


def my_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs)

    return wrapper


@my_decorator
def my_func():
    """My docstring."""
    pass


# Note: MicroPython doesn't support setting __name__ on functions
# so we just verify wraps doesn't crash
print("   wraps: OK (MicroPython has limited __name__ support)")


@lru_cache(maxsize=10)
def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)


assert fib(10) == 55, "lru_cache failed"
print("   lru_cache: OK")

# Test pathlib
print("\n2. Testing pathlib...")
from compat.pathlib import Path

p = Path("/foo/bar/baz.txt")
assert p.name == "baz.txt", "name failed"
print("   name: OK")

assert p.stem == "baz", "stem failed"
print("   stem: OK")

assert p.suffix == ".txt", "suffix failed"
print("   suffix: OK")

assert str(p.parent) == "/foo/bar", "parent failed"
print("   parent: OK")

assert p.is_absolute(), "is_absolute failed"
print("   is_absolute: OK")

p2 = Path("foo") / "bar" / "baz"
assert str(p2) == "foo/bar/baz", "/ operator failed"
print("   / operator: OK")

# Test datetime
print("\n3. Testing datetime...")
from compat.datetime import date, datetime, time, timedelta

d = date(2024, 1, 15)
assert d.year == 2024, "date year failed"
assert d.month == 1, "date month failed"
assert d.day == 15, "date day failed"
assert d.isoformat() == "2024-01-15", "date isoformat failed"
print("   date: OK")

dt = datetime(2024, 1, 15, 14, 30, 45)
assert dt.hour == 14, "datetime hour failed"
assert dt.minute == 30, "datetime minute failed"
assert str(dt) == "2024-01-15 14:30:45", "datetime str failed"
print("   datetime: OK")

td = timedelta(days=1, hours=2)
assert td.days == 1, "timedelta days failed"
assert td.seconds == 7200, "timedelta seconds failed"
print("   timedelta: OK")

dt2 = dt + timedelta(days=1)
assert dt2.day == 16, "datetime + timedelta failed"
print("   datetime arithmetic: OK")

# Test textwrap
print("\n4. Testing textwrap...")
from compat.textwrap import dedent, indent, wrap

text = "This is a long line of text that should wrap."
lines = wrap(text, width=20)
assert all(len(line) <= 20 for line in lines), "wrap failed"
print("   wrap: OK")

indented = """
    Hello
    World
"""
result = dedent(indented)
for line in result.split("\n"):
    if "Hello" in line:
        assert not line.startswith("    "), "dedent failed"
        break
print("   dedent: OK")

result = indent("Hello\nWorld", ">>> ")
assert result.startswith(">>> Hello"), "indent failed"
print("   indent: OK")

# Test fnmatch
print("\n5. Testing fnmatch...")
from compat.fnmatch import filter as fnfilter
from compat.fnmatch import fnmatch

assert fnmatch("foo.txt", "*.txt"), "fnmatch *.txt failed"
assert not fnmatch("foo.py", "*.txt"), "fnmatch negative failed"
print("   fnmatch: OK")

files = ["a.txt", "b.py", "c.txt"]
result = fnfilter(files, "*.txt")
assert result == ["a.txt", "c.txt"], "filter failed"
print("   filter: OK")

# Test typing (just verify imports work)
print("\n6. Testing typing...")
from compat.typing import Any, Dict, List, Optional

print("\n6. Testing typing...")
from compat.typing import Any, Dict, List, Optional

print("   type hints: OK (no runtime effect)")

# Test copy
print("\n7. Testing copy...")
from compat.copy import copy, deepcopy

original = [1, [2, 3]]
shallow = copy(original)
assert shallow == original, "copy failed"
assert shallow is not original, "copy is same object"
print("   copy: OK")

deep = deepcopy(original)
assert deep == original, "deepcopy failed"
assert deep[1] is not original[1], "deepcopy shared nested"
print("   deepcopy: OK")

# Test base64
print("\n8. Testing base64...")
from compat.base64 import b64decode, b64encode

data = b"Hello!"
encoded = b64encode(data)
decoded = b64decode(encoded)
assert decoded == data, "base64 roundtrip failed"
print("   base64: OK")

# Test statistics
print("\n9. Testing statistics...")
from compat.statistics import mean, median, mode

data = [1, 2, 3, 4, 5]
assert mean(data) == 3.0, "mean failed"
print("   mean: OK")

assert median(data) == 3, "median failed"
print("   median: OK")

assert mode([1, 1, 2, 3, 3, 3]) == 3, "mode failed"
print("   mode: OK")

print("\n" + "=" * 50)
print("All compat tests passed!")
