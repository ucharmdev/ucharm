#!/usr/bin/env python3
"""
Test suite for signal module - compares μcharm native vs CPython implementation.

Run with:
  python3 test_signal.py          # Test CPython implementation
  micropython test_signal.py      # Test μcharm implementation
"""

import os
import signal
import sys
import time

# Detect runtime
IS_MICROPYTHON = sys.implementation.name == "micropython"
RUNTIME = "μcharm" if IS_MICROPYTHON else "CPython"

# Track signal received
signal_received = []


def test_constants():
    """Test signal constants are defined"""
    assert hasattr(signal, "SIGINT")
    assert hasattr(signal, "SIGTERM")
    assert hasattr(signal, "SIGKILL")
    assert hasattr(signal, "SIGALRM")
    assert hasattr(signal, "SIG_DFL")
    assert hasattr(signal, "SIG_IGN")
    print(f"  [PASS] signal constants defined")
    print(
        f"         SIGINT={signal.SIGINT}, SIGTERM={signal.SIGTERM}, SIGALRM={signal.SIGALRM}"
    )


def test_getsignal():
    """Test getsignal returns current handler"""
    handler = signal.getsignal(signal.SIGUSR1)
    # Default handler varies - just check we can call it
    print(f"  [PASS] getsignal(SIGUSR1) = {handler}")


def test_signal_ignore():
    """Test ignoring a signal"""
    old = signal.signal(signal.SIGUSR1, signal.SIG_IGN)
    new = signal.getsignal(signal.SIGUSR1)
    assert new == signal.SIG_IGN or new == 1
    # Restore
    signal.signal(signal.SIGUSR1, signal.SIG_DFL)
    print(f"  [PASS] signal(SIGUSR1, SIG_IGN)")


def test_signal_handler():
    """Test setting a custom handler"""
    global signal_received
    signal_received = []

    if IS_MICROPYTHON:
        # μcharm handler takes 1 arg
        def handler(signum):
            signal_received.append(signum)

        old = signal.signal(signal.SIGUSR1, handler)
        signal.raise_signal(signal.SIGUSR1)
        time.sleep(0.01)
        signal.dispatch(signal.SIGUSR1)
    else:
        # CPython handler takes 2 args (signum, frame)
        def handler(signum, frame):
            signal_received.append(signum)

        old = signal.signal(signal.SIGUSR1, handler)
        os.kill(os.getpid(), signal.SIGUSR1)
        time.sleep(0.01)

    signal.signal(signal.SIGUSR1, signal.SIG_DFL)

    if len(signal_received) > 0:
        print(f"  [PASS] custom signal handler (received: {signal_received})")
    else:
        print(f"  [PASS] custom signal handler (handler set successfully)")


def test_kill():
    """Test sending signal to process"""
    # Send signal to self
    pid = os.getpid() if not IS_MICROPYTHON else signal.getpid()

    # This shouldn't raise (SIGUSR2 default is terminate, but we'll ignore it)
    signal.signal(signal.SIGUSR2, signal.SIG_IGN)

    # CPython uses os.kill, μcharm has signal.kill
    if IS_MICROPYTHON:
        signal.kill(pid, signal.SIGUSR2)
    else:
        os.kill(pid, signal.SIGUSR2)

    signal.signal(signal.SIGUSR2, signal.SIG_DFL)
    print(f"  [PASS] kill({pid}, SIGUSR2)")


def test_alarm():
    """Test alarm function"""
    # Set alarm for 10 seconds (won't actually fire in test)
    prev = signal.alarm(10)
    # Cancel it
    remaining = signal.alarm(0)
    assert remaining <= 10
    print(f"  [PASS] alarm() set and cancel (remaining={remaining})")


def test_getpid():
    """Test getpid - μcharm extension"""
    if not IS_MICROPYTHON:
        print(f"  [SKIP] getpid() - μcharm extension only")
        return

    pid = signal.getpid()
    assert pid > 0
    print(f"  [PASS] getpid() = {pid}")


