#!/usr/bin/env python3
"""
Test suite: Verify microcharm compat modules match CPython behavior.

This test runs on CPython and compares our compat implementations
against the real stdlib to ensure correctness.

Run with:
    python3 tests/test_compat_vs_cpython.py
"""

import os
import sys

# Add project to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Track test results
_passed = 0
_failed = 0
_errors = []


def test(name, condition, details=""):
    """Record a test result."""
    global _passed, _failed, _errors
    if condition:
        _passed += 1
        print(f"  ✓ {name}")
    else:
        _failed += 1
        _errors.append((name, details))
        print(f"  ✗ {name}: {details}")


def approx_equal(a, b, tol=1e-9):
    """Check if two floats are approximately equal."""
    if a == b:
        return True
    return abs(a - b) < tol


def test_base64():
    """Test base64 encoding/decoding matches CPython."""
    print("\n=== BASE64 ===")

    import base64 as cpython_base64

    from microcharm.compat import base64 as compat_base64

    test_cases = [
        b"",
        b"a",
        b"ab",
        b"abc",
        b"Hello, World!",
        b"x" * 100,
        b"\x00\x01\x02\xff\xfe\xfd",
        b"The quick brown fox jumps over the lazy dog",
    ]

    for data in test_cases:
        # b64encode
        expected = cpython_base64.b64encode(data)
        actual = compat_base64.b64encode(data)
        test(
            f"b64encode({data[:20]}...)" if len(data) > 20 else f"b64encode({data})",
            expected == actual,
            f"expected {expected}, got {actual}",
        )

        # b64decode
        expected = cpython_base64.b64decode(expected)
        actual = compat_base64.b64decode(actual)
        test(
            f"b64decode roundtrip",
            expected == actual,
            f"expected {expected}, got {actual}",
        )

    # URL-safe variants
    for data in test_cases:
        expected = cpython_base64.urlsafe_b64encode(data)
        actual = compat_base64.urlsafe_b64encode(data)
        test(
            f"urlsafe_b64encode",
            expected == actual,
            f"expected {expected}, got {actual}",
        )

    # b16 (hex)
    for data in test_cases[:5]:
        expected = cpython_base64.b16encode(data)
        actual = compat_base64.b16encode(data)
        test(
            f"b16encode({data})",
            expected == actual,
            f"expected {expected}, got {actual}",
        )

    # b32
    for data in test_cases[:5]:
        expected = cpython_base64.b32encode(data)
        actual = compat_base64.b32encode(data)
        test(
            f"b32encode({data})",
            expected == actual,
            f"expected {expected}, got {actual}",
        )


