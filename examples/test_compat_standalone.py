#!/usr/bin/env python3
"""
Standalone test for ucharm compat layer.

This script tests the import hooks without importing the full ucharm library,
which allows testing on both CPython and MicroPython.
"""

import sys

# Add parent directory to path for imports
sys.path.insert(0, ".")

# Enable the compat layer FIRST
import ucharm.compat

print("Testing ucharm compat layer (standalone)...")
print(
    "Python implementation:",
    getattr(sys, "implementation", {"name": "unknown"}).name
    if hasattr(sys, "implementation")
    else "micropython",
)
print("=" * 50)

# Test functools
print("\n1. Testing functools...")
from ucharm.compat.functools import lru_cache, partial, reduce, wraps


# Test partial
def add(a, b):
    return a + b


add5 = partial(add, 5)
assert add5(3) == 8, "partial failed"
print("   partial: OK")

# Test reduce
result = reduce(lambda x, y: x + y, [1, 2, 3, 4])
assert result == 10, "reduce failed"
print("   reduce: OK")


# Test wraps
def my_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs)

    return wrapper


@my_decorator
def my_func():
    """My docstring."""
    pass


assert my_func.__name__ == "my_func", "wraps failed"
print("   wraps: OK")


# Test lru_cache
@lru_cache(maxsize=10)
def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)


assert fib(10) == 55, "lru_cache failed"
print("   lru_cache: OK")

# Test pathlib
print("\n2. Testing pathlib...")
from ucharm.compat.pathlib import Path

p = Path("/foo/bar/baz.txt")
assert p.name == "baz.txt", "name failed: " + p.name
print("   name: OK")

assert p.stem == "baz", "stem failed"
print("   stem: OK")

assert p.suffix == ".txt", "suffix failed"
print("   suffix: OK")

assert str(p.parent) == "/foo/bar", "parent failed: " + str(p.parent)
print("   parent: OK")

assert p.is_absolute(), "is_absolute failed"
print("   is_absolute: OK")

p2 = Path("foo") / "bar" / "baz"
assert str(p2) == "foo/bar/baz", "/ operator failed: " + str(p2)
print("   / operator: OK")

# Test datetime
print("\n3. Testing datetime...")
from ucharm.compat.datetime import date, datetime, time, timedelta

# Test date
d = date(2024, 1, 15)
assert d.year == 2024, "date year failed"
assert d.month == 1, "date month failed"
assert d.day == 15, "date day failed"
assert d.isoformat() == "2024-01-15", "date isoformat failed"
print("   date: OK")

# Test datetime
dt = datetime(2024, 1, 15, 14, 30, 45)
assert dt.hour == 14, "datetime hour failed"
assert dt.minute == 30, "datetime minute failed"
assert str(dt) == "2024-01-15 14:30:45", "datetime str failed"
print("   datetime: OK")

# Test timedelta
td = timedelta(days=1, hours=2)
assert td.days == 1, "timedelta days failed"
assert td.seconds == 7200, "timedelta seconds failed"
print("   timedelta: OK")

# Test datetime arithmetic
dt2 = dt + timedelta(days=1)
assert dt2.day == 16, "datetime + timedelta failed"
print("   datetime arithmetic: OK")

# Test textwrap
print("\n4. Testing textwrap...")
from ucharm.compat.textwrap import dedent, fill, indent, wrap

text = (
    "This is a long line of text that should be wrapped to fit within a smaller width."
)
lines = wrap(text, width=30)
assert all(len(line) <= 30 for line in lines), "wrap failed"
print("   wrap: OK")

indented_text = """
    Hello
    World
"""
result = dedent(indented_text)
# After dedent, "Hello" should not have leading spaces
lines = result.split("\n")
hello_line = [l for l in lines if "Hello" in l][0]
assert not hello_line.startswith("    "), "dedent failed"
print("   dedent: OK")

result = indent("Hello\nWorld", ">>> ")
assert result.startswith(">>> Hello"), "indent failed"
print("   indent: OK")

# Test fnmatch
print("\n5. Testing fnmatch...")
from ucharm.compat.fnmatch import filter as fnfilter
from ucharm.compat.fnmatch import fnmatch

assert fnmatch("foo.txt", "*.txt"), "fnmatch *.txt failed"
assert not fnmatch("foo.py", "*.txt"), "fnmatch negative failed"
assert fnmatch("test123", "test???"), "fnmatch ??? failed"
print("   fnmatch: OK")

files = ["a.txt", "b.py", "c.txt", "d.md"]
result = fnfilter(files, "*.txt")
assert result == ["a.txt", "c.txt"], "filter failed"
print("   filter: OK")

# Test typing (should just not raise)
print("\n6. Testing typing...")
from ucharm.compat.typing import Any, Callable, Dict, List, Optional, Union

# Just verify imports work - type hints have no runtime effect
print("   type hints: OK (no runtime effect)")

# Test copy
print("\n7. Testing copy...")
from ucharm.compat.copy import copy, deepcopy

original = [1, [2, 3], {"a": 4}]

shallow = copy(original)
assert shallow == original, "shallow copy failed"
assert shallow is not original, "shallow copy is same object"
assert shallow[1] is original[1], "shallow copy didn't share nested"
print("   copy: OK")

deep = deepcopy(original)
assert deep == original, "deep copy failed"
assert deep[1] is not original[1], "deep copy shared nested"
print("   deepcopy: OK")

# Test base64
print("\n8. Testing base64...")
from ucharm.compat.base64 import (
    b64decode,
    b64encode,
    urlsafe_b64decode,
    urlsafe_b64encode,
)

data = b"Hello, World!"
encoded = b64encode(data)
assert b64decode(encoded) == data, "base64 roundtrip failed"
print("   b64encode/decode: OK")

encoded_safe = urlsafe_b64encode(data)
assert urlsafe_b64decode(encoded_safe) == data, "urlsafe roundtrip failed"
print("   urlsafe_b64encode/decode: OK")

# Test statistics
print("\n9. Testing statistics...")
from ucharm.compat.statistics import mean, median, mode, stdev, variance

data = [1, 2, 3, 4, 5]
assert mean(data) == 3.0, "mean failed"
print("   mean: OK")

assert median(data) == 3, "median failed"
print("   median: OK")

assert mode([1, 1, 2, 3, 3, 3]) == 3, "mode failed"
print("   mode: OK")

v = variance(data)
assert abs(v - 2.5) < 0.001, "variance failed"
print("   variance: OK")

s = stdev(data)
assert abs(s - 1.5811388300841898) < 0.001, "stdev failed"
print("   stdev: OK")

# Summary
print("\n" + "=" * 50)
print("All compat module tests passed!")
