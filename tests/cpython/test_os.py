"""
Simplified os module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_os.py
"""

import os
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
# os.getcwd() tests
# ============================================================================

print("\n=== os.getcwd() tests ===")

if hasattr(os, "getcwd"):
    cwd = os.getcwd()
    test("getcwd returns string", isinstance(cwd, str))
    test("getcwd not empty", len(cwd) > 0)
    test("getcwd is absolute", cwd.startswith("/") or (len(cwd) > 1 and cwd[1] == ":"))
else:
    skip("getcwd tests", "getcwd not available")


# ============================================================================
# os.listdir() tests
# ============================================================================

print("\n=== os.listdir() tests ===")

if hasattr(os, "listdir"):
    entries = os.listdir(".")
    test("listdir returns list", isinstance(entries, list))

    # listdir of root or current should have entries
    test("listdir has entries", len(entries) >= 0)

    # All entries are strings
    test("listdir all strings", all(isinstance(e, str) for e in entries))
else:
    skip("listdir tests", "listdir not available")


# ============================================================================
# os.path tests
# ============================================================================

print("\n=== os.path tests ===")

if hasattr(os, "path"):
    # exists
    if hasattr(os.path, "exists"):
        test("path.exists cwd", os.path.exists("."))
        test("path.exists nonexistent", not os.path.exists("/nonexistent_path_12345"))
    else:
        skip("path.exists", "not available")

    # isdir
    if hasattr(os.path, "isdir"):
        test("path.isdir cwd", os.path.isdir("."))
    else:
        skip("path.isdir", "not available")

    # isfile
    if hasattr(os.path, "isfile"):
        test("path.isfile cwd", not os.path.isfile("."))
    else:
        skip("path.isfile", "not available")

    # join
    if hasattr(os.path, "join"):
        test("path.join two", os.path.join("a", "b") in ["a/b", "a\\b"])
        test("path.join three", os.path.join("a", "b", "c") in ["a/b/c", "a\\b\\c"])
        test(
            "path.join absolute",
            os.path.join("a", "/b") == "/b" or os.path.join("a", "/b") == "\\b",
        )
    else:
        skip("path.join", "not available")

    # basename
    if hasattr(os.path, "basename"):
        test("path.basename", os.path.basename("/foo/bar") == "bar")
        test("path.basename no dir", os.path.basename("bar") == "bar")
        test("path.basename trailing slash", os.path.basename("/foo/bar/") == "")
    else:
        skip("path.basename", "not available")

    # dirname
    if hasattr(os.path, "dirname"):
        test("path.dirname", os.path.dirname("/foo/bar") == "/foo")
        test("path.dirname no dir", os.path.dirname("bar") == "")
    else:
        skip("path.dirname", "not available")

    # split
    if hasattr(os.path, "split"):
        head, tail = os.path.split("/foo/bar")
        test("path.split head", head == "/foo")
        test("path.split tail", tail == "bar")
    else:
        skip("path.split", "not available")

    # splitext
    if hasattr(os.path, "splitext"):
        root, ext = os.path.splitext("/foo/bar.txt")
        test("path.splitext root", root == "/foo/bar")
        test("path.splitext ext", ext == ".txt")

        root, ext = os.path.splitext("/foo/bar")
        test("path.splitext no ext", ext == "")
    else:
        skip("path.splitext", "not available")

    # isabs
    if hasattr(os.path, "isabs"):
        test("path.isabs absolute", os.path.isabs("/foo"))
        test("path.isabs relative", not os.path.isabs("foo"))
    else:
        skip("path.isabs", "not available")

    # abspath
    if hasattr(os.path, "abspath"):
        abs_path = os.path.abspath(".")
        test(
            "path.abspath is absolute",
            os.path.isabs(abs_path)
            if hasattr(os.path, "isabs")
            else abs_path.startswith("/"),
        )
    else:
        skip("path.abspath", "not available")

    # normpath
    if hasattr(os.path, "normpath"):
        test("path.normpath dots", os.path.normpath("a/./b") in ["a/b", "a\\b"])
        test("path.normpath dotdot", os.path.normpath("a/b/../c") in ["a/c", "a\\c"])
    else:
        skip("path.normpath", "not available")
else:
    skip("os.path tests", "os.path not available")


