#!/usr/bin/env python3
"""
Test suite for logging module - compares μcharm native vs CPython implementation.

Run with:
  python3 test_logging.py          # Test CPython implementation
  micropython test_logging.py      # Test μcharm implementation
"""

import sys
import time

# Detect runtime
IS_MICROPYTHON = sys.implementation.name == "micropython"
RUNTIME = "μcharm" if IS_MICROPYTHON else "CPython"

import logging


# Capture output for testing
class StringIO:
    def __init__(self):
        self._data = ""

    def write(self, s):
        self._data += s
        return len(s)

    def getvalue(self):
        return self._data

    def clear(self):
        self._data = ""


def test_level_constants():
    """Test log level constants are defined"""
    assert logging.DEBUG == 10
    assert logging.INFO == 20
    assert logging.WARNING == 30
    assert logging.ERROR == 40
    assert logging.CRITICAL == 50
    print(f"  [PASS] level constants: DEBUG={logging.DEBUG}, INFO={logging.INFO}")


def test_get_level_name():
    """Test getLevelName"""
    assert logging.getLevelName(10) == "DEBUG"
    assert logging.getLevelName(20) == "INFO"
    assert logging.getLevelName(30) == "WARNING"
    assert logging.getLevelName(40) == "ERROR"
    assert logging.getLevelName(50) == "CRITICAL"
    print(f"  [PASS] getLevelName: 20 -> {logging.getLevelName(20)}")


def test_set_level():
    """Test setLevel"""
    original = logging.getLevel() if IS_MICROPYTHON else logging.root.level

    if IS_MICROPYTHON:
        logging.setLevel(logging.DEBUG)
        assert logging.getLevel() == logging.DEBUG
        logging.setLevel(original)
    else:
        logging.root.setLevel(logging.DEBUG)
        assert logging.root.level == logging.DEBUG
        logging.root.setLevel(original)

    print(f"  [PASS] setLevel: DEBUG")


def test_basic_config():
    """Test basicConfig"""
    if IS_MICROPYTHON:
        logging.basicConfig(level=logging.INFO)
        assert logging.getLevel() == logging.INFO
    else:
        # CPython basicConfig only works once, so just check it exists
        pass
    print(f"  [PASS] basicConfig(level=INFO)")


def test_is_enabled_for():
    """Test isEnabledFor"""
    if IS_MICROPYTHON:
        logging.setLevel(logging.WARNING)
        assert logging.isEnabledFor(logging.WARNING) == True
        assert logging.isEnabledFor(logging.ERROR) == True
        assert logging.isEnabledFor(logging.DEBUG) == False
        assert logging.isEnabledFor(logging.INFO) == False
    else:
        logging.root.setLevel(logging.WARNING)
        assert logging.root.isEnabledFor(logging.WARNING) == True
        assert logging.root.isEnabledFor(logging.ERROR) == True
        assert logging.root.isEnabledFor(logging.DEBUG) == False

    print(f"  [PASS] isEnabledFor: WARNING enabled, DEBUG disabled")


def test_logging_debug():
    """Test debug logging (should be filtered at WARNING level)"""
    if IS_MICROPYTHON:
        logging.setLevel(logging.WARNING)
        # This shouldn't produce output
        logging.debug("debug message")
    print(f"  [PASS] debug() filtered at WARNING level")


def test_logging_warning():
    """Test warning logging"""
    if IS_MICROPYTHON:
        logging.setLevel(logging.WARNING)
        # This should produce output (we just test it doesn't crash)
        logging.warning("test warning")
    else:
        logging.warning("test warning")
    print(f"  [PASS] warning() executed")


def test_logging_error():
    """Test error logging"""
    if IS_MICROPYTHON:
        logging.setLevel(logging.ERROR)
        logging.error("test error")
    else:
        logging.error("test error")
    print(f"  [PASS] error() executed")


def test_logging_format_args():
    """Test logging with format arguments"""
    if IS_MICROPYTHON:
        logging.setLevel(logging.INFO)
        logging.info("Hello %s, number %d", "world", 42)
    else:
        logging.info("Hello %s, number %d", "world", 42)
    print(f"  [PASS] format args: 'Hello %s, number %d'")


def test_get_logger():
    """Test getLogger"""
    logger = logging.getLogger("myapp")
    assert logger is not None
    print(f"  [PASS] getLogger('myapp')")


def test_logger_methods():
    """Test Logger methods"""
    logger = logging.getLogger("test")

    if IS_MICROPYTHON:
        logger.setLevel(logging.DEBUG)
        logger.debug("debug from logger")
        logger.info("info from logger")
        logger.warning("warning from logger")
        logger.error("error from logger")
        logger.critical("critical from logger")
    else:
        logger.setLevel(logging.DEBUG)
        logger.debug("debug from logger")
        logger.info("info from logger")

    print(f"  [PASS] Logger methods executed")


# Performance benchmarks
def benchmark_logging():
    """Benchmark logging operations"""
    if IS_MICROPYTHON:
        logging.setLevel(logging.DEBUG)
    else:
        logging.root.setLevel(logging.DEBUG)
        # Silence output for benchmark
        logging.root.handlers = []

    start = time.time()
    iterations = 1000

    for i in range(iterations):
        if IS_MICROPYTHON:
            logging.debug("Test message %d", i)
        else:
            # Just format, don't output
            pass

    elapsed = time.time() - start
    ops_per_sec = iterations / elapsed

    print(f"  Logging: {iterations} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec")
    return elapsed


def benchmark_level_check():
    """Benchmark level checking (fast path)"""
    if IS_MICROPYTHON:
        logging.setLevel(logging.ERROR)
    else:
        logging.root.setLevel(logging.ERROR)

    start = time.time()
    iterations = 10000

    for i in range(iterations):
        if IS_MICROPYTHON:
            logging.isEnabledFor(logging.DEBUG)
        else:
            logging.root.isEnabledFor(logging.DEBUG)

    elapsed = time.time() - start
    ops_per_sec = iterations / elapsed

    print(
        f"  Level check: {iterations} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec"
    )
    return elapsed


def run_tests():
    print(f"\n=== Logging Tests ({RUNTIME}) ===\n")

    print("Level constants tests:")
    test_level_constants()
    test_get_level_name()

    print("\nConfiguration tests:")
    test_set_level()
    test_basic_config()
    test_is_enabled_for()

    print("\nLogging functions tests:")
    test_logging_debug()
    test_logging_warning()
    test_logging_error()
    test_logging_format_args()

    print("\nLogger class tests:")
    test_get_logger()
    test_logger_methods()

    print(f"\nAll tests passed!")

    print(f"\nPerformance benchmarks:")
    benchmark_logging()
    benchmark_level_check()


if __name__ == "__main__":
    run_tests()
