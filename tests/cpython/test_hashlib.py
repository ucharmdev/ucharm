"""
Simplified hashlib module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_hashlib.py
"""

import hashlib
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


def has_algorithm(name):
    """Check if a hash algorithm is available."""
    try:
        hashlib.new(name)
        return True
    except (ValueError, AttributeError):
        pass
    return hasattr(hashlib, name)


def bytes_to_hex(b):
    """Convert bytes to hex string."""
    return "".join("{:02x}".format(x) for x in b)


class HashWrapper:
    """Wrapper that adds hexdigest() to MicroPython hashes."""

    def __init__(self, h):
        self._h = h

    def update(self, data):
        self._h.update(data)
        return self

    def digest(self):
        return self._h.digest()

    def hexdigest(self):
        if hasattr(self._h, "hexdigest"):
            return self._h.hexdigest()
        return bytes_to_hex(self._h.digest())


def get_hash(name, data=b""):
    """Get a hash object, trying multiple methods."""
    if hasattr(hashlib, name):
        h = getattr(hashlib, name)()
        if data:
            h.update(data)
        return HashWrapper(h)
    h = hashlib.new(name, data)
    return HashWrapper(h)


# ============================================================================
# MD5 tests
# ============================================================================

print("\n=== hashlib.md5() tests ===")

if has_algorithm("md5"):
    h = get_hash("md5")
    test("md5 empty hexdigest", h.hexdigest() == "d41d8cd98f00b204e9800998ecf8427e")

    h = get_hash("md5", b"hello")
    test("md5 'hello' hexdigest", h.hexdigest() == "5d41402abc4b2a76b9719d911017c592")

    h = get_hash("md5")
    h.update(b"hello")
    test("md5 update hexdigest", h.hexdigest() == "5d41402abc4b2a76b9719d911017c592")

    h = get_hash("md5")
    h.update(b"hel")
    h.update(b"lo")
    test("md5 multiple updates", h.hexdigest() == "5d41402abc4b2a76b9719d911017c592")

    h = get_hash("md5", b"hello")
    digest = h.digest()
    test("md5 digest is bytes", isinstance(digest, bytes))
    test("md5 digest length", len(digest) == 16)
else:
    skip("md5 tests", "md5 not available")


# ============================================================================
# SHA1 tests
# ============================================================================

print("\n=== hashlib.sha1() tests ===")

if has_algorithm("sha1"):
    h = get_hash("sha1")
    test(
        "sha1 empty hexdigest",
        h.hexdigest() == "da39a3ee5e6b4b0d3255bfef95601890afd80709",
    )

    h = get_hash("sha1", b"hello")
    test(
        "sha1 'hello' hexdigest",
        h.hexdigest() == "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d",
    )

    h = get_hash("sha1")
    h.update(b"hello")
    test(
        "sha1 update hexdigest",
        h.hexdigest() == "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d",
    )

    h = get_hash("sha1", b"hello")
    digest = h.digest()
    test("sha1 digest is bytes", isinstance(digest, bytes))
    test("sha1 digest length", len(digest) == 20)
else:
    skip("sha1 tests", "sha1 not available")


# ============================================================================
# SHA256 tests
# ============================================================================

print("\n=== hashlib.sha256() tests ===")

if has_algorithm("sha256"):
    h = get_hash("sha256")
    test(
        "sha256 empty hexdigest",
        h.hexdigest()
        == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    )

    h = get_hash("sha256", b"hello")
    test(
        "sha256 'hello' hexdigest",
        h.hexdigest()
        == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
    )

    h = get_hash("sha256")
    h.update(b"hello")
    test(
        "sha256 update hexdigest",
        h.hexdigest()
        == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
    )

    h = get_hash("sha256")
    h.update(b"hel")
    h.update(b"lo")
    test(
        "sha256 multiple updates",
        h.hexdigest()
        == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
    )

    h = get_hash("sha256", b"hello")
    digest = h.digest()
    test("sha256 digest is bytes", isinstance(digest, bytes))
    test("sha256 digest length", len(digest) == 32)

    # Known test vector
    h = get_hash("sha256", b"The quick brown fox jumps over the lazy dog")
    test(
        "sha256 fox hexdigest",
        h.hexdigest()
        == "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592",
    )
else:
    skip("sha256 tests", "sha256 not available")


# ============================================================================
# SHA512 tests
# ============================================================================

print("\n=== hashlib.sha512() tests ===")

if has_algorithm("sha512"):
    h = get_hash("sha512")
    expected_empty = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
    test("sha512 empty hexdigest", h.hexdigest() == expected_empty)

    h = get_hash("sha512", b"hello")
    expected_hello = "9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043"
    test("sha512 'hello' hexdigest", h.hexdigest() == expected_hello)

    h = get_hash("sha512", b"hello")
    digest = h.digest()
    test("sha512 digest is bytes", isinstance(digest, bytes))
    test("sha512 digest length", len(digest) == 64)
else:
    skip("sha512 tests", "sha512 not available")


# ============================================================================
# hashlib.new() tests
# ============================================================================

print("\n=== hashlib.new() tests ===")

if hasattr(hashlib, "new"):
    try:
        h = hashlib.new("sha256", b"test")
        test(
            "new sha256",
            h.hexdigest()
            == "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
        )
    except (ValueError, TypeError):
        skip("new sha256", "hashlib.new() not fully supported")

    try:
        h = hashlib.new("md5", b"test")
        test("new md5 lowercase", h.hexdigest() == "098f6bcd4621d373cade4e832627b4f6")
    except (ValueError, TypeError):
        skip("new md5 lowercase", "hashlib.new() not fully supported")
else:
    skip("hashlib.new() tests", "hashlib.new() not available")


# ============================================================================
# Edge cases
# ============================================================================

print("\n=== Edge cases ===")

if has_algorithm("sha256"):
    # Binary data with null bytes
    h = get_hash("sha256", b"\x00\x01\x02\x03")
    test("sha256 binary with nulls", len(h.hexdigest()) == 64)

    # Large data
    large_data = b"x" * 10000
    h = get_hash("sha256", large_data)
    test("sha256 large data", len(h.hexdigest()) == 64)

    # Repeated hexdigest calls - MicroPython hashes can only be finalized once
    h = get_hash("sha256", b"test")
    hex1 = h.hexdigest()
    try:
        hex2 = h.hexdigest()
        test("sha256 repeated hexdigest", hex1 == hex2)
    except ValueError:
        skip("sha256 repeated hexdigest", "hash can only be finalized once")


# ============================================================================
# Algorithm attributes (if available)
# ============================================================================

print("\n=== Algorithm attributes ===")

if has_algorithm("sha256"):
    h = get_hash("sha256")

    if hasattr(h, "digest_size"):
        test("sha256 digest_size", h.digest_size == 32)
    else:
        skip("sha256 digest_size", "digest_size attribute not available")

    if hasattr(h, "block_size"):
        test("sha256 block_size", h.block_size == 64)
    else:
        skip("sha256 block_size", "block_size attribute not available")


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
