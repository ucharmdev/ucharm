"""
Simplified operator module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_operator.py
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


try:
    import operator
except ImportError:
    print("SKIP: operator module not available")
    sys.exit(0)


# ============================================================================
# Arithmetic operators
# ============================================================================

print("\n=== Arithmetic operators ===")

test("add int", operator.add(1, 2) == 3)
test("add float", abs(operator.add(1.5, 2.5) - 4.0) < 0.001)
test("add str", operator.add("hello", " world") == "hello world")
test("add list", operator.add([1, 2], [3, 4]) == [1, 2, 3, 4])

test("sub", operator.sub(5, 3) == 2)
test("sub negative", operator.sub(3, 5) == -2)
test("sub float", abs(operator.sub(5.5, 2.5) - 3.0) < 0.001)

test("mul int", operator.mul(3, 4) == 12)
test("mul str", operator.mul("ab", 3) == "ababab")
test("mul list", operator.mul([1, 2], 2) == [1, 2, 1, 2])

test("truediv", abs(operator.truediv(7, 2) - 3.5) < 0.001)
test("truediv float", abs(operator.truediv(7.0, 2.0) - 3.5) < 0.001)

test("floordiv", operator.floordiv(7, 2) == 3)
test("floordiv negative", operator.floordiv(-7, 2) == -4)

test("mod", operator.mod(7, 3) == 1)
test("mod negative", operator.mod(-7, 3) == 2)

test("pow", operator.pow(2, 3) == 8)
test("pow float", abs(operator.pow(2.0, 3.0) - 8.0) < 0.001)

test("neg", operator.neg(5) == -5)
test("neg negative", operator.neg(-5) == 5)
test("neg float", abs(operator.neg(3.14) + 3.14) < 0.001)

test("pos", operator.pos(5) == 5)
test("pos negative", operator.pos(-5) == -5)

test("abs positive", operator.abs(5) == 5)
test("abs negative", operator.abs(-5) == 5)
test("abs float", abs(operator.abs(-3.14) - 3.14) < 0.001)

test("index", operator.index(5) == 5)
test("index negative", operator.index(-5) == -5)


# ============================================================================
# Comparison operators
# ============================================================================

print("\n=== Comparison operators ===")

test("lt true", operator.lt(1, 2) is True)
test("lt false", operator.lt(2, 1) is False)
test("lt equal", operator.lt(1, 1) is False)

test("le true", operator.le(1, 2) is True)
test("le equal", operator.le(1, 1) is True)
test("le false", operator.le(2, 1) is False)

test("eq true", operator.eq(1, 1) is True)
test("eq false", operator.eq(1, 2) is False)
test("eq str", operator.eq("a", "a") is True)

test("ne true", operator.ne(1, 2) is True)
test("ne false", operator.ne(1, 1) is False)

test("ge true", operator.ge(2, 1) is True)
test("ge equal", operator.ge(1, 1) is True)
test("ge false", operator.ge(1, 2) is False)

test("gt true", operator.gt(2, 1) is True)
test("gt false", operator.gt(1, 2) is False)
test("gt equal", operator.gt(1, 1) is False)


# ============================================================================
# Logical/bitwise operators
# ============================================================================

print("\n=== Logical/bitwise operators ===")

test("not_ false", operator.not_(False) is True)
test("not_ true", operator.not_(True) is False)
test("not_ zero", operator.not_(0) is True)
test("not_ nonzero", operator.not_(1) is False)
test("not_ empty", operator.not_([]) is True)
test("not_ nonempty", operator.not_([1]) is False)

test("truth false", operator.truth(False) is False)
test("truth true", operator.truth(True) is True)
test("truth zero", operator.truth(0) is False)
test("truth nonzero", operator.truth(1) is True)

test("and_ int", operator.and_(0b1100, 0b1010) == 0b1000)
test("or_ int", operator.or_(0b1100, 0b1010) == 0b1110)
test("xor int", operator.xor(0b1100, 0b1010) == 0b0110)

test("invert", operator.invert(0) == -1)
test("inv", operator.inv(0) == -1)  # alias

test("lshift", operator.lshift(1, 4) == 16)
test("rshift", operator.rshift(16, 2) == 4)


# ============================================================================
# Identity operators
# ============================================================================

print("\n=== Identity operators ===")

a = [1, 2, 3]
b = a
c = [1, 2, 3]

test("is_ same", operator.is_(a, b) is True)
test("is_ different", operator.is_(a, c) is False)
test("is_not same", operator.is_not(a, b) is False)
test("is_not different", operator.is_not(a, c) is True)

try:
    test("is_none true", operator.is_none(None) is True)
    test("is_none false", operator.is_none(1) is False)
    test("is_not_none true", operator.is_not_none(1) is True)
    test("is_not_none false", operator.is_not_none(None) is False)
except AttributeError:
    skip("is_none/is_not_none", "Python 3.11+ feature")


# ============================================================================
# Sequence operators
# ============================================================================

print("\n=== Sequence operators ===")

test("concat list", operator.concat([1, 2], [3, 4]) == [1, 2, 3, 4])
test("concat str", operator.concat("hello", " world") == "hello world")

test("contains true", operator.contains([1, 2, 3], 2) is True)
test("contains false", operator.contains([1, 2, 3], 4) is False)
test("contains str", operator.contains("hello", "ll") is True)

test("countOf", operator.countOf([1, 2, 2, 3, 2], 2) == 3)
test("countOf zero", operator.countOf([1, 2, 3], 5) == 0)

test("indexOf", operator.indexOf([1, 2, 3, 4], 3) == 2)
test("indexOf first", operator.indexOf([1, 2, 3, 2], 2) == 1)

# indexOf should raise ValueError if not found
try:
    operator.indexOf([1, 2, 3], 5)
    test("indexOf not found raises", False)
except ValueError:
    test("indexOf not found raises", True)

test("getitem list", operator.getitem([1, 2, 3], 1) == 2)
test("getitem dict", operator.getitem({"a": 1}, "a") == 1)
test("getitem str", operator.getitem("hello", 0) == "h")

lst = [1, 2, 3]
operator.setitem(lst, 1, 10)
test("setitem", lst == [1, 10, 3])

lst = [1, 2, 3]
operator.delitem(lst, 1)
test("delitem", lst == [1, 3])


# ============================================================================
# In-place operators
# ============================================================================

print("\n=== In-place operators ===")

# For immutable types, in-place ops return new objects
x = 5
test("iadd", operator.iadd(x, 3) == 8)

x = 5
test("isub", operator.isub(x, 3) == 2)

x = 5
test("imul", operator.imul(x, 3) == 15)

x = 6
test("itruediv", abs(operator.itruediv(x, 2) - 3.0) < 0.001)

x = 7
test("ifloordiv", operator.ifloordiv(x, 2) == 3)

x = 7
test("imod", operator.imod(x, 3) == 1)

x = 2
test("ipow", operator.ipow(x, 3) == 8)

x = 0b1100
test("iand", operator.iand(x, 0b1010) == 0b1000)

x = 0b1100
test("ior", operator.ior(x, 0b1010) == 0b1110)

x = 0b1100
test("ixor", operator.ixor(x, 0b1010) == 0b0110)

x = 1
test("ilshift", operator.ilshift(x, 4) == 16)

x = 16
test("irshift", operator.irshift(x, 2) == 4)

# For mutable types, in-place ops modify in place
lst = [1, 2]
result = operator.iconcat(lst, [3, 4])
test("iconcat", result == [1, 2, 3, 4])


# ============================================================================
# itemgetter
# ============================================================================

print("\n=== itemgetter ===")

getter = operator.itemgetter(1)
test("itemgetter single", getter([1, 2, 3]) == 2)
test("itemgetter dict", getter({"a": 1, "b": 2, 1: 100}) == 100)

getter = operator.itemgetter(0, 2)
test("itemgetter multiple", getter([1, 2, 3, 4]) == (1, 3))

getter = operator.itemgetter("a", "c")
test("itemgetter dict multiple", getter({"a": 1, "b": 2, "c": 3}) == (1, 3))

# Use itemgetter for sorting
data = [{"name": "Bob", "age": 30}, {"name": "Alice", "age": 25}]
sorted_data = sorted(data, key=operator.itemgetter("age"))
test("itemgetter sort", sorted_data[0]["name"] == "Alice")


# ============================================================================
# attrgetter
# ============================================================================

print("\n=== attrgetter ===")


class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y


p = Point(3, 4)

getter = operator.attrgetter("x")
test("attrgetter single", getter(p) == 3)

getter = operator.attrgetter("x", "y")
test("attrgetter multiple", getter(p) == (3, 4))


# Nested attribute access
class Container:
    def __init__(self, point):
        self.point = point


c = Container(Point(1, 2))
getter = operator.attrgetter("point.x")
test("attrgetter nested", getter(c) == 1)


# ============================================================================
# methodcaller
# ============================================================================

print("\n=== methodcaller ===")

caller = operator.methodcaller("upper")
test("methodcaller no args", caller("hello") == "HELLO")

caller = operator.methodcaller("split", " ")
test("methodcaller with args", caller("a b c") == ["a", "b", "c"])

caller = operator.methodcaller("replace", "o", "0")
test("methodcaller two args", caller("hello") == "hell0")

# With keyword args - note: not all MicroPython methods support kwargs
caller = operator.methodcaller("split")
test("methodcaller default", caller("a b c") == ["a", "b", "c"])


# ============================================================================
# length_hint
# ============================================================================

print("\n=== length_hint ===")

try:
    test("length_hint list", operator.length_hint([1, 2, 3]) == 3)
    test("length_hint str", operator.length_hint("hello") == 5)
    test("length_hint default", operator.length_hint(iter([]), 10) == 10)
except AttributeError:
    skip("length_hint", "not implemented")


# ============================================================================
# call (Python 3.11+)
# ============================================================================

print("\n=== call ===")

try:

    def add(a, b):
        return a + b

    test("call function", operator.call(add, 1, 2) == 3)
    test("call builtin", operator.call(len, [1, 2, 3]) == 3)
except AttributeError:
    skip("call", "Python 3.11+ feature")


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
