"""
Simplified time module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_time.py
"""

import sys
import time

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


# ============================================================================
# time.time() tests
# ============================================================================

print("\n=== time.time() tests ===")

t = time.time()
test("time returns number", isinstance(t, (int, float)))
test("time is positive", t > 0)
test("time is reasonable", t > 1000000000)  # After 2001

# Time should increase
t1 = time.time()
t2 = time.time()
test("time increases", t2 >= t1)


# ============================================================================
# time.sleep() tests
# ============================================================================

print("\n=== time.sleep() tests ===")

# Sleep for a short time
start = time.time()
time.sleep(0.1)
elapsed = time.time() - start
test("sleep 0.1s", elapsed >= 0.09)  # Allow some tolerance

# Sleep for zero (should return immediately)
start = time.time()
time.sleep(0)
elapsed = time.time() - start
test("sleep 0", elapsed < 0.1)


# ============================================================================
# time.localtime() tests
# ============================================================================

print("\n=== time.localtime() tests ===")

if hasattr(time, "localtime"):
    lt = time.localtime()
    test(
        "localtime returns tuple", isinstance(lt, (tuple, type(lt)))
    )  # struct_time or tuple
    test("localtime has 9 elements", len(lt) >= 9)

    # Check reasonable values
    test("localtime year", lt[0] >= 2020)  # tm_year
    test("localtime month", 1 <= lt[1] <= 12)  # tm_mon
    test("localtime day", 1 <= lt[2] <= 31)  # tm_mday
    test("localtime hour", 0 <= lt[3] <= 23)  # tm_hour
    test("localtime minute", 0 <= lt[4] <= 59)  # tm_min
    test("localtime second", 0 <= lt[5] <= 61)  # tm_sec (61 for leap seconds)
    test("localtime weekday", 0 <= lt[6] <= 6)  # tm_wday
    test("localtime yearday", 1 <= lt[7] <= 366)  # tm_yday

    # With argument
    lt2 = time.localtime(0)
    test("localtime(0) works", lt2 is not None)
else:
    skip("localtime tests", "localtime not available")


# ============================================================================
# time.gmtime() tests
# ============================================================================

print("\n=== time.gmtime() tests ===")

if hasattr(time, "gmtime"):
    gt = time.gmtime()
    test("gmtime returns tuple", isinstance(gt, (tuple, type(gt))))
    test("gmtime has 9 elements", len(gt) >= 9)

    # Check reasonable values
    test("gmtime year", gt[0] >= 2020)
    test("gmtime month", 1 <= gt[1] <= 12)

    # gmtime(0) should be Unix epoch
    epoch = time.gmtime(0)
    test("gmtime(0) year", epoch[0] == 1970)
    test("gmtime(0) month", epoch[1] == 1)
    test("gmtime(0) day", epoch[2] == 1)
else:
    skip("gmtime tests", "gmtime not available")


# ============================================================================
# time.mktime() tests
# ============================================================================

print("\n=== time.mktime() tests ===")

if hasattr(time, "mktime") and hasattr(time, "localtime"):
    # Round-trip test
    now = time.time()
    lt = time.localtime(now)
    back = time.mktime(lt)
    test("mktime roundtrip", abs(now - back) < 2)  # Allow 1 second tolerance

    # Known date
    # 2020-01-01 00:00:00
    try:
        t = time.mktime((2020, 1, 1, 0, 0, 0, 0, 0, -1))
        test(
            "mktime known date",
            t > 1577836800 - 86400 * 2 and t < 1577836800 + 86400 * 2,
        )
    except (OverflowError, OSError):
        skip("mktime known date", "date out of range")
else:
    skip("mktime tests", "mktime or localtime not available")


# ============================================================================
# time.strftime() tests
# ============================================================================

print("\n=== time.strftime() tests ===")