def test_datetime():
    """Test datetime operations match CPython."""
    print("\n=== DATETIME ===")

    import datetime as cpython_datetime

    from microcharm.compat import datetime as compat_datetime

    # Test datetime creation
    test_dates = [
        (2024, 1, 1, 0, 0, 0),
        (2024, 6, 15, 12, 30, 45),
        (2024, 12, 31, 23, 59, 59),
        (2000, 2, 29, 12, 0, 0),  # Leap year
        (1999, 12, 31, 23, 59, 59),
        (2100, 1, 1, 0, 0, 0),  # Not a leap year
    ]

    for y, m, d, h, mi, s in test_dates:
        cp_dt = cpython_datetime.datetime(y, m, d, h, mi, s)
        compat_dt = compat_datetime.datetime(y, m, d, h, mi, s)

        # isoformat
        test(
            f"datetime({y},{m},{d}).isoformat()",
            cp_dt.isoformat() == compat_dt.isoformat(),
            f"expected {cp_dt.isoformat()}, got {compat_dt.isoformat()}",
        )

        # weekday
        test(
            f"datetime({y},{m},{d}).weekday()",
            cp_dt.weekday() == compat_dt.weekday(),
            f"expected {cp_dt.weekday()}, got {compat_dt.weekday()}",
        )

        # isoweekday
        test(
            f"datetime({y},{m},{d}).isoweekday()",
            cp_dt.isoweekday() == compat_dt.isoweekday(),
            f"expected {cp_dt.isoweekday()}, got {compat_dt.isoweekday()}",
        )

    # Test timedelta
    timedelta_cases = [
        {"days": 1},
        {"hours": 12},
        {"minutes": 30},
        {"seconds": 45},
        {"days": 5, "hours": 3, "minutes": 30},
        {"days": -1},
        {"hours": 25},  # Should normalize
        {"seconds": 3661},  # 1 hour, 1 minute, 1 second
    ]

    for kwargs in timedelta_cases:
        cp_td = cpython_datetime.timedelta(**kwargs)
        compat_td = compat_datetime.timedelta(**kwargs)

        test(
            f"timedelta({kwargs}).total_seconds()",
            approx_equal(cp_td.total_seconds(), compat_td.total_seconds()),
            f"expected {cp_td.total_seconds()}, got {compat_td.total_seconds()}",
        )

        test(
            f"timedelta({kwargs}).days",
            cp_td.days == compat_td.days,
            f"expected {cp_td.days}, got {compat_td.days}",
        )

    # Test datetime arithmetic
    dt = compat_datetime.datetime(2024, 6, 15, 12, 0, 0)
    td = compat_datetime.timedelta(days=10)
    result = dt + td

    cp_dt = cpython_datetime.datetime(2024, 6, 15, 12, 0, 0)
    cp_td = cpython_datetime.timedelta(days=10)
    cp_result = cp_dt + cp_td

    test(
        "datetime + timedelta",
        result.isoformat() == cp_result.isoformat(),
        f"expected {cp_result.isoformat()}, got {result.isoformat()}",
    )


def test_fnmatch():
    """Test fnmatch pattern matching matches CPython."""
    print("\n=== FNMATCH ===")

    import fnmatch as cpython_fnmatch

    from microcharm.compat import fnmatch as compat_fnmatch

    test_cases = [
        # (name, pattern, expected_match)
        ("test.py", "*.py", True),
        ("test.py", "*.txt", False),
        ("test.py", "test.*", True),
        ("test.py", "????.py", True),
        ("test.py", "???.py", False),
        ("test.py", "t*.py", True),
        ("test.py", "[a-z]*.py", True),
        ("Test.py", "[a-z]*.py", False),  # Case sensitive
        ("test.py", "[!a-z]*.py", False),
        ("1test.py", "[!a-z]*.py", True),
        ("abc", "a*c", True),
        ("abc", "a?c", True),
        ("ac", "a*c", True),
        ("ac", "a?c", False),
        ("file.tar.gz", "*.tar.gz", True),
        ("file.tar.gz", "*.gz", True),
        ("", "*", True),
        ("", "?", False),
        ("a", "*", True),
        ("abc", "[abc][abc][abc]", True),
        ("abd", "[abc][abc][abc]", False),
    ]

    for name, pattern, _ in test_cases:
        expected = cpython_fnmatch.fnmatch(name, pattern)
        actual = compat_fnmatch.fnmatch(name, pattern)
        test(
            f"fnmatch('{name}', '{pattern}')",
            expected == actual,
            f"expected {expected}, got {actual}",
        )

    # Test filter
    names = ["test.py", "main.py", "data.txt", "config.json", "app.py"]
    pattern = "*.py"
    expected = cpython_fnmatch.filter(names, pattern)
    actual = compat_fnmatch.filter(names, pattern)
    test(
        f"filter({names}, '{pattern}')",
        expected == actual,
        f"expected {expected}, got {actual}",
    )


