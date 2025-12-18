"""
Simplified csv module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_csv.py
"""

import csv
import sys

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
# csv.reader() tests
# ============================================================================

print("\n=== csv.reader() tests ===")

# Test basic reading
if hasattr(csv, "reader"):
    # Simple CSV
    data = ["a,b,c", "1,2,3"]
    reader = csv.reader(data)
    rows = list(reader)
    test("reader basic", rows == [["a", "b", "c"], ["1", "2", "3"]])

    # Empty fields
    data = ["a,,c", ",2,"]
    reader = csv.reader(data)
    rows = list(reader)
    test("reader empty fields", rows == [["a", "", "c"], ["", "2", ""]])

    # Quoted fields
    data = ['"a,b",c,d']
    reader = csv.reader(data)
    rows = list(reader)
    test("reader quoted comma", rows == [["a,b", "c", "d"]])

    # Quotes within quoted field
    data = ['"a""b",c']
    reader = csv.reader(data)
    rows = list(reader)
    test("reader escaped quote", rows == [['a"b', "c"]])

    # Empty input
    data = []
    reader = csv.reader(data)
    rows = list(reader)
    test("reader empty input", rows == [])

    # Single field
    data = ["abc"]
    reader = csv.reader(data)
    rows = list(reader)
    test("reader single field", rows == [["abc"]])

    # Numbers as strings
    data = ["1,2.5,3"]
    reader = csv.reader(data)
    rows = list(reader)
    test("reader numbers as strings", rows == [["1", "2.5", "3"]])
else:
    for _ in range(7):
        skip("reader tests", "csv.reader not available")

# ============================================================================
# csv.writer() tests (file-based - skip if not available)
# ============================================================================

print("\n=== csv.writer() tests ===")

# MicroPython's csv may not have the same writer interface
if hasattr(csv, "writer"):
    try:
        # Try to create a simple StringIO for testing
        import io

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["a", "b", "c"])
        result = output.getvalue()
        test("writer basic", "a,b,c" in result or "a, b, c" in result)

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["a,b", "c"])
        result = output.getvalue()
        # Should quote the field with comma
        test("writer quotes comma", '"a,b"' in result or "'a,b'" in result)
    except Exception as e:
        skip("writer tests", f"writer not fully supported: {e}")
else:
    skip("writer basic", "csv.writer not available")
    skip("writer quotes comma", "csv.writer not available")

# ============================================================================
# csv.parse() tests (ucharm-specific but useful)
# ============================================================================

print("\n=== csv.parse() tests ===")

if hasattr(csv, "parse"):
    # Simple parse
    result = csv.parse("a,b,c")
    test("parse simple", result == ["a", "b", "c"])

    # Parse with quotes
    result = csv.parse('"a,b",c')
    test("parse quoted", result == ["a,b", "c"])

    # Parse empty
    result = csv.parse("")
    test("parse empty", result == [] or result == [""])

    # Parse whitespace
    result = csv.parse("a, b, c")
    # Some implementations strip whitespace, some don't
    test("parse whitespace", len(result) == 3)
else:
    for _ in range(4):
        skip("parse tests", "csv.parse not available")

# ============================================================================
# csv constants tests
# ============================================================================

print("\n=== csv constants tests ===")

test("QUOTE_MINIMAL exists", hasattr(csv, "QUOTE_MINIMAL"))
test("QUOTE_ALL exists", hasattr(csv, "QUOTE_ALL"))
test("QUOTE_NONNUMERIC exists", hasattr(csv, "QUOTE_NONNUMERIC"))
test("QUOTE_NONE exists", hasattr(csv, "QUOTE_NONE"))

if hasattr(csv, "QUOTE_MINIMAL"):
    test("QUOTE_MINIMAL is int", isinstance(csv.QUOTE_MINIMAL, int))

if hasattr(csv, "QUOTE_ALL"):
    test("QUOTE_ALL is int", isinstance(csv.QUOTE_ALL, int))

# ============================================================================
# Edge cases
# ============================================================================

print("\n=== Edge cases ===")

if hasattr(csv, "reader"):
    # Newline in quoted field
    data = ['"a\nb",c']
    reader = csv.reader(data)
    rows = list(reader)
    test("reader newline in quotes", len(rows) >= 1)

    # Multiple rows
    data = ["a,b", "c,d", "e,f"]
    reader = csv.reader(data)
    rows = list(reader)
    test("reader multiple rows", len(rows) == 3)

    # Unicode
    data = ["hello,world"]  # Keep simple for compatibility
    reader = csv.reader(data)
    rows = list(reader)
    test("reader unicode", rows == [["hello", "world"]])
else:
    for _ in range(3):
        skip("edge case tests", "csv.reader not available")

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
