"""
Simplified pathlib module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_pathlib.py
"""

import sys
import os

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


# Try to import pathlib
try:
    from pathlib import Path, PurePath, PurePosixPath
except ImportError:
    try:
        # For micropython-ucharm, pathlib might only have Path
        from pathlib import Path

        PurePath = Path
        PurePosixPath = Path
    except ImportError:
        print("SKIP: pathlib module not available")
        sys.exit(0)


# ============================================================================
# Path construction
# ============================================================================

print("\n=== Path construction ===")

# Basic construction
p = Path("/usr/bin")
test("Path from string", str(p) == "/usr/bin")

p = Path("foo", "bar", "baz")
test("Path from multiple args", str(p) == "foo/bar/baz")

p = Path("/usr") / "bin" / "python"
test("Path with / operator", str(p) == "/usr/bin/python")

p = Path(".")
test("Path current dir", str(p) == ".")


# ============================================================================
# Path parts
# ============================================================================

print("\n=== Path parts ===")

p = Path("/usr/bin/python3")

# name (basename)
test("Path.name", p.name == "python3")

# parent (dirname)
test("Path.parent", str(p.parent) == "/usr/bin")

# suffix (extension)
p = Path("/home/user/file.txt")
test("Path.suffix", p.suffix == ".txt")

p = Path("/home/user/file.tar.gz")
test("Path.suffix multi-ext", p.suffix == ".gz")

p = Path("/home/user/file")
test("Path.suffix none", p.suffix == "")

# stem (name without suffix)
p = Path("/home/user/file.txt")
test("Path.stem", p.stem == "file")

p = Path("/home/user/file.tar.gz")
test("Path.stem multi-ext", p.stem == "file.tar")


# ============================================================================
# Path properties
# ============================================================================

print("\n=== Path properties ===")

# is_absolute
test("is_absolute /usr", Path("/usr").is_absolute())
test("is_absolute relative", not Path("foo/bar").is_absolute())
test("is_absolute dot", not Path(".").is_absolute())


# ============================================================================
# Path operations
# ============================================================================

print("\n=== Path operations ===")

# joinpath
p = Path("/usr")
test("joinpath", str(p.joinpath("bin", "python")) == "/usr/bin/python")

# with_name
p = Path("/usr/bin/python")
try:
    test("with_name", str(p.with_name("python3")) == "/usr/bin/python3")
except (AttributeError, NotImplementedError):
    skip("with_name", "not implemented")

# with_suffix
p = Path("/home/user/file.txt")
try:
    test("with_suffix", str(p.with_suffix(".md")) == "/home/user/file.md")
    test(
        "with_suffix add",
        str(Path("/home/user/file").with_suffix(".txt")) == "/home/user/file.txt",
    )
except (AttributeError, NotImplementedError):
    skip("with_suffix", "not implemented")


# ============================================================================
# Filesystem operations
# ============================================================================

print("\n=== Filesystem operations ===")

# exists
test("exists cwd", Path(".").exists())
test("exists nonexistent", not Path("/nonexistent/path/foo").exists())

# is_file
test("is_file on file", Path(__file__).is_file())
test("is_file on dir", not Path(".").is_file())

# is_dir
test("is_dir on dir", Path(".").is_dir())
test("is_dir on file", not Path(__file__).is_dir())

# cwd
try:
    cwd = Path.cwd()
    test("cwd is Path", isinstance(cwd, Path))
    test("cwd exists", cwd.exists())
    test("cwd is_dir", cwd.is_dir())
except (AttributeError, NotImplementedError):
    skip("cwd", "not implemented")


# ============================================================================
# Comparison and hashing
# ============================================================================

print("\n=== Comparison and hashing ===")

# Equality
test("equality same", Path("/usr/bin") == Path("/usr/bin"))
test("equality different", not (Path("/usr/bin") == Path("/usr/local")))

# String representation
p = Path("/usr/bin")
test("str()", str(p) == "/usr/bin")
test("repr contains path", "/usr/bin" in repr(p))


# ============================================================================
# Edge cases
# ============================================================================

print("\n=== Edge cases ===")

# Empty path
p = Path("")
test("empty path str", str(p) == ".")

# Root path
p = Path("/")
test("root str", str(p) == "/")
test("root name", p.name == "")
test("root is_absolute", p.is_absolute())

# Trailing slash handling
p = Path("/usr/bin/")
test("trailing slash name", p.name == "bin")

# Dot paths
p = Path("./foo/./bar")
test("dot paths", str(p) == "./foo/./bar" or str(p) == "foo/bar")

# Double dot paths
p = Path("/usr/bin/../lib")
# Note: Path doesn't resolve .. by default
test("double dot preserved", ".." in str(p))


# ============================================================================
# resolve()
# ============================================================================

print("\n=== resolve ===")

try:
    p = Path(".")
    resolved = p.resolve()
    test("resolve returns Path", isinstance(resolved, Path))
    test("resolve is absolute", resolved.is_absolute())
except (AttributeError, NotImplementedError):
    skip("resolve", "not implemented")


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
