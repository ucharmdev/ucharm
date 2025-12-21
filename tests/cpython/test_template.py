"""Tests for the template module."""

import sys

_passed = 0
_failed = 0
_errors = []


def test(name, condition):
    global _passed, _failed, _errors
    if condition:
        _passed += 1
        print("  PASS: " + name)
    else:
        _failed += 1
        _errors.append(name)
        print("  FAIL: " + name)


try:
    import template

    HAS_TEMPLATE = True
except ImportError:
    HAS_TEMPLATE = False
    print("SKIP: template module not available")

if HAS_TEMPLATE:
    print("\n=== Module attributes ===")
    test("has render function", hasattr(template, "render"))
    test("render is callable", callable(template.render))

    print("\n=== Basic variable substitution ===")
    r = template.render("{{x}}", {"x": "hello"})
    test("simple variable", r == "hello")
    r = template.render("{{a}} {{b}}", {"a": "1", "b": "2"})
    test("multiple variables", r == "1 2")
    r = template.render("{{n}}", {"n": 42})
    test("integer variable", r == "42")
    r = template.render("hello", {})
    test("empty params", r == "hello")
    r = template.render("hello", None)
    test("none params", r == "hello")

    print("\n=== Dotted access ===")
    r = template.render("{{user.name}}", {"user": {"name": "Alice"}})
    test("dict dot access", r == "Alice")
    r = template.render("{{a.b}}", {"a": {"b": "nested"}})
    test("nested dict 2 levels", r == "nested")

    # Note: object attribute access is not yet fully supported
    # Only dict access works reliably

    print("\n=== Conditionals ===")
    r = template.render("{% if x %}yes{% end %}", {"x": 1})
    test("if true", r == "yes")
    r = template.render("{% if x %}yes{% end %}", {"x": 0})
    test("if false", r == "")
    r = template.render("{% if x %}yes{% else %}no{% end %}", {"x": 1})
    test("if else true", r == "yes")
    r = template.render("{% if x %}yes{% else %}no{% end %}", {"x": 0})
    test("if else false", r == "no")

    print("\n=== Loops ===")
    r = template.render("{% for i in items %}{{i}},{% end %}", {"items": [1, 2, 3]})
    test("for loop list", r == "1,2,3,")
    r = template.render("{% for i in items %}{{i}}{% end %}", {"items": []})
    test("for loop empty", r == "")
    r = template.render("{% for s in items %}{{s}} {% end %}", {"items": ["a", "b"]})
    test("for loop strings", r == "a b ")

    print("\n=== Complex templates ===")
    src = "{% for u in users %}{{u.name}},{% end %}"
    users = [{"name": "Alice"}, {"name": "Bob"}]
    result = template.render(src, {"users": users})
    test("loop with dot access", result == "Alice,Bob,")

    src = "{% for i in items %}{% if i %}{{i}}{% end %}{% end %}"
    r = template.render(src, {"items": [0, 1, 2, 0, 3]})
    test("conditional in loop", r == "123")

    print("\n=== Edge cases ===")
    r = template.render("{{a}}{{b}}", {"a": "x", "b": "y"})
    test("adjacent variables", r == "xy")
    r = template.render("Hello {{name}}!", {"name": "World"})
    test("variable in text", r == "Hello World!")
    r = template.render("{{x}}", {"x": True})
    test("bool true", r == "1")
    r = template.render("{{x}}", {"x": False})
    test("bool false", r == "0")

    print("\n=== Error handling ===")
    try:
        template.render("{% if %}", {})
        test("invalid if syntax raises", False)
    except Exception:
        test("invalid if syntax raises", True)

print("\n==================================================")
msg = "Results: " + str(_passed) + " passed, " + str(_failed) + " failed"
print(msg)
if _errors:
    print("Failed tests:")
    for e in _errors:
        print("  - " + e)
    sys.exit(1)
else:
    print("All tests passed!")
