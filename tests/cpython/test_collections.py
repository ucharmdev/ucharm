"""
Simplified collections module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_collections.py
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


def test_raises(name, exc_type, func, *args, **kwargs):
    global _passed, _failed, _errors
    try:
        func(*args, **kwargs)
        _failed += 1
        _errors.append(name)
        print(f"  FAIL: {name} (no exception raised)")
    except exc_type:
        _passed += 1
        print(f"  PASS: {name}")
    except Exception as e:
        _failed += 1
        _errors.append(name)
        print(f"  FAIL: {name} (wrong exception: {type(e).__name__})")


# Try to import from collections
try:
    from collections import OrderedDict

    HAS_ORDEREDDICT = True
except ImportError:
    HAS_ORDEREDDICT = False

try:
    from collections import namedtuple

    HAS_NAMEDTUPLE = True
except ImportError:
    HAS_NAMEDTUPLE = False

try:
    from collections import deque

    HAS_DEQUE = True
except ImportError:
    HAS_DEQUE = False


# ============================================================================
# OrderedDict tests
# ============================================================================

print("\n=== OrderedDict tests ===")

if HAS_ORDEREDDICT:
    # Basic creation
    od = OrderedDict()
    test("OrderedDict empty", len(od) == 0)

    # Creation with items
    od = OrderedDict([("a", 1), ("b", 2), ("c", 3)])
    test("OrderedDict from list", list(od.keys()) == ["a", "b", "c"])
    test("OrderedDict values", list(od.values()) == [1, 2, 3])

    # Test insertion order is preserved
    od = OrderedDict()
    od["one"] = 1
    od["two"] = 2
    od["three"] = 3
    test("OrderedDict insertion order", list(od.keys()) == ["one", "two", "three"])

    # Test that updating a value doesn't change order
    od["two"] = 22
    test(
        "OrderedDict update preserves order", list(od.keys()) == ["one", "two", "three"]
    )
    test("OrderedDict update changes value", od["two"] == 22)

    # Test deletion and re-insertion changes order
    del od["two"]
    od["two"] = 2
    test(
        "OrderedDict delete+insert changes order",
        list(od.keys()) == ["one", "three", "two"],
    )

    # move_to_end (if available)
    if hasattr(OrderedDict, "move_to_end"):
        od = OrderedDict([("a", 1), ("b", 2), ("c", 3)])
        od.move_to_end("a")
        test("move_to_end default", list(od.keys()) == ["b", "c", "a"])
    else:
        skip("move_to_end", "not implemented")

    # popitem on empty raises KeyError
    od_empty = OrderedDict()
    test_raises("popitem empty raises KeyError", KeyError, od_empty.popitem)
else:
    skip("OrderedDict tests", "OrderedDict not available")


# ============================================================================
# namedtuple tests
# ============================================================================

print("\n=== namedtuple tests ===")

if HAS_NAMEDTUPLE:
    # Basic creation with list field names
    Point = namedtuple("Point", ["x", "y"])
    p = Point(1, 2)
    test("namedtuple creation", p.x == 1 and p.y == 2)

    # Creation with space-separated field names
    Point2 = namedtuple("Point2", "x y")
    p2 = Point2(3, 4)
    test("namedtuple space-separated", p2.x == 3 and p2.y == 4)

    # Creation with keyword arguments
    p4 = Point(x=10, y=20)
    test("namedtuple kwargs", p4.x == 10 and p4.y == 20)

    # Attribute access
    p = Point(3, 4)
    test("namedtuple attr x", p.x == 3)
    test("namedtuple attr y", p.y == 4)

    # Index access
    test("namedtuple index 0", p[0] == 3)
    test("namedtuple index 1", p[1] == 4)

    # Iteration
    test("namedtuple iter", list(p) == [3, 4])

    # Length
    test("namedtuple len", len(p) == 2)

    # Unpacking
    x, y = p
    test("namedtuple unpack", x == 3 and y == 4)

    # _asdict (if available)
    if hasattr(p, "_asdict"):
        d = p._asdict()
        test("_asdict type", isinstance(d, dict))
        test("_asdict values", d["x"] == 3 and d["y"] == 4)
    else:
        skip("_asdict", "not implemented")

    # _replace (if available)
    if hasattr(p, "_replace"):
        p2 = p._replace(x=10)
        test("_replace single", p2.x == 10 and p2.y == 4)
        test("_replace original unchanged", p.x == 3)
    else:
        skip("_replace", "not implemented")

    # _fields (if available)
    if hasattr(Point, "_fields"):
        test("_fields", Point._fields == ("x", "y"))
    else:
        skip("_fields", "not implemented")
else:
    skip("namedtuple tests", "namedtuple not available")


# ============================================================================
# deque tests
# ============================================================================

print("\n=== deque tests ===")

if HAS_DEQUE:
    # Check if MicroPython-style deque (requires maxlen) or CPython-style
    _mpy_deque = False
    try:
        _test_d = deque()
    except TypeError:
        _mpy_deque = True

    def make_deque(items=None, maxlen=None):
        """Create deque compatible with both MicroPython and CPython"""
        if items is None:
            items = []
        if _mpy_deque:
            # MicroPython requires maxlen argument
            return deque(items, maxlen if maxlen else 1000)
        else:
            # CPython style
            if maxlen is not None:
                return deque(items, maxlen=maxlen)
            return deque(items)

    # Empty deque
    d = make_deque()
    test("deque empty", len(d) == 0)

    # From list
    d = make_deque([1, 2, 3])
    test("deque from list", list(d) == [1, 2, 3])

    # append (right)
    d = make_deque([1, 2, 3])
    d.append(4)
    test("deque append", list(d) == [1, 2, 3, 4])

    # appendleft
    d.appendleft(0)
    test("deque appendleft", list(d) == [0, 1, 2, 3, 4])

    # pop (right)
    d = make_deque([1, 2, 3, 4, 5])
    item = d.pop()
    test("deque pop value", item == 5)
    test("deque pop result", list(d) == [1, 2, 3, 4])

    # popleft
    item = d.popleft()
    test("deque popleft value", item == 1)
    test("deque popleft result", list(d) == [2, 3, 4])

    # pop on empty raises IndexError
    d_empty = make_deque()
    test_raises("deque pop empty", IndexError, d_empty.pop)
    test_raises("deque popleft empty", IndexError, d_empty.popleft)

    # rotate (if available) - CPython only
    d_test = make_deque([1, 2, 3])
    if hasattr(d_test, "rotate"):
        d = make_deque([1, 2, 3, 4, 5])
        d.rotate(2)
        test("deque rotate right", list(d) == [4, 5, 1, 2, 3])

        d = make_deque([1, 2, 3, 4, 5])
        d.rotate(-2)
        test("deque rotate left", list(d) == [3, 4, 5, 1, 2])
    else:
        skip("deque rotate", "not implemented")

    # maxlen
    d = make_deque([1, 2, 3], maxlen=3)
    d.append(4)
    test("deque maxlen append", list(d) == [2, 3, 4])

    d = make_deque([1, 2, 3], maxlen=3)
    d.appendleft(0)
    test("deque maxlen appendleft", list(d) == [0, 1, 2])

    # extend (if available)
    d_test = make_deque([1, 2])
    if hasattr(d_test, "extend"):
        d = make_deque([1, 2])
        d.extend([3, 4, 5])
        test("deque extend", list(d) == [1, 2, 3, 4, 5])
    else:
        skip("deque extend", "not implemented")

    # clear (if available) - CPython only
    d_test = make_deque([1, 2, 3])
    if hasattr(d_test, "clear"):
        d = make_deque([1, 2, 3])
        d.clear()
        test("deque clear", len(d) == 0)
    else:
        skip("deque clear", "not implemented")
else:
    skip("deque tests", "deque not available")


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
