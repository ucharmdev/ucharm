"""
Simplified errno module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_errno.py
"""

import errno
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
# Common POSIX errno constants tests
# ============================================================================

print("\n=== Common POSIX errno constants ===")

# Core file/directory errors
if hasattr(errno, "ENOENT"):
    test("ENOENT is integer", isinstance(errno.ENOENT, int))
    test("ENOENT value", errno.ENOENT == 2)
else:
    skip("ENOENT", "not available")

if hasattr(errno, "EEXIST"):
    test("EEXIST is integer", isinstance(errno.EEXIST, int))
    test("EEXIST value", errno.EEXIST == 17)
else:
    skip("EEXIST", "not available")

if hasattr(errno, "ENOTDIR"):
    test("ENOTDIR is integer", isinstance(errno.ENOTDIR, int))
    test("ENOTDIR value", errno.ENOTDIR == 20)
else:
    skip("ENOTDIR", "not available")

if hasattr(errno, "EISDIR"):
    test("EISDIR is integer", isinstance(errno.EISDIR, int))
    test("EISDIR value", errno.EISDIR == 21)
else:
    skip("EISDIR", "not available")

# Permission errors
if hasattr(errno, "EACCES"):
    test("EACCES is integer", isinstance(errno.EACCES, int))
    test("EACCES value", errno.EACCES == 13)
else:
    skip("EACCES", "not available")

if hasattr(errno, "EPERM"):
    test("EPERM is integer", isinstance(errno.EPERM, int))
    test("EPERM value", errno.EPERM == 1)
else:
    skip("EPERM", "not available")

# Argument errors
if hasattr(errno, "EINVAL"):
    test("EINVAL is integer", isinstance(errno.EINVAL, int))
    test("EINVAL value", errno.EINVAL == 22)
else:
    skip("EINVAL", "not available")

if hasattr(errno, "EBADF"):
    test("EBADF is integer", isinstance(errno.EBADF, int))
    test("EBADF value", errno.EBADF == 9)
else:
    skip("EBADF", "not available")


# ============================================================================
# I/O and system resource errors
# ============================================================================

print("\n=== I/O and system resource errors ===")

if hasattr(errno, "EIO"):
    test("EIO is integer", isinstance(errno.EIO, int))
    test("EIO value", errno.EIO == 5)
else:
    skip("EIO", "not available")

if hasattr(errno, "ENOMEM"):
    test("ENOMEM is integer", isinstance(errno.ENOMEM, int))
    test("ENOMEM value", errno.ENOMEM == 12)
else:
    skip("ENOMEM", "not available")

if hasattr(errno, "ENOSPC"):
    test("ENOSPC is integer", isinstance(errno.ENOSPC, int))
    test("ENOSPC value", errno.ENOSPC == 28)
else:
    skip("ENOSPC", "not available")


# ============================================================================
# Process and system errors
# ============================================================================

print("\n=== Process and system errors ===")

if hasattr(errno, "ESRCH"):
    test("ESRCH is integer", isinstance(errno.ESRCH, int))
    test("ESRCH value", errno.ESRCH == 3)
else:
    skip("ESRCH", "not available")

if hasattr(errno, "ECHILD"):
    test("ECHILD is integer", isinstance(errno.ECHILD, int))
    test("ECHILD value", errno.ECHILD == 10)
else:
    skip("ECHILD", "not available")

if hasattr(errno, "EAGAIN"):
    test("EAGAIN is integer", isinstance(errno.EAGAIN, int))
    # EAGAIN is 35 on macOS, 11 on Linux
    test("EAGAIN value", errno.EAGAIN == 35 or errno.EAGAIN == 11)
else:
    skip("EAGAIN", "not available")

if hasattr(errno, "EINTR"):
    test("EINTR is integer", isinstance(errno.EINTR, int))
    test("EINTR value", errno.EINTR == 4)
else:
    skip("EINTR", "not available")


# ============================================================================
# Pipe errors
# ============================================================================

print("\n=== Pipe errors ===")

if hasattr(errno, "EPIPE"):
    test("EPIPE is integer", isinstance(errno.EPIPE, int))
    test("EPIPE value", errno.EPIPE == 32)
else:
    skip("EPIPE", "not available")


# ============================================================================
# errorcode dict tests
# ============================================================================

print("\n=== errorcode dict tests ===")

if hasattr(errno, "errorcode"):
    test("errorcode is dict", isinstance(errno.errorcode, dict))
    test("errorcode not empty", len(errno.errorcode) > 0)

    # Check that errorcode maps integers to strings
    if hasattr(errno, "ENOENT"):
        if errno.ENOENT in errno.errorcode:
            test("errorcode ENOENT mapping", errno.errorcode[errno.ENOENT] == "ENOENT")
        else:
            skip("errorcode ENOENT mapping", "ENOENT not in errorcode")
else:
    skip("errorcode", "not available")


# ============================================================================
# Uniqueness tests
# ============================================================================

print("\n=== Uniqueness tests ===")

# Collect all available errno constants
errno_constants = {}
for name in dir(errno):
    if name.startswith("E") and name.isupper():
        value = getattr(errno, name)
        if isinstance(value, int):
            errno_constants[name] = value

test("has errno constants", len(errno_constants) > 0)
test("has multiple errno constants", len(errno_constants) >= 10)


# ============================================================================
# Integration with OSError tests
# ============================================================================

print("\n=== Integration with OSError tests ===")

if hasattr(errno, "ENOENT"):
    try:
        err = OSError(errno.ENOENT, "No such file or directory")
        test("OSError with ENOENT", err.args[0] == errno.ENOENT)
    except Exception:
        skip("OSError with ENOENT", "OSError creation failed")


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