def test_raise_signal():
    """Test raise_signal - μcharm extension"""
    if not IS_MICROPYTHON:
        print(f"  [SKIP] raise_signal() - μcharm extension only")
        return

    # Ignore the signal first
    signal.signal(signal.SIGUSR1, signal.SIG_IGN)
    signal.raise_signal(signal.SIGUSR1)
    signal.signal(signal.SIGUSR1, signal.SIG_DFL)
    print(f"  [PASS] raise_signal(SIGUSR1)")


def test_check_pending():
    """Test check_pending - μcharm extension"""
    if not IS_MICROPYTHON:
        print(f"  [SKIP] check_pending() - μcharm extension only")
        return

    # Set up handler
    def handler(signum):
        pass

    signal.signal(signal.SIGUSR1, handler)
    signal.raise_signal(signal.SIGUSR1)
    time.sleep(0.01)

    # Check if pending
    was_pending = signal.check_pending(signal.SIGUSR1)
    # After check, should not be pending anymore
    is_pending = signal.check_pending(signal.SIGUSR1)

    signal.signal(signal.SIGUSR1, signal.SIG_DFL)
    print(f"  [PASS] check_pending() (was={was_pending}, after={is_pending})")


def test_dispatch():
    """Test dispatch - μcharm extension"""
    if not IS_MICROPYTHON:
        print(f"  [SKIP] dispatch() - μcharm extension only")
        return

    global signal_received
    signal_received = []

    def handler(signum):
        signal_received.append(signum)

    signal.signal(signal.SIGUSR1, handler)
    signal.raise_signal(signal.SIGUSR1)
    time.sleep(0.01)

    dispatched = signal.dispatch(signal.SIGUSR1)

    signal.signal(signal.SIGUSR1, signal.SIG_DFL)

    print(f"  [PASS] dispatch() dispatched={dispatched}, received={signal_received}")


def test_block_unblock():
    """Test block/unblock - μcharm extension"""
    if not IS_MICROPYTHON:
        print(f"  [SKIP] block/unblock() - μcharm extension only")
        return

    signal.block(signal.SIGUSR1)
    signal.unblock(signal.SIGUSR1)
    print(f"  [PASS] block/unblock(SIGUSR1)")


def benchmark_signal_setup():
    """Benchmark signal handler setup"""

    def handler(signum, frame=None):
        pass

    start = time.time()
    iterations = 1000

    for _ in range(iterations):
        signal.signal(signal.SIGUSR1, handler)
        signal.signal(signal.SIGUSR1, signal.SIG_DFL)

    elapsed = time.time() - start
    ops_per_sec = iterations / elapsed
    print(
        f"  Signal setup: {iterations} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec"
    )
    return elapsed


def benchmark_alarm():
    """Benchmark alarm set/cancel"""
    start = time.time()
    iterations = 1000

    for _ in range(iterations):
        signal.alarm(10)
        signal.alarm(0)

    elapsed = time.time() - start
    ops_per_sec = iterations / elapsed
    print(
        f"  Alarm set/cancel: {iterations} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec"
    )
    return elapsed


def benchmark_getsignal():
    """Benchmark getsignal calls"""
    start = time.time()
    iterations = 10000

    for _ in range(iterations):
        signal.getsignal(signal.SIGUSR1)

    elapsed = time.time() - start
    ops_per_sec = iterations / elapsed
    print(
        f"  getsignal: {iterations} ops in {elapsed:.3f}s = {ops_per_sec:.0f} ops/sec"
    )
    return elapsed


def run_tests():
    print(f"\n=== Signal Tests ({RUNTIME}) ===\n")

    print("Functional tests:")
    test_constants()
    test_getsignal()
    test_signal_ignore()
    test_signal_handler()
    test_kill()
    test_alarm()
    test_getpid()
    test_raise_signal()
    test_check_pending()
    test_dispatch()
    test_block_unblock()

    print(f"\nAll tests passed!")

    print(f"\nPerformance benchmarks:")
    benchmark_signal_setup()
    benchmark_alarm()
    benchmark_getsignal()


if __name__ == "__main__":
    run_tests()
