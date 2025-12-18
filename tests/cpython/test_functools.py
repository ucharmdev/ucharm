"""
Simplified functools module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_functools.py
"""

import functools

# Test tracking
_passed = 0
_failed = 0
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


# ============================================================================
# functools.reduce() tests
# ============================================================================

print("\n=== functools.reduce() tests ===")

# Basic reduction
test("reduce add", functools.reduce(lambda x, y: x + y, [1, 2, 3, 4]) == 10)
test("reduce multiply", functools.reduce(lambda x, y: x * y, [1, 2, 3, 4]) == 24)
test("reduce with initial", functools.reduce(lambda x, y: x + y, [1, 2, 3], 10) == 16)

# Single element
test("reduce single", functools.reduce(lambda x, y: x + y, [5]) == 5)
test("reduce single with initial", functools.reduce(lambda x, y: x + y, [5], 10) == 15)

# Empty with initial
test("reduce empty with initial", functools.reduce(lambda x, y: x + y, [], 42) == 42)

# String concatenation
test("reduce strings", functools.reduce(lambda x, y: x + y, ["a", "b", "c"]) == "abc")

# Max/min
test(
    "reduce max", functools.reduce(lambda x, y: x if x > y else y, [3, 1, 4, 1, 5]) == 5
)
test(
    "reduce min", functools.reduce(lambda x, y: x if x < y else y, [3, 1, 4, 1, 5]) == 1
)


# ============================================================================
# functools.partial() tests
# ============================================================================

print("\n=== functools.partial() tests ===")


def add(a, b, c=0):
    return a + b + c


# Basic partial
p = functools.partial(add, 1)
test("partial basic", p(2) == 3)
test("partial with remaining", p(2, c=10) == 13)

# Partial with multiple args
p2 = functools.partial(add, 1, 2)
test("partial two args", p2() == 3)
test("partial two args with kwarg", p2(c=5) == 8)

# Partial with keyword
p3 = functools.partial(add, c=10)
test("partial with kwarg", p3(1, 2) == 13)

# Nested partial
p4 = functools.partial(functools.partial(add, 1), 2)
test("nested partial", p4() == 3)

# Partial attributes
test("partial.func", p.func == add)
test("partial.args", p.args == (1,))
test("partial.keywords", p.keywords == {})


# ============================================================================
# functools.cmp_to_key() tests
# ============================================================================

print("\n=== functools.cmp_to_key() tests ===")


def compare(a, b):
    if a < b:
        return -1
    elif a > b:
        return 1
    return 0


# Sort with cmp_to_key
nums = [3, 1, 4, 1, 5, 9, 2, 6]
sorted_nums = sorted(nums, key=functools.cmp_to_key(compare))
test("cmp_to_key ascending", sorted_nums == [1, 1, 2, 3, 4, 5, 6, 9])


# Reverse comparison
def reverse_compare(a, b):
    return -compare(a, b)


sorted_desc = sorted(nums, key=functools.cmp_to_key(reverse_compare))
test("cmp_to_key descending", sorted_desc == [9, 6, 5, 4, 3, 2, 1, 1])

# String comparison
words = ["banana", "Apple", "cherry"]


def case_insensitive_cmp(a, b):
    return compare(a.lower(), b.lower())


sorted_words = sorted(words, key=functools.cmp_to_key(case_insensitive_cmp))
test("cmp_to_key strings", sorted_words == ["Apple", "banana", "cherry"])


# ============================================================================
# Edge cases
# ============================================================================

print("\n=== Edge cases ===")

# Reduce with error on empty
try:
    functools.reduce(lambda x, y: x + y, [])
    test("reduce empty raises", False)
except TypeError:
    test("reduce empty raises", True)

# Partial called with wrong args
try:
    p = functools.partial(add)
    p()  # Missing required args
    test("partial missing args raises", False)
except TypeError:
    test("partial missing args raises", True)


# ============================================================================
# Summary
# ============================================================================

print("\n" + "=" * 50)
print(f"Results: {_passed} passed, {_failed} failed")
if _errors:
    print("Failed tests:")
    for e in _errors:
        print(f"  - {e}")
    import sys

    sys.exit(1)
else:
    print("All tests passed!")