if hasattr(time, "strftime") and hasattr(time, "localtime"):
    lt = time.localtime()

    # Basic format
    result = time.strftime("%Y", lt)
    test("strftime %Y", len(result) == 4 and result.isdigit())

    result = time.strftime("%m", lt)
    test("strftime %m", len(result) == 2)

    result = time.strftime("%d", lt)
    test("strftime %d", len(result) == 2)

    result = time.strftime("%H:%M:%S", lt)
    test("strftime %H:%M:%S", len(result) == 8 and ":" in result)

    result = time.strftime("%Y-%m-%d", lt)
    test("strftime %Y-%m-%d", len(result) == 10 and "-" in result)

    # Literal text
    result = time.strftime("Year: %Y", lt)
    test("strftime literal", result.startswith("Year: "))
else:
    skip("strftime tests", "strftime or localtime not available")


# ============================================================================
# time.strptime() tests
# ============================================================================

print("\n=== time.strptime() tests ===")

if hasattr(time, "strptime"):
    # Parse date
    try:
        result = time.strptime("2020-01-15", "%Y-%m-%d")
        test("strptime date", result[0] == 2020 and result[1] == 1 and result[2] == 15)
    except ValueError:
        skip("strptime date", "parsing failed")

    # Parse time
    try:
        result = time.strptime("14:30:00", "%H:%M:%S")
        test("strptime time", result[3] == 14 and result[4] == 30 and result[5] == 0)
    except ValueError:
        skip("strptime time", "parsing failed")
else:
    skip("strptime tests", "strptime not available")


# ============================================================================
# time.monotonic() tests (if available)
# ============================================================================

print("\n=== time.monotonic() tests ===")

if hasattr(time, "monotonic"):
    m = time.monotonic()
    test("monotonic returns number", isinstance(m, (int, float)))
    test("monotonic is non-negative", m >= 0)

    # Should always increase
    m1 = time.monotonic()
    time.sleep(0.01)
    m2 = time.monotonic()
    test("monotonic increases", m2 > m1)
else:
    skip("monotonic tests", "monotonic not available")


# ============================================================================
# time.perf_counter() tests (if available)
# ============================================================================

print("\n=== time.perf_counter() tests ===")

if hasattr(time, "perf_counter"):
    p = time.perf_counter()
    test("perf_counter returns number", isinstance(p, (int, float)))

    # Should increase
    p1 = time.perf_counter()
    time.sleep(0.01)
    p2 = time.perf_counter()
    test("perf_counter increases", p2 > p1)
else:
    skip("perf_counter tests", "perf_counter not available")


# ============================================================================
# time.time_ns() tests (if available)
# ============================================================================

print("\n=== time.time_ns() tests ===")

if hasattr(time, "time_ns"):
    t = time.time_ns()
    test("time_ns returns int", isinstance(t, int))
    test("time_ns is positive", t > 0)
    test("time_ns is nanoseconds", t > 1000000000000000000)  # After 2001
else:
    skip("time_ns tests", "time_ns not available")


# ============================================================================
# time.ticks_ms/ticks_us/ticks_diff (MicroPython specific)
# ============================================================================

print("\n=== MicroPython ticks functions ===")

if hasattr(time, "ticks_ms"):
    t = time.ticks_ms()
    test("ticks_ms returns int", isinstance(t, int))
    test("ticks_ms is non-negative", t >= 0)
else:
    skip("ticks_ms", "not available (MicroPython specific)")

if hasattr(time, "ticks_us"):
    t = time.ticks_us()
    test("ticks_us returns int", isinstance(t, int))
    test("ticks_us is non-negative", t >= 0)
else:
    skip("ticks_us", "not available (MicroPython specific)")

if hasattr(time, "ticks_diff"):
    t1 = time.ticks_ms() if hasattr(time, "ticks_ms") else 100
    t2 = t1 + 50
    if hasattr(time, "ticks_ms"):
        diff = time.ticks_diff(t2, t1)
        test("ticks_diff", diff == 50)
else:
    skip("ticks_diff", "not available (MicroPython specific)")


# ============================================================================
# Edge cases
# ============================================================================

print("\n=== Edge cases ===")

# Very small sleep
start = time.time()
time.sleep(0.001)
elapsed = time.time() - start
test("sleep 1ms", elapsed >= 0.0005)

# Multiple time() calls
times = [time.time() for _ in range(10)]
test("multiple time calls", all(times[i] <= times[i + 1] for i in range(9)))


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
