#!/usr/bin/env python3
"""
Test suite for csv module - compares μcharm native vs CPython implementation.

Run with:
  python3 test_csv.py          # Test CPython implementation
  micropython test_csv.py      # Test μcharm implementation
"""

import sys
import time

# Detect runtime
IS_MICROPYTHON = sys.implementation.name == "micropython"
RUNTIME = "μcharm" if IS_MICROPYTHON else "CPython"

import csv

# For file operations
if IS_MICROPYTHON:
    try:
        import io

        StringIO = io.StringIO
    except:
        # Fallback for older micropython
        class StringIO:
            def __init__(self, initial=""):
                self._data = initial
                self._pos = 0
                self._written = ""

            def write(self, s):
                self._written += s
                return len(s)

            def getvalue(self):
                return self._written if self._written else self._data

            def __iter__(self):
                return iter(self._data.split("\n"))
else:
    from io import StringIO


def test_parse_simple():
    """Test parsing simple CSV line"""
    if IS_MICROPYTHON:
        result = csv.parse("a,b,c")
    else:
        reader = csv.reader(["a,b,c"])
        result = next(reader)

    assert result == ["a", "b", "c"], f"Expected ['a', 'b', 'c'], got {result}"
    print(f"  [PASS] parse simple: {result}")


def test_parse_quoted():
    """Test parsing quoted fields"""
    if IS_MICROPYTHON:
        result = csv.parse('"hello, world",b,c')
    else:
        reader = csv.reader(['"hello, world",b,c'])
        result = next(reader)

    assert result[0] == "hello, world", f"Expected 'hello, world', got {result[0]}"
    print(f"  [PASS] parse quoted: {result}")


def test_parse_escaped_quote():
    """Test parsing escaped quotes (doubled)"""
    if IS_MICROPYTHON:
        result = csv.parse('"say ""hello""",b')
    else:
        reader = csv.reader(['"say ""hello""",b'])
        result = next(reader)

    assert result[0] == 'say "hello"', f"Expected 'say \"hello\"', got {result[0]}"
    print(f"  [PASS] parse escaped quote: {result}")


def test_parse_empty_fields():
    """Test parsing empty fields"""
    if IS_MICROPYTHON:
        result = csv.parse("a,,c,")
    else:
        reader = csv.reader(["a,,c,"])
        result = next(reader)

    assert result == ["a", "", "c", ""], f"Expected ['a', '', 'c', ''], got {result}"
    print(f"  [PASS] parse empty fields: {result}")


def test_parse_newline_in_quoted():
    """Test parsing newline within quoted field"""
    if IS_MICROPYTHON:
        result = csv.parse('"line1\nline2",b')
    else:
        # CPython's reader handles this across lines, so simulate single line
        reader = csv.reader(['"line1\nline2",b'])
        result = next(reader)

    assert "line1" in result[0] and "line2" in result[0], (
        f"Expected newline preserved, got {result[0]}"
    )
    print(f"  [PASS] parse newline in quoted: {repr(result[0])}")


def test_parse_custom_delimiter():
    """Test parsing with custom delimiter"""
    if IS_MICROPYTHON:
        result = csv.parse("a;b;c", ";")
    else:
        reader = csv.reader(["a;b;c"], delimiter=";")
        result = next(reader)

    assert result == ["a", "b", "c"], f"Expected ['a', 'b', 'c'], got {result}"
    print(f"  [PASS] parse custom delimiter (;): {result}")


def test_parse_tab_delimiter():
    """Test parsing tab-delimited"""
    if IS_MICROPYTHON:
        result = csv.parse("a\tb\tc", "\t")
    else:
        reader = csv.reader(["a\tb\tc"], delimiter="\t")
        result = next(reader)

    assert result == ["a", "b", "c"], f"Expected ['a', 'b', 'c'], got {result}"
    print(f"  [PASS] parse tab delimiter: {result}")


def test_format_simple():
    """Test formatting simple fields"""
    if IS_MICROPYTHON:
        result = csv.format(["a", "b", "c"])
    else:
        output = StringIO()
        writer = csv.writer(output)
        writer.writerow(["a", "b", "c"])
        result = output.getvalue().strip()

    assert result == "a,b,c", f"Expected 'a,b,c', got {result}"
    print(f"  [PASS] format simple: {result}")


def test_format_needs_quoting():
    """Test formatting fields that need quoting"""
    if IS_MICROPYTHON:
        result = csv.format(["hello, world", "b"])
    else:
        output = StringIO()
        writer = csv.writer(output)
        writer.writerow(["hello, world", "b"])
        result = output.getvalue().strip()

    assert '"hello, world"' in result, f"Expected quoted field, got {result}"
    print(f"  [PASS] format needs quoting: {result}")