def test_statistics():
    """Test statistics functions match CPython."""
    print("\n=== STATISTICS ===")

    import statistics as cpython_stats

    from microcharm.compat import statistics as compat_stats

    test_data = [
        [1, 2, 3, 4, 5],
        [1.5, 2.5, 3.5],
        [10, 20, 30, 40, 50, 60],
        [1, 1, 2, 3, 5, 8, 13],  # Fibonacci-ish
        [100],
        [1, 2],
        [-5, -3, 0, 3, 5],
        [0.1, 0.2, 0.3, 0.4, 0.5],
    ]

    for data in test_data:
        # mean
        expected = cpython_stats.mean(data)
        actual = compat_stats.mean(data)
        test(
            f"mean({data})",
            approx_equal(expected, actual),
            f"expected {expected}, got {actual}",
        )

        # median
        expected = cpython_stats.median(data)
        actual = compat_stats.median(data)
        test(
            f"median({data})",
            approx_equal(expected, actual),
            f"expected {expected}, got {actual}",
        )

        if len(data) >= 2:
            # stdev (sample)
            expected = cpython_stats.stdev(data)
            actual = compat_stats.stdev(data)
            test(
                f"stdev({data})",
                approx_equal(expected, actual, tol=1e-6),
                f"expected {expected}, got {actual}",
            )

            # variance (sample)
            expected = cpython_stats.variance(data)
            actual = compat_stats.variance(data)
            test(
                f"variance({data})",
                approx_equal(expected, actual, tol=1e-6),
                f"expected {expected}, got {actual}",
            )

            # pstdev (population)
            expected = cpython_stats.pstdev(data)
            actual = compat_stats.pstdev(data)
            test(
                f"pstdev({data})",
                approx_equal(expected, actual, tol=1e-6),
                f"expected {expected}, got {actual}",
            )

            # pvariance (population)
            expected = cpython_stats.pvariance(data)
            actual = compat_stats.pvariance(data)
            test(
                f"pvariance({data})",
                approx_equal(expected, actual, tol=1e-6),
                f"expected {expected}, got {actual}",
            )

    # geometric_mean (only positive values)
    positive_data = [[1, 2, 3, 4], [10, 100, 1000], [1.5, 2.5, 3.5]]
    for data in positive_data:
        expected = cpython_stats.geometric_mean(data)
        actual = compat_stats.geometric_mean(data)
        test(
            f"geometric_mean({data})",
            approx_equal(expected, actual, tol=1e-6),
            f"expected {expected}, got {actual}",
        )

    # harmonic_mean (only positive values)
    for data in positive_data:
        expected = cpython_stats.harmonic_mean(data)
        actual = compat_stats.harmonic_mean(data)
        test(
            f"harmonic_mean({data})",
            approx_equal(expected, actual, tol=1e-6),
            f"expected {expected}, got {actual}",
        )


def test_textwrap():
    """Test textwrap functions match CPython."""
    print("\n=== TEXTWRAP ===")

    import textwrap as cpython_textwrap

    from microcharm.compat import textwrap as compat_textwrap

    test_strings = [
        "Hello world",
        "The quick brown fox jumps over the lazy dog",
        "This is a longer text that should be wrapped across multiple lines when the width is set appropriately.",
        "Short",
        "",
        "Word " * 20,
    ]

    for text in test_strings:
        if not text:
            continue

        # wrap
        expected = cpython_textwrap.wrap(text, width=20)
        actual = compat_textwrap.wrap(text, width=20)
        test(
            f"wrap('{text[:20]}...', 20)" if len(text) > 20 else f"wrap('{text}', 20)",
            expected == actual,
            f"expected {expected}, got {actual}",
        )

        # fill
        expected = cpython_textwrap.fill(text, width=20)
        actual = compat_textwrap.fill(text, width=20)
        test(
            f"fill('{text[:20]}...', 20)" if len(text) > 20 else f"fill('{text}', 20)",
            expected == actual,
            f"expected {expected!r}, got {actual!r}",
        )

    # dedent
    dedent_tests = [
        "    line1\n    line2\n    line3",
        "\t\ttabbed\n\t\tlines",
        "  mixed\n    indents",  # Different indents
        "no indent",
    ]

    for text in dedent_tests:
        expected = cpython_textwrap.dedent(text)
        actual = compat_textwrap.dedent(text)
        test(
            f"dedent('{text[:20]}...')" if len(text) > 20 else f"dedent('{text}')",
            expected == actual,
            f"expected {expected!r}, got {actual!r}",
        )

    # indent
    indent_tests = [
        ("line1\nline2\nline3", "  "),
        ("hello\nworld", ">>> "),
    ]

    for text, prefix in indent_tests:
        expected = cpython_textwrap.indent(text, prefix)
        actual = compat_textwrap.indent(text, prefix)
        test(
            f"indent('{text}', '{prefix}')",
            expected == actual,
            f"expected {expected!r}, got {actual!r}",
        )


