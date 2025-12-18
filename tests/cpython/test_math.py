"""
Simplified math module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_math.py
"""

import math
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


def approx_equal(a, b, tol=1e-9):
    """Check if two floats are approximately equal."""
    if a == b:
        return True
    return abs(a - b) < tol


# ============================================================================
# Constants
# ============================================================================

print("\n=== Constants ===")

test("pi exists", hasattr(math, "pi"))
test("pi value", approx_equal(math.pi, 3.141592653589793, 1e-10))

test("e exists", hasattr(math, "e"))
test("e value", approx_equal(math.e, 2.718281828459045, 1e-10))

if hasattr(math, "tau"):
    test("tau value", approx_equal(math.tau, 2 * math.pi, 1e-10))
else:
    skip("tau", "not available")

if hasattr(math, "inf"):
    test("inf exists", math.inf > 1e308)
else:
    skip("inf", "not available")

if hasattr(math, "nan"):
    test("nan exists", math.nan != math.nan)  # NaN is not equal to itself
else:
    skip("nan", "not available")


# ============================================================================
# Basic functions
# ============================================================================

print("\n=== Basic functions ===")

# abs/fabs
test("fabs positive", math.fabs(3.14) == 3.14)
test("fabs negative", math.fabs(-3.14) == 3.14)
test("fabs zero", math.fabs(0) == 0)

# ceil
test("ceil positive", math.ceil(3.2) == 4)
test("ceil negative", math.ceil(-3.2) == -3)
test("ceil integer", math.ceil(3.0) == 3)

# floor
test("floor positive", math.floor(3.8) == 3)
test("floor negative", math.floor(-3.8) == -4)
test("floor integer", math.floor(3.0) == 3)

# trunc
if hasattr(math, "trunc"):
    test("trunc positive", math.trunc(3.8) == 3)
    test("trunc negative", math.trunc(-3.8) == -3)
else:
    skip("trunc", "not available")


# ============================================================================
# Power and logarithmic functions
# ============================================================================

print("\n=== Power and logarithmic functions ===")

# sqrt
test("sqrt 4", math.sqrt(4) == 2.0)
test("sqrt 2", approx_equal(math.sqrt(2), 1.4142135623730951))
test("sqrt 0", math.sqrt(0) == 0)

# pow
test("pow 2^3", math.pow(2, 3) == 8.0)
test("pow 2^0", math.pow(2, 0) == 1.0)
test("pow negative", math.pow(2, -1) == 0.5)

# exp
test("exp 0", math.exp(0) == 1.0)
test("exp 1", approx_equal(math.exp(1), math.e))
test("exp 2", approx_equal(math.exp(2), math.e**2))

# log (natural)
test("log e", approx_equal(math.log(math.e), 1.0))
test("log 1", math.log(1) == 0.0)
test("log 10", approx_equal(math.log(10), 2.302585092994046))

# log with base
try:
    test("log base 10", approx_equal(math.log(100, 10), 2.0))
    test("log base 2", approx_equal(math.log(8, 2), 3.0))
except TypeError:
    skip("log with base", "two-argument log not supported")

# log10
if hasattr(math, "log10"):
    test("log10 10", math.log10(10) == 1.0)
    test("log10 100", math.log10(100) == 2.0)
    test("log10 1", math.log10(1) == 0.0)
else:
    skip("log10", "not available")

# log2
if hasattr(math, "log2"):
    test("log2 2", math.log2(2) == 1.0)
    test("log2 8", math.log2(8) == 3.0)
    test("log2 1", math.log2(1) == 0.0)
else:
    skip("log2", "not available")


# ============================================================================
# Trigonometric functions
# ============================================================================

print("\n=== Trigonometric functions ===")

# sin
test("sin 0", math.sin(0) == 0.0)
test("sin pi/2", approx_equal(math.sin(math.pi / 2), 1.0))
test("sin pi", approx_equal(math.sin(math.pi), 0.0, 1e-15))

# cos
test("cos 0", math.cos(0) == 1.0)
test("cos pi/2", approx_equal(math.cos(math.pi / 2), 0.0, 1e-15))
test("cos pi", approx_equal(math.cos(math.pi), -1.0))

# tan
test("tan 0", math.tan(0) == 0.0)
test("tan pi/4", approx_equal(math.tan(math.pi / 4), 1.0))

