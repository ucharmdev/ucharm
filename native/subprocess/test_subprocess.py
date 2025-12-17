#!/usr/bin/env python3
"""
Test suite for subprocess module - compares μcharm native vs CPython implementation.

Run with:
  python3 test_subprocess.py          # Test CPython implementation
  micropython test_subprocess.py      # Test μcharm implementation
"""

import os
import subprocess
import sys
import time

# Detect runtime
IS_MICROPYTHON = sys.implementation.name == "micropython"
RUNTIME = "μcharm" if IS_MICROPYTHON else "CPython"


def run_cmd(args, capture=False, shell=False):
    """Wrapper to handle API differences between CPython and μcharm"""
    if IS_MICROPYTHON:
        # μcharm uses positional args: run(args, capture_output, shell)
        return subprocess.run(args, capture, shell)
    else:
        # CPython uses keyword args
        return subprocess.run(args, capture_output=capture, shell=shell)


def get_returncode(result):
    """Get returncode from result (dict in μcharm, object in CPython)"""
    if IS_MICROPYTHON:
        return result["returncode"]
    return result.returncode


def get_stdout(result):
    """Get stdout from result"""
    if IS_MICROPYTHON:
        return result["stdout"]
    return result.stdout


def get_stderr(result):
    """Get stderr from result"""
    if IS_MICROPYTHON:
        return result["stderr"]
    return result.stderr


def test_run_simple():
    """Test basic subprocess.run()"""
    result = run_cmd(["echo", "hello"], capture=True)
    assert get_returncode(result) == 0
    assert b"hello" in get_stdout(result)
    print(f"  [PASS] run(['echo', 'hello'])")


def test_run_with_args():
    """Test subprocess.run() with multiple arguments"""
    result = run_cmd(["echo", "hello", "world"], capture=True)
    assert get_returncode(result) == 0
    assert b"hello world" in get_stdout(result)
    print(f"  [PASS] run(['echo', 'hello', 'world'])")


def test_run_failure():
    """Test subprocess.run() with failing command"""
    result = run_cmd(["false"], capture=True)
    assert get_returncode(result) != 0
    print(f"  [PASS] run(['false']) returns non-zero")


def test_run_shell():
    """Test subprocess.run() with shell=True"""
    result = run_cmd("echo hello | cat", capture=True, shell=True)
    assert get_returncode(result) == 0
    assert b"hello" in get_stdout(result)
    print(f"  [PASS] run('echo hello | cat', shell=True)")


def test_call():
    """Test subprocess.call()"""
    ret = subprocess.call(["true"])
    assert ret == 0
    print(f"  [PASS] call(['true']) == 0")

    ret = subprocess.call(["false"])
    assert ret != 0
    print(f"  [PASS] call(['false']) != 0")


def test_check_call():
    """Test subprocess.check_call()"""
    ret = subprocess.check_call(["true"])
    assert ret == 0
    print(f"  [PASS] check_call(['true'])")

    try:
        subprocess.check_call(["false"])
        assert False, "Should have raised"
    except (
        OSError,
        subprocess.CalledProcessError
        if hasattr(subprocess, "CalledProcessError")
        else OSError,
    ):
        print(f"  [PASS] check_call(['false']) raises exception")


def test_check_output():
    """Test subprocess.check_output()"""
    output = subprocess.check_output(["echo", "hello"])
    assert b"hello" in output
    print(f"  [PASS] check_output(['echo', 'hello'])")


def test_check_output_shell():
    """Test subprocess.check_output() with shell"""
    if IS_MICROPYTHON:
        output = subprocess.check_output("echo hello", True)  # shell=True
    else:
        output = subprocess.check_output("echo hello", shell=True)
    assert b"hello" in output
    print(f"  [PASS] check_output('echo hello', shell=True)")


def test_getoutput():
    """Test subprocess.getoutput()"""
    output = subprocess.getoutput("echo hello")
    assert "hello" in output
    assert not output.endswith("\n")  # Should strip trailing newline
    print(f"  [PASS] getoutput('echo hello')")