def test_copy():
    """Test copy functions match CPython."""
    print("\n=== COPY ===")

    import copy as cpython_copy

    from microcharm.compat import copy as compat_copy

    # Simple types (should be identical)
    simple_values = [1, 3.14, "hello", True, None, (1, 2, 3)]

    for val in simple_values:
        expected = cpython_copy.copy(val)
        actual = compat_copy.copy(val)
        test(f"copy({val})", expected == actual, f"expected {expected}, got {actual}")

    # Lists
    lst = [1, 2, [3, 4], {"a": 1}]

    cp_shallow = cpython_copy.copy(lst)
    compat_shallow = compat_copy.copy(lst)
    test(
        "copy(list) - shallow",
        cp_shallow == compat_shallow,
        f"expected {cp_shallow}, got {compat_shallow}",
    )

    cp_deep = cpython_copy.deepcopy(lst)
    compat_deep = compat_copy.deepcopy(lst)
    test(
        "deepcopy(list)",
        cp_deep == compat_deep,
        f"expected {cp_deep}, got {compat_deep}",
    )

    # Verify deep copy is actually deep
    compat_deep[2][0] = 999
    test(
        "deepcopy creates independent copy",
        lst[2][0] == 3,  # Original unchanged
        f"original was modified: {lst}",
    )

    # Dicts
    d = {"a": 1, "b": [2, 3], "c": {"nested": True}}

    cp_shallow = cpython_copy.copy(d)
    compat_shallow = compat_copy.copy(d)
    test(
        "copy(dict) - shallow",
        cp_shallow == compat_shallow,
        f"expected {cp_shallow}, got {compat_shallow}",
    )

    cp_deep = cpython_copy.deepcopy(d)
    compat_deep = compat_copy.deepcopy(d)
    test(
        "deepcopy(dict)",
        cp_deep == compat_deep,
        f"expected {cp_deep}, got {compat_deep}",
    )


def test_functools():
    """Test functools functions match CPython."""
    print("\n=== FUNCTOOLS ===")

    import functools as cpython_functools

    from microcharm.compat import functools as compat_functools

    # reduce
    test_cases = [
        (lambda x, y: x + y, [1, 2, 3, 4, 5]),
        (lambda x, y: x * y, [1, 2, 3, 4, 5]),
        (lambda x, y: x + y, ["a", "b", "c"]),
    ]

    for func, data in test_cases:
        expected = cpython_functools.reduce(func, data)
        actual = compat_functools.reduce(func, data)
        test(
            f"reduce(+, {data})",
            expected == actual,
            f"expected {expected}, got {actual}",
        )

    # reduce with initial
    expected = cpython_functools.reduce(lambda x, y: x + y, [1, 2, 3], 10)
    actual = compat_functools.reduce(lambda x, y: x + y, [1, 2, 3], 10)
    test(
        "reduce(+, [1,2,3], 10)",
        expected == actual,
        f"expected {expected}, got {actual}",
    )

    # partial
    def add(a, b, c):
        return a + b + c

    cp_partial = cpython_functools.partial(add, 1, 2)
    compat_partial = compat_functools.partial(add, 1, 2)

    test(
        "partial(add, 1, 2)(3)",
        cp_partial(3) == compat_partial(3),
        f"expected {cp_partial(3)}, got {compat_partial(3)}",
    )

    # partial with kwargs
    def greet(name, greeting="Hello"):
        return f"{greeting}, {name}!"

    cp_partial = cpython_functools.partial(greet, greeting="Hi")
    compat_partial = compat_functools.partial(greet, greeting="Hi")

    test(
        "partial with kwargs",
        cp_partial("World") == compat_partial("World"),
        f"expected {cp_partial('World')}, got {compat_partial('World')}",
    )

    # cmp_to_key
    def compare(a, b):
        return (a > b) - (a < b)

    data = [3, 1, 4, 1, 5, 9, 2, 6]
    cp_sorted = sorted(data, key=cpython_functools.cmp_to_key(compare))
    compat_sorted = sorted(data, key=compat_functools.cmp_to_key(compare))
    test(
        "cmp_to_key sorting",
        cp_sorted == compat_sorted,
        f"expected {cp_sorted}, got {compat_sorted}",
    )


