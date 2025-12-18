"""
Simplified datetime module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_datetime.py
"""

import datetime
import sys

# Detect which datetime API we're using
IS_UCHARM = hasattr(datetime, "now") and callable(datetime.now)
IS_CPYTHON = hasattr(datetime, "datetime")

# Test tracking
_passed = 0
_failed = 0
_skipped = 0
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


def skip(name, reason):
    global _skipped
    _skipped += 1
    print(f"  SKIP: {name} ({reason})")


# ============================================================================
# datetime.now() tests - test getting current time
# ============================================================================

print("\n=== datetime.now() tests ===")

if IS_UCHARM:
    now = datetime.now()
    test("now year is reasonable", 2020 <= now["year"] <= 2100)
    test("now month is valid", 1 <= now["month"] <= 12)
    test("now day is valid", 1 <= now["day"] <= 31)
    test("now hour is valid", 0 <= now["hour"] <= 23)
    test("now minute is valid", 0 <= now["minute"] <= 59)
    test("now second is valid", 0 <= now["second"] <= 59)
elif IS_CPYTHON:
    now = datetime.datetime.now()
    test("now year is reasonable", 2020 <= now.year <= 2100)
    test("now month is valid", 1 <= now.month <= 12)
    test("now day is valid", 1 <= now.day <= 31)
    test("now hour is valid", 0 <= now.hour <= 23)
    test("now minute is valid", 0 <= now.minute <= 59)
    test("now second is valid", 0 <= now.second <= 59)
else:
    for _ in range(6):
        skip("now tests", "no datetime API available")

# ============================================================================
# date_isoformat tests - test ISO format date strings
# ============================================================================

print("\n=== date_isoformat tests ===")

if IS_UCHARM and hasattr(datetime, "date_isoformat"):
    test(
        "date_isoformat 2024-01-15",
        datetime.date_isoformat(2024, 1, 15) == "2024-01-15",
    )
    test(
        "date_isoformat 2000-12-31",
        datetime.date_isoformat(2000, 12, 31) == "2000-12-31",
    )
elif IS_CPYTHON:
    d1 = datetime.date(2024, 1, 15)
    d2 = datetime.date(2000, 12, 31)
    test("date_isoformat 2024-01-15", d1.isoformat() == "2024-01-15")
    test("date_isoformat 2000-12-31", d2.isoformat() == "2000-12-31")
else:
    for _ in range(2):
        skip("date_isoformat tests", "no date API available")

# ============================================================================
# weekday tests - test weekday calculation
# ============================================================================

print("\n=== weekday tests ===")

if IS_UCHARM and hasattr(datetime, "weekday"):
    # 2024-01-15 is a Monday (weekday 0)
    test("weekday monday", datetime.weekday(2024, 1, 15) == 0)
    # 2024-01-21 is a Sunday (weekday 6)
    test("weekday sunday", datetime.weekday(2024, 1, 21) == 6)
elif IS_CPYTHON:
    # 2024-01-15 is a Monday (weekday 0)
    test("weekday monday", datetime.date(2024, 1, 15).weekday() == 0)
    # 2024-01-21 is a Sunday (weekday 6)
    test("weekday sunday", datetime.date(2024, 1, 21).weekday() == 6)
else:
    for _ in range(2):
        skip("weekday tests", "not available")

# ============================================================================
# is_leap_year tests
# ============================================================================

print("\n=== is_leap_year tests ===")

if IS_UCHARM and hasattr(datetime, "is_leap_year"):
    test("2000 is leap year", datetime.is_leap_year(2000) == True)
    test("2024 is leap year", datetime.is_leap_year(2024) == True)
    test("2023 is not leap year", datetime.is_leap_year(2023) == False)
    test("1900 is not leap year", datetime.is_leap_year(1900) == False)
elif IS_CPYTHON:
    # CPython: check via Feb 29 existence
    import calendar

    test("2000 is leap year", calendar.isleap(2000) == True)
    test("2024 is leap year", calendar.isleap(2024) == True)
    test("2023 is not leap year", calendar.isleap(2023) == False)
    test("1900 is not leap year", calendar.isleap(1900) == False)
else:
    for _ in range(4):
        skip("is_leap_year tests", "not available")

# ============================================================================
# timedelta tests
# ============================================================================

print("\n=== timedelta tests ===")

if IS_UCHARM and hasattr(datetime, "timedelta"):
    td = datetime.timedelta(1, 3600, 0)
    test("timedelta days", td["days"] == 1)
    test("timedelta seconds", td["seconds"] == 3600)
elif IS_CPYTHON:
    td = datetime.timedelta(days=1, seconds=3600)
    test("timedelta days", td.days == 1)
    test("timedelta seconds", td.seconds == 3600)
else:
    for _ in range(2):
        skip("timedelta tests", "not available")

# ============================================================================
# timedelta total_seconds tests
# ============================================================================

print("\n=== timedelta total_seconds tests ===")

if IS_UCHARM and hasattr(datetime, "timedelta_total_seconds"):
    # 1 day + 3600 seconds = 86400 + 3600 = 90000 seconds
    result = datetime.timedelta_total_seconds(1, 3600, 0)
    test("timedelta_total_seconds", result == 90000.0)
elif IS_CPYTHON:
    td = datetime.timedelta(days=1, seconds=3600)
    test("timedelta_total_seconds", td.total_seconds() == 90000.0)
else:
    skip("timedelta_total_seconds", "not available")

# ============================================================================
# days_in_month tests
# ============================================================================

print("\n=== days_in_month tests ===")

if IS_UCHARM and hasattr(datetime, "days_in_month"):
    test("january has 31 days", datetime.days_in_month(2024, 1) == 31)
    test("feb leap has 29 days", datetime.days_in_month(2024, 2) == 29)
    test("feb non-leap has 28 days", datetime.days_in_month(2023, 2) == 28)
    test("april has 30 days", datetime.days_in_month(2024, 4) == 30)
elif IS_CPYTHON:
    import calendar

    test("january has 31 days", calendar.monthrange(2024, 1)[1] == 31)
    test("feb leap has 29 days", calendar.monthrange(2024, 2)[1] == 29)
    test("feb non-leap has 28 days", calendar.monthrange(2023, 2)[1] == 28)
    test("april has 30 days", calendar.monthrange(2024, 4)[1] == 30)
else:
    for _ in range(4):
        skip("days_in_month tests", "not available")

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