# asin
test("asin 0", math.asin(0) == 0.0)
test("asin 1", approx_equal(math.asin(1), math.pi / 2))

# acos
test("acos 1", math.acos(1) == 0.0)
test("acos 0", approx_equal(math.acos(0), math.pi / 2))

# atan
test("atan 0", math.atan(0) == 0.0)
test("atan 1", approx_equal(math.atan(1), math.pi / 4))

# atan2
test("atan2 0,1", math.atan2(0, 1) == 0.0)
test("atan2 1,0", approx_equal(math.atan2(1, 0), math.pi / 2))
test("atan2 1,1", approx_equal(math.atan2(1, 1), math.pi / 4))


# ============================================================================
# Hyperbolic functions
# ============================================================================

print("\n=== Hyperbolic functions ===")

if hasattr(math, "sinh"):
    test("sinh 0", math.sinh(0) == 0.0)
    test("sinh 1", approx_equal(math.sinh(1), 1.1752011936438014))
else:
    skip("sinh", "not available")

if hasattr(math, "cosh"):
    test("cosh 0", math.cosh(0) == 1.0)
    test("cosh 1", approx_equal(math.cosh(1), 1.5430806348152437))
else:
    skip("cosh", "not available")

if hasattr(math, "tanh"):
    test("tanh 0", math.tanh(0) == 0.0)
    test("tanh 1", approx_equal(math.tanh(1), 0.7615941559557649))
else:
    skip("tanh", "not available")


# ============================================================================
# Angular conversion
# ============================================================================

print("\n=== Angular conversion ===")

if hasattr(math, "degrees"):
    test("degrees pi", approx_equal(math.degrees(math.pi), 180.0))
    test("degrees pi/2", approx_equal(math.degrees(math.pi / 2), 90.0))
else:
    skip("degrees", "not available")

if hasattr(math, "radians"):
    test("radians 180", approx_equal(math.radians(180), math.pi))
    test("radians 90", approx_equal(math.radians(90), math.pi / 2))
else:
    skip("radians", "not available")


# ============================================================================
# Special functions
# ============================================================================

print("\n=== Special functions ===")

# copysign
if hasattr(math, "copysign"):
    test("copysign positive", math.copysign(1.0, 2.0) == 1.0)
    test("copysign negative", math.copysign(1.0, -2.0) == -1.0)
else:
    skip("copysign", "not available")

# fmod
if hasattr(math, "fmod"):
    test("fmod 7,4", approx_equal(math.fmod(7, 4), 3.0))
    test("fmod -7,4", approx_equal(math.fmod(-7, 4), -3.0))
else:
    skip("fmod", "not available")

# modf
if hasattr(math, "modf"):
    frac, integer = math.modf(3.5)
    test("modf 3.5 frac", approx_equal(frac, 0.5))
    test("modf 3.5 int", integer == 3.0)
else:
    skip("modf", "not available")

# frexp
if hasattr(math, "frexp"):
    mantissa, exp = math.frexp(8.0)
    test("frexp 8", mantissa == 0.5 and exp == 4)
else:
    skip("frexp", "not available")

# ldexp
if hasattr(math, "ldexp"):
    test("ldexp", math.ldexp(0.5, 4) == 8.0)
else:
    skip("ldexp", "not available")

# isfinite
if hasattr(math, "isfinite"):
    test("isfinite number", math.isfinite(1.0))
    test("isfinite inf", not math.isfinite(float("inf")))
else:
    skip("isfinite", "not available")

# isinf
if hasattr(math, "isinf"):
    test("isinf number", not math.isinf(1.0))
    test("isinf inf", math.isinf(float("inf")))
else:
    skip("isinf", "not available")

# isnan
if hasattr(math, "isnan"):
    test("isnan number", not math.isnan(1.0))
    test("isnan nan", math.isnan(float("nan")))
else:
    skip("isnan", "not available")


# ============================================================================
# Edge cases
# ============================================================================

print("\n=== Edge cases ===")

# sqrt of negative
try:
    math.sqrt(-1)
    test("sqrt negative raises", False)
except ValueError:
    test("sqrt negative raises", True)

# log of zero
try:
    math.log(0)
    test("log 0 raises", False)
except ValueError:
    test("log 0 raises", True)

# log of negative
try:
    math.log(-1)
    test("log negative raises", False)
except ValueError:
    test("log negative raises", True)


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