def test_getstatusoutput():
    """Test subprocess.getstatusoutput()"""
    status, output = subprocess.getstatusoutput("echo hello")
    assert status == 0
    assert "hello" in output
    print(f"  [PASS] getstatusoutput('echo hello')")

    status, output = subprocess.getstatusoutput("false")
    assert status != 0
    print(f"  [PASS] getstatusoutput('false') returns non-zero status")


def test_getpid():
    """Test subprocess.getpid() - μcharm extension"""
    if not IS_MICROPYTHON:
        print(f"  [SKIP] getpid() - μcharm extension only")
        return
    pid = subprocess.getpid()
    assert pid > 0
    print(f"  [PASS] getpid() == {pid}")


def test_stderr_capture():
    """Test capturing stderr"""
    result = run_cmd("echo error >&2", capture=True, shell=True)
    stderr = get_stderr(result)
    assert b"error" in stderr
    print(f"  [PASS] stderr capture works")


def test_large_output():
    """Test handling large output"""
    # Generate ~14KB of output
    result = run_cmd(
        "dd if=/dev/zero bs=1024 count=10 2>/dev/null | base64",
        capture=True,
        shell=True,
    )
    stdout = get_stdout(result)
    assert len(stdout) > 10000
    print(f"  [PASS] large output ({len(stdout)} bytes)")


def test_environment():
    """Test that environment is inherited"""
    if IS_MICROPYTHON:
        # MicroPython doesn't have os.environ, use os.putenv
        os.putenv("TEST_VAR", "test_value")
    else:
        os.environ["TEST_VAR"] = "test_value"
    output = subprocess.getoutput("echo $TEST_VAR")
    assert "test_value" in output
    print(f"  [PASS] environment inheritance")


def test_working_directory():
    """Test current working directory"""
    output = subprocess.getoutput("pwd")
    assert os.getcwd() in output
    print(f"  [PASS] working directory")


def test_pipe_command():
    """Test piped commands"""
    output = subprocess.getoutput("echo 'hello world' | wc -w")
    assert "2" in output
    print(f"  [PASS] piped commands")


# Performance tests
def bench_spawn_overhead():
    """Benchmark process spawning overhead"""
    iterations = 100
    start = time.time()
    for _ in range(iterations):
        subprocess.call(["true"])
    elapsed = time.time() - start
    per_call = (elapsed / iterations) * 1000
    print(f"  spawn overhead: {per_call:.2f}ms per call ({iterations} iterations)")
    return per_call


def bench_output_capture():
    """Benchmark output capture"""
    iterations = 50
    start = time.time()
    for _ in range(iterations):
        subprocess.check_output(["echo", "hello"])
    elapsed = time.time() - start
    per_call = (elapsed / iterations) * 1000
    print(f"  output capture: {per_call:.2f}ms per call ({iterations} iterations)")
    return per_call


def bench_shell_command():
    """Benchmark shell command execution"""
    iterations = 50
    start = time.time()
    for _ in range(iterations):
        subprocess.getoutput("echo hello")
    elapsed = time.time() - start
    per_call = (elapsed / iterations) * 1000
    print(f"  shell command: {per_call:.2f}ms per call ({iterations} iterations)")
    return per_call


def run_tests():
    print(f"\n=== Subprocess Tests ({RUNTIME}) ===\n")

    print("Functional tests:")
    test_run_simple()
    test_run_with_args()
    test_run_failure()
    test_run_shell()
    test_call()
    test_check_call()
    test_check_output()
    test_check_output_shell()
    test_getoutput()
    test_getstatusoutput()
    test_getpid()
    test_stderr_capture()
    test_large_output()
    test_environment()
    test_working_directory()
    test_pipe_command()

    print(f"\nAll {16} functional tests passed!")

    print(f"\nPerformance benchmarks:")
    spawn_time = bench_spawn_overhead()
    capture_time = bench_output_capture()
    shell_time = bench_shell_command()

    print(f"\n=== Summary ({RUNTIME}) ===")
    print(f"  Spawn: {spawn_time:.2f}ms")
    print(f"  Capture: {capture_time:.2f}ms")
    print(f"  Shell: {shell_time:.2f}ms")


if __name__ == "__main__":
    run_tests()
