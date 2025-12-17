#!/usr/bin/env python3
"""
Test suite for functools module - compares μcharm native vs CPython implementation.

Run with:
  python3 test_functools.py          # Test CPython implementation
  micropython test_functools.py      # Test μcharm implementation
"""

import sys
import time

# Detect runtime
IS_MICROPYTHON = sys.implementation.name == "micropython"
RUNTIME = "μcharm" if IS_MICROPYTHON else "CPython"

from functools import reduce

if IS_MICROPYTHON:
    from functools import cmp_to_key, partial
else:
    from functools import cmp_to_key, partial


def test_reduce_sum():
    """Test reduce with sum operation"""
    result = reduce(lambda x, y: x + y, [1, 2, 3, 4, 5])
    assert result == 15, f"Expected 15, got {result}"
    print(f"  [PASS] reduce sum: {result}")


def test_reduce_product():
    """Test reduce with product operation"""
    result = reduce(lambda x, y: x * y, [1, 2, 3, 4, 5])
    assert result == 120, f"Expected 120, got {result}"
    print(f"  [PASS] reduce product: {result}")


def test_reduce_initial():
    """Test reduce with initial value"""
    result = reduce(lambda x, y: x + y, [1, 2, 3], 10)
    assert result == 16, f"Expected 16, got {result}"
    print(f"  [PASS] reduce with initial: {result}")


def test_reduce_single():
    """Test reduce with single element"""
    result = reduce(lambda x, y: x + y, [42])
    assert result == 42, f"Expected 42, got {result}"
    print(f"  [PASS] reduce single element: {result}")


def test_reduce_empty_with_initial():
    """Test reduce with empty sequence and initial value"""
    result = reduce(lambda x, y: x + y, [], 100)
    assert result == 100, f"Expected 100, got {result}"
    print(f"  [PASS] reduce empty with initial: {result}")


def test_reduce_strings():
    """Test reduce with string concatenation"""
    result = reduce(lambda x, y: x + y, ["a", "b", "c"])
    assert result == "abc", f"Expected 'abc', got {result}"
    print(f"  [PASS] reduce strings: {result}")


def test_reduce_max():
    """Test reduce to find maximum"""
    result = reduce(lambda x, y: x if x > y else y, [3, 1, 4, 1, 5, 9, 2, 6])
    assert result == 9, f"Expected 9, got {result}"
    print(f"  [PASS] reduce max: {result}")


def test_partial_basic():
    """Test basic partial function"""

    def add(x, y):
        return x + y

    add10 = partial(add, 10)
    result = add10(5)
    assert result == 15, f"Expected 15, got {result}"
    print(f"  [PASS] partial basic: add10(5) = {result}")


def test_partial_multiple_args():
    """Test partial with multiple bound args"""

    def multiply(x, y, z):
        return x * y * z

    mult_2_3 = partial(multiply, 2, 3)
    result = mult_2_3(4)
    assert result == 24, f"Expected 24, got {result}"
    print(f"  [PASS] partial multiple args: mult_2_3(4) = {result}")


def test_partial_no_args():
    """Test partial with no additional args"""

    def greet():
        return "hello"

    p = partial(greet)
    result = p()
    assert result == "hello", f"Expected 'hello', got {result}"
    print(f"  [PASS] partial no args: {result}")


def test_partial_attributes():
    """Test partial object attributes"""

    def add(x, y):
        return x + y

    p = partial(add, 10)

    # Check func attribute
    assert p.func == add, "func attribute mismatch"

    # Check args attribute
    assert p.args == (10,), f"args mismatch: {p.args}"

    print(
        f"  [PASS] partial attributes: func={p.func.__name__ if hasattr(p.func, '__name__') else 'ok'}, args={p.args}"
    )


def test_cmp_to_key_basic():
    """Test cmp_to_key with sorting"""

    def compare(a, b):
        return a - b

    data = [3, 1, 4, 1, 5, 9, 2, 6]
    result = sorted(data, key=cmp_to_key(compare))
    expected = [1, 1, 2, 3, 4, 5, 6, 9]
    assert result == expected, f"Expected {expected}, got {result}"
    print(f"  [PASS] cmp_to_key basic sort: {result}")


def test_cmp_to_key_reverse():
    """Test cmp_to_key with reverse comparison"""

    def compare_reverse(a, b):
        return b - a

    data = [3, 1, 4, 1, 5, 9, 2, 6]
    result = sorted(data, key=cmp_to_key(compare_reverse))
    expected = [9, 6, 5, 4, 3, 2, 1, 1]
    assert result == expected, f"Expected {expected}, got {result}"
    print(f"  [PASS] cmp_to_key reverse: {result}")


def test_cmp_to_key_strings():
    """Test cmp_to_key with string comparison"""

    def compare_len(a, b):
        return len(a) - len(b)

    data = ["apple", "pie", "strawberry", "a"]
    result = sorted(data, key=cmp_to_key(compare_len))
    expected = ["a", "pie", "apple", "strawberry"]
    assert result == expected, f"Expected {expected}, got {result}"
    print(f"  [PASS] cmp_to_key strings by length: {result}")


# Performance benchmarks
def benchmark_reduce():
    """Benchmark reduce operation"""
    data = list(range(1000))

    start = time.time()
    iterations = 1000

    for _ in range(iterations):
        reduce(lambda x, y: x + y, data)

    elapsed = time.time() - start
    ops_per_sec = iterations / elapsed

    print(
        f"  Reduce (1000 elements): {iterations} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec"
    )
    return elapsed


def benchmark_partial():
    """Benchmark partial function calls"""

    def add(x, y):
        return x + y

    add10 = partial(add, 10)

    start = time.time()
    iterations = 10000

    for i in range(iterations):
        add10(i)

    elapsed = time.time() - start
    ops_per_sec = iterations / elapsed

    print(
        f"  Partial calls: {iterations} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec"
    )
    return elapsed


def run_tests():
    print(f"\n=== Functools Tests ({RUNTIME}) ===\n")

    print("reduce() tests:")
    test_reduce_sum()
    test_reduce_product()
    test_reduce_initial()
    test_reduce_single()
    test_reduce_empty_with_initial()
    test_reduce_strings()
    test_reduce_max()

    print("\npartial() tests:")
    test_partial_basic()
    test_partial_multiple_args()
    test_partial_no_args()
    test_partial_attributes()

    print("\ncmp_to_key() tests:")
    test_cmp_to_key_basic()
    test_cmp_to_key_reverse()
    test_cmp_to_key_strings()

    print(f"\nAll tests passed!")

    print(f"\nPerformance benchmarks:")
    benchmark_reduce()
    benchmark_partial()


if __name__ == "__main__":
    run_tests()
