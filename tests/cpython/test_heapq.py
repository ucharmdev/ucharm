"""
Simplified heapq module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_heapq.py
"""

import heapq
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


def is_heap(heap):
    """Check if the list satisfies the heap property."""
    n = len(heap)
    for i in range(n):
        left = 2 * i + 1
        right = 2 * i + 2
        if left < n and heap[i] > heap[left]:
            return False
        if right < n and heap[i] > heap[right]:
            return False
    return True


# ============================================================================
# heapq.heappush() tests
# ============================================================================

print("\n=== heapq.heappush() tests ===")

heap = []
heapq.heappush(heap, 3)
test("heappush single", heap == [3])

heapq.heappush(heap, 1)
test("heappush smaller element", heap[0] == 1)
test("heappush maintains heap", is_heap(heap))

heapq.heappush(heap, 2)
test("heappush middle element", is_heap(heap))

# Push multiple elements
heap = []
for x in [5, 3, 7, 1, 4, 2, 6]:
    heapq.heappush(heap, x)
test("heappush multiple maintains heap", is_heap(heap))
test("heappush multiple min at top", heap[0] == 1)


# ============================================================================
# heapq.heappop() tests
# ============================================================================

print("\n=== heapq.heappop() tests ===")

heap = [1, 3, 2]
result = heapq.heappop(heap)
test("heappop returns min", result == 1)
test("heappop reduces size", len(heap) == 2)
test("heappop maintains heap", is_heap(heap))

# Pop all elements in order
heap = []
for x in [5, 3, 7, 1, 4, 2, 6]:
    heapq.heappush(heap, x)
sorted_result = []
while heap:
    sorted_result.append(heapq.heappop(heap))
test("heappop produces sorted", sorted_result == [1, 2, 3, 4, 5, 6, 7])

# Pop raises on empty
try:
    heapq.heappop([])
    test("heappop empty raises", False)
except IndexError:
    test("heappop empty raises", True)


# ============================================================================
# heapq.heapify() tests
# ============================================================================

print("\n=== heapq.heapify() tests ===")

data = [5, 3, 7, 1, 4, 2, 6]
heapq.heapify(data)
test("heapify creates heap", is_heap(data))
test("heapify min at top", data[0] == 1)

data = [1, 2, 3, 4, 5]
heapq.heapify(data)
test("heapify sorted", is_heap(data))

data = [5, 4, 3, 2, 1]
heapq.heapify(data)
test("heapify reverse sorted", is_heap(data))
test("heapify reverse min", data[0] == 1)

data = [42]
heapq.heapify(data)
test("heapify single", data == [42])

data = []
heapq.heapify(data)
test("heapify empty", data == [])


# ============================================================================
# heapq.heapreplace() tests
# ============================================================================

print("\n=== heapq.heapreplace() tests ===")

if hasattr(heapq, "heapreplace"):
    heap = [1, 3, 2, 5, 4]
    heapq.heapify(heap)
    result = heapq.heapreplace(heap, 10)
    test("heapreplace returns old min", result == 1)
    test("heapreplace maintains heap", is_heap(heap))
    test("heapreplace size unchanged", len(heap) == 5)

    # heapreplace raises on empty
    try:
        heapq.heapreplace([], 1)
        test("heapreplace empty raises", False)
    except IndexError:
        test("heapreplace empty raises", True)
else:
    skip("heapreplace tests", "heapreplace not available")


# ============================================================================
# heapq.heappushpop() tests
# ============================================================================

print("\n=== heapq.heappushpop() tests ===")

if hasattr(heapq, "heappushpop"):
    heap = [1, 3, 2, 5, 4]
    heapq.heapify(heap)
    result = heapq.heappushpop(heap, 10)
    test("heappushpop larger returns min", result == 1)
    test("heappushpop larger heap", is_heap(heap))
    test("heappushpop larger size", len(heap) == 5)

    heap = [1, 3, 2, 5, 4]
    heapq.heapify(heap)
    result = heapq.heappushpop(heap, 0)
    test("heappushpop smaller returns pushed", result == 0)
    test("heappushpop smaller min unchanged", heap[0] == 1)
else:
    skip("heappushpop tests", "heappushpop not available")


# ============================================================================
# heapq.nlargest() tests
# ============================================================================

print("\n=== heapq.nlargest() tests ===")

if hasattr(heapq, "nlargest"):
    data = [5, 3, 7, 1, 4, 2, 6]
    result = heapq.nlargest(3, data)
    test("nlargest basic", result == [7, 6, 5])

    result = heapq.nlargest(7, data)
    test("nlargest all", result == [7, 6, 5, 4, 3, 2, 1])

    result = heapq.nlargest(0, data)
    test("nlargest zero", result == [])

    result = heapq.nlargest(1, data)
    test("nlargest one", result == [7])

    result = heapq.nlargest(3, [])
    test("nlargest empty", result == [])
else:
    skip("nlargest tests", "nlargest not available")


# ============================================================================
# heapq.nsmallest() tests
# ============================================================================

print("\n=== heapq.nsmallest() tests ===")

if hasattr(heapq, "nsmallest"):
    data = [5, 3, 7, 1, 4, 2, 6]
    result = heapq.nsmallest(3, data)
    test("nsmallest basic", result == [1, 2, 3])

    result = heapq.nsmallest(7, data)
    test("nsmallest all", result == [1, 2, 3, 4, 5, 6, 7])

    result = heapq.nsmallest(0, data)
    test("nsmallest zero", result == [])

    result = heapq.nsmallest(1, data)
    test("nsmallest one", result == [1])

    result = heapq.nsmallest(3, [])
    test("nsmallest empty", result == [])
else:
    skip("nsmallest tests", "nsmallest not available")


# ============================================================================
# Edge cases
# ============================================================================

print("\n=== Edge cases ===")

# Heap with all same elements
heap = [5, 5, 5, 5, 5]
heapq.heapify(heap)
test("all same elements heap", is_heap(heap))
test("all same elements min", heap[0] == 5)

# Float values
heap = []
heapq.heappush(heap, 3.14)
heapq.heappush(heap, 2.71)
heapq.heappush(heap, 1.41)
test("float values heap", is_heap(heap))
test("float values min", heap[0] == 1.41)

# Tuple values (priority queue pattern)
heap = []
heapq.heappush(heap, (3, "three"))
heapq.heappush(heap, (1, "one"))
heapq.heappush(heap, (2, "two"))
test("tuple values heap", is_heap(heap))
test("tuple values min", heap[0] == (1, "one"))


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