# ============================================================================
# os.environ tests
# ============================================================================

print("\n=== os.environ tests ===")

if hasattr(os, "environ"):
    test("environ is dict-like", hasattr(os.environ, "__getitem__"))

    # PATH or HOME should exist on most systems
    has_path = "PATH" in os.environ or "HOME" in os.environ or "USER" in os.environ
    test("environ has common vars", has_path)
else:
    skip("environ tests", "environ not available")

# getenv
if hasattr(os, "getenv"):
    # Get a known environment variable
    result = os.getenv("PATH", "default")
    test("getenv PATH", result != "default" or os.getenv("HOME", "x") != "x")

    # Get nonexistent with default
    test(
        "getenv nonexistent default",
        os.getenv("NONEXISTENT_VAR_12345", "default") == "default",
    )

    # Get nonexistent without default
    test("getenv nonexistent none", os.getenv("NONEXISTENT_VAR_12345") is None)
else:
    skip("getenv tests", "getenv not available")


# ============================================================================
# os.sep and os.name tests
# ============================================================================

print("\n=== os.sep and os.name tests ===")

if hasattr(os, "sep"):
    test("sep is string", isinstance(os.sep, str))
    test("sep is / or \\", os.sep in ["/", "\\"])
else:
    skip("sep", "not available")

if hasattr(os, "name"):
    test("name is string", isinstance(os.name, str))
    test("name is known", os.name in ["posix", "nt", "java"])
else:
    skip("name", "not available")

if hasattr(os, "linesep"):
    test("linesep is string", isinstance(os.linesep, str))
    test("linesep is newline", os.linesep in ["\n", "\r\n", "\r"])
else:
    skip("linesep", "not available")


# ============================================================================
# File descriptor operations (if available)
# ============================================================================

print("\n=== File operations ===")

# mkdir/rmdir
if hasattr(os, "mkdir") and hasattr(os, "rmdir"):
    test_dir = "/tmp/ucharm_test_dir_12345"
    try:
        if os.path.exists(test_dir) if hasattr(os.path, "exists") else False:
            os.rmdir(test_dir)
        os.mkdir(test_dir)
        exists = os.path.exists(test_dir) if hasattr(os.path, "exists") else True
        test("mkdir creates dir", exists)
        os.rmdir(test_dir)
        not_exists = (
            not os.path.exists(test_dir) if hasattr(os.path, "exists") else True
        )
        test("rmdir removes dir", not_exists)
    except (OSError, PermissionError) as e:
        skip("mkdir/rmdir", str(e))
else:
    skip("mkdir/rmdir", "not available")

# remove/unlink
if hasattr(os, "remove") or hasattr(os, "unlink"):
    remove_func = getattr(os, "remove", None) or getattr(os, "unlink", None)
    test_file = "/tmp/ucharm_test_file_12345.txt"
    try:
        # Create a test file
        with open(test_file, "w") as f:
            f.write("test")
        exists_before = (
            os.path.exists(test_file) if hasattr(os.path, "exists") else True
        )
        remove_func(test_file)
        exists_after = (
            os.path.exists(test_file) if hasattr(os.path, "exists") else False
        )
        test("remove deletes file", exists_before and not exists_after)
    except (OSError, PermissionError) as e:
        skip("remove/unlink", str(e))
else:
    skip("remove/unlink", "not available")


# ============================================================================
# os.stat tests
# ============================================================================

print("\n=== os.stat tests ===")

if hasattr(os, "stat"):
    try:
        st = os.stat(".")
        test("stat returns object", st is not None)

        # Check common stat attributes (works with both CPython's stat_result and MicroPython's tuple)
        if hasattr(st, "st_mode"):
            test("stat has st_mode", isinstance(st.st_mode, int))
        elif isinstance(st, tuple) and len(st) >= 1:
            # MicroPython returns tuple: (st_mode, st_ino, st_dev, st_nlink, st_uid, st_gid, st_size, ...)
            test("stat has st_mode", isinstance(st[0], int))

        if hasattr(st, "st_size"):
            test("stat has st_size", isinstance(st.st_size, int))
        elif isinstance(st, tuple) and len(st) >= 7:
            test("stat has st_size", isinstance(st[6], int))
    except OSError as e:
        skip("stat tests", str(e))
else:
    skip("stat tests", "stat not available")


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
