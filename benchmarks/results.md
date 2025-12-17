# Benchmark Results: CPython vs MicroPython (Pure Python Compat)

## Test Environment
- **CPython**: 3.14.1
- **MicroPython**: 3.4.0
- **Iterations**: 10,000 (1,000 for slow operations)

## Results Summary

### Base64 Encoding/Decoding

| Operation | CPython | MicroPython | Slowdown |
|-----------|---------|-------------|----------|
| encode 13 bytes | 0.0001 ms | 0.0002 ms | 2x |
| encode 1KB | 0.0011 ms | 0.0057 ms | 5.2x |
| encode 10KB | 0.0099 ms | 0.0504 ms | 5.1x |
| decode 20 bytes | 0.0001 ms | 0.0003 ms | 3x |
| decode 1.3KB | 0.0015 ms | 0.0036 ms | 2.4x |
| urlsafe encode 1KB | 0.0013 ms | 0.0112 ms | 8.6x |

**Notes**: MicroPython's base64 uses `binascii` which is a native C module, so it's reasonably fast. The urlsafe variant has extra Python overhead for character replacement.

### Datetime Operations

| Operation | CPython | MicroPython | Slowdown |
|-----------|---------|-------------|----------|
| create datetime | 0.0003 ms | 0.0022 ms | 7.3x |
| fromtimestamp | 0.0007 ms | 0.0026 ms | 3.7x |
| isoformat | 0.0007 ms | 0.0103 ms | 14.7x |
| weekday | 0.0003 ms | 0.0004 ms | 1.3x |
| create timedelta | 0.0003 ms | 0.0014 ms | 4.7x |
| timedelta add | 0.0004 ms | 0.0016 ms | 4x |
| datetime + timedelta | 0.0015 ms | 0.0091 ms | 6.1x |

**Notes**: Pure Python datetime is 4-15x slower than CPython's C implementation. The `isoformat()` method is particularly slow due to string formatting.

### Fnmatch Pattern Matching

| Operation | CPython | MicroPython | Slowdown |
|-----------|---------|-------------|----------|
| simple *.py | 0.0007 ms | 0.0038 ms | 5.4x |
| pattern ????.py | 0.0005 ms | 0.0025 ms | 5x |
| pattern [a-z]*.py | 0.0009 ms | 0.0046 ms | 5.1x |
| complex pattern | 0.0017 ms | 0.0119 ms | 7x |
| no match | 0.0008 ms | 0.0058 ms | 7.3x |
| filter 100 items | 0.0755 ms | 0.4932 ms | 6.5x |

**Notes**: Our pure Python fnmatch implementation is 5-7x slower than CPython's. This is expected since it's interpreted Python vs compiled C.

## Memory Usage

| Runtime | Memory |
|---------|--------|
| CPython | ~19 MB RSS |
| MicroPython | 58 KB allocated, 2 MB free |

## Expected Native Zig Performance

When MicroPython is built with our native Zig modules, we expect:

| Module | Expected Improvement |
|--------|---------------------|
| **base64** | 2-5x faster (Zig SIMD base64) |
| **datetime** | 5-15x faster (native time operations) |
| **fnmatch** | 5-10x faster (compiled pattern matching) |
| **glob** | 10-20x faster (native filesystem iteration) |
| **tempfile** | 10-50x faster (direct syscalls) |
| **shutil** | 10-50x faster (native file operations) |

The native modules should bring MicroPython performance close to or exceeding CPython for these operations, while maintaining the tiny memory footprint.

## Conclusion

Our pure Python compat layer is functional and provides a 5-10x slowdown compared to CPython's native C implementations. This is acceptable for many CLI applications.

With native Zig modules compiled into MicroPython, we expect to match or exceed CPython performance while keeping:
- **Binary size**: ~700KB (vs 77MB Python installation)
- **Memory usage**: ~2MB (vs 20MB+ for CPython)
- **Startup time**: ~6ms (vs 30ms+ for Python)
