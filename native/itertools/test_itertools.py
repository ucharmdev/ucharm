#!/usr/bin/env python3
"""
Test suite for itertools module - compares μcharm native vs CPython implementation.

Run with:
  python3 test_itertools.py          # Test CPython implementation
  micropython test_itertools.py      # Test μcharm implementation
"""

import sys
import time

# Detect runtime
IS_MICROPYTHON = sys.implementation.name == "micropython"
RUNTIME = "μcharm" if IS_MICROPYTHON else "CPython"

from itertools import (
    accumulate,
    chain,
    count,
    cycle,
    dropwhile,
    islice,
    repeat,
    starmap,
    takewhile,
)


def test_count_basic():
    """Test count with default start and step"""
    result = list(islice(count(), 5))
    assert result == [0, 1, 2, 3, 4], f"Expected [0,1,2,3,4], got {result}"
    print(f"  [PASS] count(): {result}")


def test_count_start():
    """Test count with custom start"""
    result = list(islice(count(10), 5))
    assert result == [10, 11, 12, 13, 14], f"Expected [10..14], got {result}"
    print(f"  [PASS] count(10): {result}")


def test_count_step():
    """Test count with custom step"""
    result = list(islice(count(0, 2), 5))
    assert result == [0, 2, 4, 6, 8], f"Expected [0,2,4,6,8], got {result}"
    print(f"  [PASS] count(0, 2): {result}")


def test_cycle():
    """Test cycle"""
    result = list(islice(cycle([1, 2, 3]), 7))
    assert result == [1, 2, 3, 1, 2, 3, 1], f"Expected [1,2,3,1,2,3,1], got {result}"
    print(f"  [PASS] cycle([1,2,3]): {result}")


def test_repeat_finite():
    """Test repeat with count"""
    result = list(repeat("x", 4))
    assert result == ["x", "x", "x", "x"], f"Expected 4 x's, got {result}"
    print(f"  [PASS] repeat('x', 4): {result}")


def test_repeat_infinite():
    """Test repeat without count (infinite)"""
    result = list(islice(repeat(42), 5))
    assert result == [42, 42, 42, 42, 42], f"Expected 5 42's, got {result}"
    print(f"  [PASS] repeat(42): {result}")


def test_chain():
    """Test chain"""
    result = list(chain([1, 2], [3, 4], [5]))
    assert result == [1, 2, 3, 4, 5], f"Expected [1..5], got {result}"
    print(f"  [PASS] chain([1,2], [3,4], [5]): {result}")


def test_chain_empty():
    """Test chain with empty iterables"""
    result = list(chain([], [1, 2], [], [3]))
    assert result == [1, 2, 3], f"Expected [1,2,3], got {result}"
    print(f"  [PASS] chain with empty: {result}")


def test_islice_stop():
    """Test islice with just stop"""
    result = list(islice(range(10), 5))
    assert result == [0, 1, 2, 3, 4], f"Expected [0..4], got {result}"
    print(f"  [PASS] islice(range(10), 5): {result}")


def test_islice_start_stop():
    """Test islice with start and stop"""
    result = list(islice(range(10), 2, 7))
    assert result == [2, 3, 4, 5, 6], f"Expected [2..6], got {result}"
    print(f"  [PASS] islice(range(10), 2, 7): {result}")


def test_islice_step():
    """Test islice with step"""
    result = list(islice(range(20), 0, 10, 2))
    assert result == [0, 2, 4, 6, 8], f"Expected [0,2,4,6,8], got {result}"
    print(f"  [PASS] islice(range(20), 0, 10, 2): {result}")


def test_takewhile():
    """Test takewhile"""
    result = list(takewhile(lambda x: x < 5, range(10)))
    assert result == [0, 1, 2, 3, 4], f"Expected [0..4], got {result}"
    print(f"  [PASS] takewhile(x < 5): {result}")


def test_dropwhile():
    """Test dropwhile"""
    result = list(dropwhile(lambda x: x < 5, range(10)))
    assert result == [5, 6, 7, 8, 9], f"Expected [5..9], got {result}"
    print(f"  [PASS] dropwhile(x < 5): {result}")


def test_accumulate_sum():
    """Test accumulate with default sum"""
    result = list(accumulate([1, 2, 3, 4]))
    assert result == [1, 3, 6, 10], f"Expected [1,3,6,10], got {result}"
    print(f"  [PASS] accumulate([1,2,3,4]): {result}")


def test_accumulate_product():
    """Test accumulate with multiplication"""
    result = list(accumulate([1, 2, 3, 4], lambda x, y: x * y))
    assert result == [1, 2, 6, 24], f"Expected [1,2,6,24], got {result}"
    print(f"  [PASS] accumulate with multiply: {result}")


def test_starmap():
    """Test starmap"""
    result = list(starmap(lambda x, y: x + y, [(1, 2), (3, 4), (5, 6)]))
    assert result == [3, 7, 11], f"Expected [3,7,11], got {result}"
    print(f"  [PASS] starmap(add, pairs): {result}")


def test_starmap_pow():
    """Test starmap with pow"""
    result = list(starmap(pow, [(2, 3), (3, 2), (10, 2)]))
    assert result == [8, 9, 100], f"Expected [8,9,100], got {result}"
    print(f"  [PASS] starmap(pow): {result}")


# Performance benchmarks
def benchmark_count():
    """Benchmark count iteration"""
    start = time.time()
    iterations = 100

    for _ in range(iterations):
        total = 0
        for i in islice(count(), 1000):
            total += i

    elapsed = time.time() - start
    ops_per_sec = iterations / elapsed

    print(
        f"  count+islice (1000): {iterations} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec"
    )
    return elapsed


def benchmark_chain():
    """Benchmark chain"""
    lists = [[i] * 100 for i in range(10)]

    start = time.time()
    iterations = 1000

    for _ in range(iterations):
        result = list(chain(*lists))

    elapsed = time.time() - start
    ops_per_sec = iterations / elapsed

    print(
        f"  chain (10x100): {iterations} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec"
    )
    return elapsed


def run_tests():
    print(f"\n=== Itertools Tests ({RUNTIME}) ===\n")

    print("count() tests:")
    test_count_basic()
    test_count_start()
    test_count_step()

    print("\ncycle() tests:")
    test_cycle()

    print("\nrepeat() tests:")
    test_repeat_finite()
    test_repeat_infinite()

    print("\nchain() tests:")
    test_chain()
    test_chain_empty()

    print("\nislice() tests:")
    test_islice_stop()
    test_islice_start_stop()
    test_islice_step()

    print("\ntakewhile/dropwhile tests:")
    test_takewhile()
    test_dropwhile()

    print("\naccumulate() tests:")
    test_accumulate_sum()
    test_accumulate_product()

    print("\nstarmap() tests:")
    test_starmap()
    test_starmap_pow()

    print(f"\nAll tests passed!")

    print(f"\nPerformance benchmarks:")
    benchmark_count()
    benchmark_chain()


if __name__ == "__main__":
    run_tests()
