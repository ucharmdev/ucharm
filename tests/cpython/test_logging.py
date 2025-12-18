"""
Simplified logging module tests for ucharm compatibility testing.
Works on both CPython and micropython-ucharm.

Based on CPython's Lib/test/test_logging.py
"""

import logging
import sys

# Detect runtime for handling differences
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


# ============================================================================
# Log level constants tests
# ============================================================================

print("\n=== Log level constants tests ===")

test("DEBUG constant defined", hasattr(logging, "DEBUG"))
test("INFO constant defined", hasattr(logging, "INFO"))
test("WARNING constant defined", hasattr(logging, "WARNING"))
test("ERROR constant defined", hasattr(logging, "ERROR"))
test("CRITICAL constant defined", hasattr(logging, "CRITICAL"))

if hasattr(logging, "DEBUG"):
    test("DEBUG value is 10", logging.DEBUG == 10)
if hasattr(logging, "INFO"):
    test("INFO value is 20", logging.INFO == 20)
if hasattr(logging, "WARNING"):
    test("WARNING value is 30", logging.WARNING == 30)
if hasattr(logging, "ERROR"):
    test("ERROR value is 40", logging.ERROR == 40)
if hasattr(logging, "CRITICAL"):
    test("CRITICAL value is 50", logging.CRITICAL == 50)


# ============================================================================
# getLogger() tests
# ============================================================================

print("\n=== getLogger() tests ===")

if hasattr(logging, "getLogger"):
    test("getLogger callable", callable(logging.getLogger))
    logger = logging.getLogger("test_logger")
    test("getLogger returns object", logger is not None)
else:
    skip("getLogger", "not implemented")


# ============================================================================
# Logger methods tests
# ============================================================================

print("\n=== Logger methods tests ===")

if hasattr(logging, "getLogger"):
    logger = logging.getLogger("methods_test")
    test("logger.debug exists", hasattr(logger, "debug") and callable(logger.debug))
    test("logger.info exists", hasattr(logger, "info") and callable(logger.info))
    test(
        "logger.warning exists", hasattr(logger, "warning") and callable(logger.warning)
    )
    test("logger.error exists", hasattr(logger, "error") and callable(logger.error))
    test(
        "logger.critical exists",
        hasattr(logger, "critical") and callable(logger.critical),
    )


# ============================================================================
# Module-level logging functions tests
# ============================================================================

print("\n=== Module-level logging functions tests ===")

test("logging.debug exists", hasattr(logging, "debug") and callable(logging.debug))
test("logging.info exists", hasattr(logging, "info") and callable(logging.info))
test(
    "logging.warning exists", hasattr(logging, "warning") and callable(logging.warning)
)
test("logging.error exists", hasattr(logging, "error") and callable(logging.error))
test(
    "logging.critical exists",
    hasattr(logging, "critical") and callable(logging.critical),
)


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
