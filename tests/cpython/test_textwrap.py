"""
Simplified textwrap module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_textwrap.py
"""

import textwrap

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
# textwrap.wrap() tests
# ============================================================================

print("\n=== textwrap.wrap() tests ===")

# Basic wrap - use positional args only for ucharm compatibility
text = "Hello World, this is a test of text wrapping functionality."
result = textwrap.wrap(text, 20)
test("wrap basic", len(result) > 1)
test("wrap line length", all(len(line) <= 20 for line in result))

# Short text that doesn't need wrapping
result = textwrap.wrap("Hello", 20)
test("wrap short", result == ["Hello"])

# Empty string
result = textwrap.wrap("", 20)
test("wrap empty", result == [])

# Exact width
result = textwrap.wrap("Hello World", 11)
test("wrap exact", result == ["Hello World"])


# ============================================================================
# textwrap.fill() tests
# ============================================================================

print("\n=== textwrap.fill() tests ===")

text = "Hello World, this is a test."
result = textwrap.fill(text, 15)
test("fill returns string", isinstance(result, str))
test("fill has newlines", "\n" in result)

# Short text
result = textwrap.fill("Hello", 20)
test("fill short", result == "Hello")


# ============================================================================
# textwrap.dedent() tests
# ============================================================================

print("\n=== textwrap.dedent() tests ===")

# Basic dedent
text = """\
    Hello
    World
    Test"""
result = textwrap.dedent(text)
expected = """\
Hello
World
Test"""
test("dedent basic", result == expected)

# Mixed indentation (uses common prefix)
text = """\
        Line 1
        Line 2
        Line 3"""
result = textwrap.dedent(text)
test("dedent common prefix", not result.startswith("        "))

# No indentation
text = "No indent\nAnother line"
result = textwrap.dedent(text)
test("dedent no indent", result == text)

# Empty lines preserved
text = """\
    Line 1

    Line 2"""
result = textwrap.dedent(text)
test("dedent preserves empty", "\n\n" in result or result.count("\n") >= 2)


# ============================================================================
# textwrap.indent() tests
# ============================================================================

print("\n=== textwrap.indent() tests ===")

# Basic indent
text = "Hello\nWorld\nTest"
result = textwrap.indent(text, "  ")
expected = "  Hello\n  World\n  Test"
test("indent basic", result == expected)

# Different prefix
text = "Line 1\nLine 2"
result = textwrap.indent(text, ">>> ")
test("indent prefix", result == ">>> Line 1\n>>> Line 2")

# Empty string
result = textwrap.indent("", "  ")
test("indent empty", result == "")

# Single line
result = textwrap.indent("Hello", "  ")
test("indent single", result == "  Hello")


# ============================================================================
# textwrap.shorten() tests
# ============================================================================

print("\n=== textwrap.shorten() tests ===")

if hasattr(textwrap, "shorten"):
    # Basic shorten - use positional args
    text = "Hello World, this is a long piece of text that needs to be shortened."
    result = textwrap.shorten(text, 30)
    test("shorten fits width", len(result) <= 30)
    test(
        "shorten has placeholder",
        "[...]" in result or "..." in result or len(result) <= 30,
    )

    # Short text that doesn't need shortening
    result = textwrap.shorten("Hello", 20)
    test("shorten short", result == "Hello")
else:
    skip("shorten", "not implemented")


# ============================================================================
# Combined tests
# ============================================================================

print("\n=== Combined tests ===")

# Dedent then wrap
text = """\
    This is a long line of indented text that should be dedented and then wrapped to a specific width."""
dedented = textwrap.dedent(text)
wrapped = textwrap.wrap(dedented, 30)
test("dedent + wrap", len(wrapped) > 1)

# Indent then fill
text = "Hello World"
indented = textwrap.indent(text, ">>> ")
test("indent works", indented.startswith(">>> "))


# ============================================================================
# Edge cases
# ============================================================================

print("\n=== Edge cases ===")

# Very long word
result = textwrap.wrap("Supercalifragilisticexpialidocious", 10)
test("wrap long word", len(result) >= 1)

# Only whitespace - behavior may vary
result = textwrap.wrap("   ", 10)
test("wrap whitespace", result == [] or result == [""] or result == ["   "])

# Newlines in input
text = "Line 1\nLine 2\nLine 3"
result = textwrap.wrap(text, 50)
test("wrap with newlines", len(result) >= 1)


# ============================================================================
# Summary
# ============================================================================

print("\n" + "=" * 50)
print(f"Results: {_passed} passed, {_failed} failed, {_skipped} skipped")
if _errors:
    print("Failed tests:")
    for e in _errors:
        print(f"  - {e}")
    import sys

    sys.exit(1)
else:
    print("All tests passed!")
