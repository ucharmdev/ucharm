"""
Simplified sys module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_sys.py
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


# ============================================================================
# sys.version tests
# ============================================================================

print("\n=== sys.version tests ===")

test("version exists", hasattr(sys, "version"))
test("version is string", isinstance(sys.version, str))
test("version not empty", len(sys.version) > 0)

if hasattr(sys, "version_info"):
    test("version_info exists", True)
    test(
        "version_info has major",
        hasattr(sys.version_info, "major") or len(sys.version_info) >= 1,
    )
    # Check major version is reasonable (3 for Python 3, or 1 for MicroPython 1.x)
    major = (
        sys.version_info[0]
        if isinstance(sys.version_info, tuple)
        else sys.version_info.major
    )
    test("version_info major", major >= 1)
else:
    skip("version_info tests", "version_info not available")


# ============================================================================
# sys.platform tests
# ============================================================================

print("\n=== sys.platform tests ===")

test("platform exists", hasattr(sys, "platform"))
test("platform is string", isinstance(sys.platform, str))
test("platform not empty", len(sys.platform) > 0)
test(
    "platform known",
    sys.platform
    in [
        "linux",
        "darwin",
        "win32",
        "cygwin",
        "freebsd",
        "rp2",
        "esp32",
        "pyboard",
        "unix",
    ],
)


# ============================================================================
# sys.path tests
# ============================================================================

print("\n=== sys.path tests ===")

test("path exists", hasattr(sys, "path"))
test("path is list", isinstance(sys.path, list))
# path can be empty in some embedded scenarios


# ============================================================================
# sys.modules tests
# ============================================================================

print("\n=== sys.modules tests ===")

test("modules exists", hasattr(sys, "modules"))
test("modules is dict", isinstance(sys.modules, dict))
# Note: MicroPython's sys.modules is always empty - modules are not tracked
# This is a fundamental difference from CPython
if len(sys.modules) > 0:
    test("sys in modules", "sys" in sys.modules)
    test("modules not empty", len(sys.modules) > 0)
else:
    skip("sys in modules", "MicroPython sys.modules is empty")
    skip("modules not empty", "MicroPython sys.modules is empty")


# ============================================================================
# sys.argv tests
# ============================================================================

print("\n=== sys.argv tests ===")

test("argv exists", hasattr(sys, "argv"))
test("argv is list", isinstance(sys.argv, list))
# argv[0] should be the script name or empty


# ============================================================================
# sys.stdin/stdout/stderr tests
# ============================================================================

print("\n=== sys.stdin/stdout/stderr tests ===")

test("stdin exists", hasattr(sys, "stdin"))
test("stdout exists", hasattr(sys, "stdout"))
test("stderr exists", hasattr(sys, "stderr"))

# Check stdout has write method
if hasattr(sys, "stdout") and sys.stdout is not None:
    test("stdout has write", hasattr(sys.stdout, "write"))
else:
    skip("stdout has write", "stdout is None")

# Check stderr has write method
if hasattr(sys, "stderr") and sys.stderr is not None:
    test("stderr has write", hasattr(sys.stderr, "write"))
else:
    skip("stderr has write", "stderr is None")


# ============================================================================
# sys.exit() tests
# ============================================================================

print("\n=== sys.exit() tests ===")

test("exit exists", hasattr(sys, "exit"))
test("exit is callable", callable(sys.exit))

# Test that SystemExit is raised (but don't actually exit)
try:
    sys.exit(0)
    test("exit raises SystemExit", False)
except SystemExit as e:
    test("exit raises SystemExit", True)
    test("exit code", e.args[0] == 0 if e.args else True)


# ============================================================================
# sys.maxsize tests
# ============================================================================

print("\n=== sys.maxsize tests ===")

if hasattr(sys, "maxsize"):
    test("maxsize exists", True)
    test("maxsize is int", isinstance(sys.maxsize, int))
    test("maxsize is large", sys.maxsize > 2**30)  # At least 32-bit
else:
    skip("maxsize tests", "maxsize not available")


# ============================================================================
# sys.byteorder tests
# ============================================================================

print("\n=== sys.byteorder tests ===")

if hasattr(sys, "byteorder"):
    test("byteorder exists", True)
    test("byteorder is string", isinstance(sys.byteorder, str))
    test("byteorder value", sys.byteorder in ["little", "big"])
else:
    skip("byteorder tests", "byteorder not available")


# ============================================================================
# sys.implementation tests
# ============================================================================

print("\n=== sys.implementation tests ===")

if hasattr(sys, "implementation"):
    test("implementation exists", True)
    test("implementation has name", hasattr(sys.implementation, "name"))
    test("implementation name is string", isinstance(sys.implementation.name, str))
    test(
        "implementation known",
        sys.implementation.name
        in ["cpython", "micropython", "pypy", "jython", "ironpython"],
    )
else:
    skip("implementation tests", "implementation not available")


# ============================================================================
# sys.executable tests
# ============================================================================

print("\n=== sys.executable tests ===")

if hasattr(sys, "executable"):
    test("executable exists", True)
    test("executable is string", isinstance(sys.executable, str))
else:
    skip("executable tests", "executable not available")


# ============================================================================
# sys.getrecursionlimit()/setrecursionlimit() tests
# ============================================================================

print("\n=== Recursion limit tests ===")

if hasattr(sys, "getrecursionlimit"):
    limit = sys.getrecursionlimit()
    test("getrecursionlimit returns int", isinstance(limit, int))
    test("getrecursionlimit positive", limit > 0)

    if hasattr(sys, "setrecursionlimit"):
        # Save original
        original = sys.getrecursionlimit()

        # Set new limit
        sys.setrecursionlimit(500)
        test("setrecursionlimit works", sys.getrecursionlimit() == 500)

        # Restore original
        sys.setrecursionlimit(original)
        test("setrecursionlimit restore", sys.getrecursionlimit() == original)
    else:
        skip("setrecursionlimit", "not available")
else:
    skip("recursion limit tests", "getrecursionlimit not available")


# ============================================================================
# sys.getsizeof() tests (if available)
# ============================================================================

print("\n=== sys.getsizeof() tests ===")

if hasattr(sys, "getsizeof"):
    # Basic objects
    test("getsizeof int", sys.getsizeof(0) > 0)
    test("getsizeof str", sys.getsizeof("hello") > 0)
    test("getsizeof list", sys.getsizeof([]) > 0)
    test("getsizeof dict", sys.getsizeof({}) > 0)

    # Larger objects are bigger
    test("getsizeof bigger list", sys.getsizeof([1, 2, 3]) >= sys.getsizeof([]))
else:
    skip("getsizeof tests", "getsizeof not available")


# ============================================================================
# sys.intern() tests (if available)
# ============================================================================

print("\n=== sys.intern() tests ===")

if hasattr(sys, "intern"):
    s = sys.intern("hello")
    test("intern returns string", isinstance(s, str))
    test("intern same value", s == "hello")

    # Interned strings should be identical
    s1 = sys.intern("test_string")
    s2 = sys.intern("test_string")
    test("intern same identity", s1 is s2)
else:
    skip("intern tests", "intern not available")


# ============================================================================
# sys.flags tests (if available)
# ============================================================================

print("\n=== sys.flags tests ===")

if hasattr(sys, "flags"):
    test("flags exists", True)
else:
    skip("flags tests", "flags not available")


# ============================================================================
# Summary
# ============================================================================

print("\n" + "=" * 50)
print(f"Results: {_passed} passed, {_failed} failed, {_skipped} skipped")
if _errors:
    print("Failed tests:")
    for e in _errors:
        print(f"  - {e}")
    # Don't exit here since we tested exit above
else:
    print("All tests passed!")
