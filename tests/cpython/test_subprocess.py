"""
Simplified subprocess module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_subprocess.py
"""

import subprocess
import sys

IS_MICROPYTHON = sys.implementation.name == "micropython"

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


def run_cmd(args, capture=False, shell=False):
    if IS_MICROPYTHON:
        return subprocess.run(args, capture, shell)
    else:
        return subprocess.run(args, capture_output=capture, shell=shell)


def get_returncode(result):
    if isinstance(result, dict):
        return result.get("returncode", result.get("code", 0))
    return result.returncode


def get_stdout(result):
    if isinstance(result, dict):
        stdout = result.get("stdout", b"")
    else:
        stdout = result.stdout or b""
    if isinstance(stdout, bytes):
        return stdout.decode("utf-8").strip()
    return stdout.strip() if stdout else ""


# ============================================================================
# subprocess.run() tests
# ============================================================================

print("\n=== subprocess.run() tests ===")

result = run_cmd(["echo", "hello"], capture=True)
test("run echo hello - returncode", get_returncode(result) == 0)
test("run echo hello - stdout", get_stdout(result) == "hello")

result = run_cmd(["true"], capture=True)
test("run true - zero returncode", get_returncode(result) == 0)

result = run_cmd(["false"], capture=True)
test("run false - non-zero returncode", get_returncode(result) != 0)


# ============================================================================
# subprocess.run() with shell=True tests
# ============================================================================

print("\n=== subprocess.run() with shell=True tests ===")

result = run_cmd("echo hello", capture=True, shell=True)
test("run shell echo - returncode", get_returncode(result) == 0)
test("run shell echo - stdout", get_stdout(result) == "hello")


# ============================================================================
# subprocess.call() tests
# ============================================================================

print("\n=== subprocess.call() tests ===")

if hasattr(subprocess, "call"):
    ret = subprocess.call(["true"])
    test("call true", ret == 0)
    ret = subprocess.call(["false"])
    test("call false", ret != 0)
else:
    skip("call true", "call not implemented")
    skip("call false", "call not implemented")


# ============================================================================
# subprocess.check_output() tests
# ============================================================================

print("\n=== subprocess.check_output() tests ===")

if hasattr(subprocess, "check_output"):
    output = subprocess.check_output(["echo", "hello"])
    if isinstance(output, bytes):
        output = output.decode("utf-8")
    test("check_output echo", output.strip() == "hello")
else:
    skip("check_output echo", "check_output not implemented")


# ============================================================================
# subprocess constants tests
# ============================================================================

print("\n=== subprocess constants tests ===")

test("PIPE constant exists", hasattr(subprocess, "PIPE"))
test("DEVNULL constant exists", hasattr(subprocess, "DEVNULL"))


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