def test_format_with_quote():
    """Test formatting fields containing quotes"""
    if IS_MICROPYTHON:
        result = csv.format(['say "hello"', "b"])
    else:
        output = StringIO()
        writer = csv.writer(output)
        writer.writerow(['say "hello"', "b"])
        result = output.getvalue().strip()

    # Should be: "say ""hello""",b
    assert '""' in result, f"Expected escaped quote, got {result}"
    print(f"  [PASS] format with quote: {result}")


def test_reader_iteration():
    """Test reader iterating over lines"""
    data = "a,b,c\n1,2,3\nx,y,z"

    if IS_MICROPYTHON:
        rows = []
        for line in data.split("\n"):
            rows.append(csv.parse(line))
    else:
        reader = csv.reader(data.split("\n"))
        rows = list(reader)

    assert len(rows) == 3, f"Expected 3 rows, got {len(rows)}"
    assert rows[0] == ["a", "b", "c"]
    assert rows[1] == ["1", "2", "3"]
    assert rows[2] == ["x", "y", "z"]
    print(f"  [PASS] reader iteration: {len(rows)} rows")


def test_writer_basic():
    """Test writer basic functionality"""
    output = StringIO()

    if IS_MICROPYTHON:
        writer = csv.writer(output)
        writer.writerow(["a", "b", "c"])
        writer.writerow(["1", "2", "3"])
    else:
        writer = csv.writer(output)
        writer.writerow(["a", "b", "c"])
        writer.writerow(["1", "2", "3"])

    result = output.getvalue()
    assert "a,b,c" in result
    assert "1,2,3" in result
    print(f"  [PASS] writer basic: {repr(result[:30])}")


def test_roundtrip():
    """Test parsing formatted output gives same data"""
    original = ["hello, world", 'say "hi"', "normal"]

    if IS_MICROPYTHON:
        formatted = csv.format(original)
        parsed = csv.parse(formatted)
    else:
        output = StringIO()
        writer = csv.writer(output)
        writer.writerow(original)
        formatted = output.getvalue().strip()
        reader = csv.reader([formatted])
        parsed = next(reader)

    assert parsed == original, (
        f"Roundtrip failed: {original} -> {formatted} -> {parsed}"
    )
    print(f"  [PASS] roundtrip: {original}")


def test_dialect():
    """Test dialect settings (μcharm extension)"""
    if not IS_MICROPYTHON:
        print(f"  [SKIP] dialect settings - μcharm extension only")
        return

    # Get default dialect
    dialect = csv.get_dialect()
    assert dialect["delimiter"] == ","
    assert dialect["quotechar"] == '"'
    print(f"  [PASS] get_dialect: {dialect}")


# Performance benchmarks
def benchmark_parse():
    """Benchmark CSV parsing"""
    # Create test data
    lines = []
    for i in range(1000):
        lines.append(f'field1_{i},field2_{i},field3_{i},"quoted field {i}",last_{i}')

    start = time.time()
    iterations = 10

    for _ in range(iterations):
        for line in lines:
            if IS_MICROPYTHON:
                csv.parse(line)
            else:
                reader = csv.reader([line])
                next(reader)

    elapsed = time.time() - start
    ops = iterations * len(lines)
    ops_per_sec = ops / elapsed

    print(f"  Parse: {ops} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec")
    return elapsed


def benchmark_format():
    """Benchmark CSV formatting"""
    # Create test data
    rows = []
    for i in range(1000):
        rows.append(
            [
                f"field1_{i}",
                f"field2_{i}",
                f"field3_{i}",
                f"quoted, field {i}",
                f"last_{i}",
            ]
        )

    start = time.time()
    iterations = 10

    for _ in range(iterations):
        for row in rows:
            if IS_MICROPYTHON:
                csv.format(row)
            else:
                output = StringIO()
                writer = csv.writer(output)
                writer.writerow(row)

    elapsed = time.time() - start
    ops = iterations * len(rows)
    ops_per_sec = ops / elapsed

    print(f"  Format: {ops} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec")
    return elapsed


def run_tests():
    print(f"\n=== CSV Tests ({RUNTIME}) ===\n")

    print("Functional tests:")
    test_parse_simple()
    test_parse_quoted()
    test_parse_escaped_quote()
    test_parse_empty_fields()
    test_parse_newline_in_quoted()
    test_parse_custom_delimiter()
    test_parse_tab_delimiter()
    test_format_simple()
    test_format_needs_quoting()
    test_format_with_quote()
    test_reader_iteration()
    test_writer_basic()
    test_roundtrip()
    test_dialect()

    print(f"\nAll tests passed!")

    print(f"\nPerformance benchmarks:")
    parse_time = benchmark_parse()
    format_time = benchmark_format()

    return parse_time, format_time


if __name__ == "__main__":
    run_tests()