def test_pathlib():
    """Test pathlib Path operations match CPython."""
    print("\n=== PATHLIB ===")

    from pathlib import Path as CPythonPath

    from microcharm.compat.pathlib import Path as CompatPath

    test_paths = [
        "/usr/local/bin/python",
        "/home/user/file.txt",
        "relative/path/to/file.py",
        ".",
        "..",
        "/",
        "file.tar.gz",
        "/path/to/directory/",
    ]

    for p in test_paths:
        cp_path = CPythonPath(p)
        compat_path = CompatPath(p)

        # name
        test(
            f"Path('{p}').name",
            cp_path.name == compat_path.name,
            f"expected {cp_path.name}, got {compat_path.name}",
        )

        # stem
        test(
            f"Path('{p}').stem",
            cp_path.stem == compat_path.stem,
            f"expected {cp_path.stem}, got {compat_path.stem}",
        )

        # suffix
        test(
            f"Path('{p}').suffix",
            cp_path.suffix == compat_path.suffix,
            f"expected {cp_path.suffix}, got {compat_path.suffix}",
        )

        # parent (as string)
        test(
            f"Path('{p}').parent",
            str(cp_path.parent) == str(compat_path.parent),
            f"expected {cp_path.parent}, got {compat_path.parent}",
        )

        # is_absolute
        test(
            f"Path('{p}').is_absolute()",
            cp_path.is_absolute() == compat_path.is_absolute(),
            f"expected {cp_path.is_absolute()}, got {compat_path.is_absolute()}",
        )

    # Test / operator
    cp_joined = CPythonPath("/usr") / "local" / "bin"
    compat_joined = CompatPath("/usr") / "local" / "bin"
    test(
        "Path('/usr') / 'local' / 'bin'",
        str(cp_joined) == str(compat_joined),
        f"expected {cp_joined}, got {compat_joined}",
    )

    # with_suffix
    cp_path = CPythonPath("file.txt")
    compat_path = CompatPath("file.txt")
    test(
        "Path('file.txt').with_suffix('.py')",
        str(cp_path.with_suffix(".py")) == str(compat_path.with_suffix(".py")),
        f"expected {cp_path.with_suffix('.py')}, got {compat_path.with_suffix('.py')}",
    )

    # with_name
    test(
        "Path('file.txt').with_name('other.md')",
        str(cp_path.with_name("other.md")) == str(compat_path.with_name("other.md")),
        f"expected {cp_path.with_name('other.md')}, got {compat_path.with_name('other.md')}",
    )


def main():
    """Run all tests."""
    print("=" * 60)
    print("Compat Module Test Suite: Comparing to CPython")
    print("=" * 60)
    print(f"Python: {sys.implementation.name} {sys.version.split()[0]}")

    test_base64()
    test_datetime()
    test_fnmatch()
    test_statistics()
    test_textwrap()
    test_copy()
    test_functools()
    test_pathlib()

    print("\n" + "=" * 60)
    print(f"RESULTS: {_passed} passed, {_failed} failed")
    print("=" * 60)

    if _errors:
        print("\nFailed tests:")
        for name, details in _errors:
            print(f"  - {name}: {details}")
        return 1
    else:
        print("\nAll tests passed! ✓")
        return 0


if __name__ == "__main__":
    sys.exit(main())
