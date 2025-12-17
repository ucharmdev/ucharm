# CLAUDE.md - AI Assistant Guide for μcharm

## Project Overview

**μcharm** (microcharm) is a CLI toolkit for building beautiful, fast, tiny command-line applications with MicroPython. The goal is "Bun for MicroPython" - Python syntax with native performance and tiny binaries.

**Repository**: https://github.com/niklas-heer/microcharm

## Architecture

```
┌─────────────────────────────────────┐
│         Your Python Code            │
│   (standard Python syntax)          │
├─────────────────────────────────────┤
│        MicroPython VM               │
│   (bytecode interpreter)            │
├─────────────────────────────────────┤
│   Native Modules (Zig → C ABI)      │
│   18 modules: term, ansi, subprocess│
│   signal, csv, functools, etc.      │
├─────────────────────────────────────┤
│        Single Binary                │
│   (universal, no dependencies)      │
└─────────────────────────────────────┘
```

## Directory Structure

```
microcharm/
├── cli/                      # Zig CLI tool (mcharm)
│   ├── src/
│   │   ├── main.zig          # Entry point, command routing
│   │   ├── build_cmd.zig     # Build command (single/executable/universal)
│   │   ├── new_cmd.zig       # Project scaffolding
│   │   ├── run_cmd.zig       # Run Python scripts
│   │   ├── io.zig            # Shared I/O utilities
│   │   ├── tests.zig         # Unit tests
│   │   └── stubs/            # Embedded loader binaries for universal mode
│   │       ├── loader-macos-aarch64
│   │       ├── loader-macos-x86_64
│   │       └── loader-linux-x86_64
│   ├── build.zig             # Zig build configuration
│   └── test_e2e.sh           # End-to-end test suite
├── loader/                   # Universal binary loader (Zig)
│   ├── src/
│   │   ├── main.zig          # Entry: read self, parse trailer, exec
│   │   ├── trailer.zig       # Parse 48-byte trailer format
│   │   └── executor.zig      # Platform-specific execution
│   └── build.zig             # Multi-target build (3 platforms)
├── native/                   # Native Zig modules (C ABI for MicroPython)
│   ├── term/                 # Terminal control
│   ├── ansi/                 # ANSI color codes
│   ├── args/                 # CLI argument parsing
│   ├── base64/               # Base64 encoding (4x faster)
│   ├── csv/                  # CSV parsing (RFC 4180)
│   ├── datetime/             # Date/time operations
│   ├── functools/            # reduce, partial, cmp_to_key
│   ├── glob/                 # File pattern matching
│   ├── itertools/            # Iterators (count, cycle, chain, etc.)
│   ├── logging/              # Logging framework
│   ├── path/                 # Path manipulation
│   ├── shutil/               # File operations
│   ├── signal/               # Signal handling (6.6x faster)
│   ├── statistics/           # Statistical functions (16x faster)
│   ├── subprocess/           # Process spawning
│   ├── tempfile/             # Temporary files
│   ├── textwrap/             # Text wrapping
│   ├── build.sh              # Builds micropython-mcharm
│   └── dist/                 # Built micropython-mcharm binary
├── microcharm/               # Python TUI library
│   ├── __init__.py           # Public API
│   ├── terminal.py           # Terminal ops
│   ├── style.py              # Text styling
│   ├── components.py         # UI components (boxes, spinners, progress)
│   ├── input.py              # Interactive input (select, confirm, prompt)
│   ├── table.py              # Table rendering
│   └── ...                   # Other utilities
├── examples/
│   ├── simple_cli.py         # Demo of all features
│   ├── demo.py               # Quick demo
│   └── debug_keys.py         # Key input debugger
├── TODO.md                   # Roadmap
└── README.md
```

## Key Commands

```bash
# Build the Zig CLI
cd cli && zig build -Doptimize=ReleaseSmall

# Run tests
cd cli && zig build test        # Unit tests (11 tests)
cd cli && ./test_e2e.sh         # E2E tests (19 tests)

# Build custom MicroPython with native modules
cd native && ./build.sh

# Build modes
./cli/zig-out/bin/mcharm build app.py -o app --mode single      # Bundled Python
./cli/zig-out/bin/mcharm build app.py -o app --mode executable  # Shell wrapper
./cli/zig-out/bin/mcharm build app.py -o app --mode universal   # Self-contained binary

# Run Python scripts directly
./cli/zig-out/bin/mcharm run examples/simple_cli.py
```

## Build Modes Explained

| Mode | Output | Size | Dependencies |
|------|--------|------|--------------|
| `single` | Bundled .py file | ~41KB | Requires micropython |
| `executable` | Bash wrapper + base64 | ~55KB | Requires micropython |
| `universal` | Native loader binary | ~945KB | None (fully standalone) |

### Universal Binary Format

Universal binaries use a native Zig loader for instant startup:

```
┌────────────────────────────────────────┐
│  Zig Loader Stub (~98KB)               │  ← Native executable
├────────────────────────────────────────┤
│  MicroPython Binary (~806KB)           │  ← Interpreter + 18 native modules
├────────────────────────────────────────┤
│  Python Code (~41KB)                   │  ← User app + microcharm
├────────────────────────────────────────┤
│  Trailer (48 bytes)                    │  ← Offsets and magic
└────────────────────────────────────────┘
```

**Trailer format (48 bytes):**
- 8 bytes: magic `MCHARM01`
- 8 bytes: micropython_offset (u64 LE)
- 8 bytes: micropython_size (u64 LE)  
- 8 bytes: python_offset (u64 LE)
- 8 bytes: python_size (u64 LE)
- 8 bytes: magic `MCHARM01`

**Platform-specific execution:**
- **Linux**: Uses `memfd_create` for zero-disk execution (~2ms)
- **macOS**: Extracts to `/tmp/mcharm-{hash}/` with caching (~6ms cached)

## Native Modules

The custom `micropython-mcharm` binary includes 18 native Zig modules:

### term module - Terminal Control
```python
import term
cols, rows = term.size()       # Terminal dimensions
term.raw_mode(True)            # Enable raw input
key = term.read_key()          # Read single keypress
term.cursor_pos(x, y)          # Move cursor
term.clear(), term.clear_line()
term.hide_cursor(), term.show_cursor()
```

### ansi module - ANSI Colors
```python
import ansi
ansi.fg("red")                 # Foreground color (name)
ansi.fg("#ff5500")             # Foreground color (hex)
ansi.bg("blue")                # Background color
ansi.bold(), ansi.dim(), ansi.italic()
ansi.reset()                   # Reset all styles
```

### subprocess module - Process Spawning (1.5x faster shell)
```python
import subprocess
result = subprocess.run(["ls", "-la"])
output = subprocess.check_output(["echo", "hello"])
status = subprocess.call(["make", "build"])
text = subprocess.getoutput("ls -la | head -5")
```

### signal module - Signal Handling (6.6x faster)
```python
import signal
signal.signal(signal.SIGINT, handler)
signal.alarm(5)                # Set alarm
signal.kill(pid, signal.SIGTERM)
pid = signal.getpid()
```

### csv module - CSV Parsing (RFC 4180)
```python
import csv
row = csv.parse("a,b,c")       # ['a', 'b', 'c']
line = csv.format(["a", "b"])  # 'a,b'
reader = csv.reader(file_obj)
writer = csv.writer(file_obj)
```

### functools module
```python
import functools
functools.reduce(lambda a,b: a+b, [1,2,3])  # 6
add5 = functools.partial(add, 5)
sorted(items, key=functools.cmp_to_key(cmp_func))
```

### itertools module
```python
import itertools
itertools.count(10)            # 10, 11, 12, ...
itertools.cycle([1,2,3])       # 1, 2, 3, 1, 2, 3, ...
itertools.chain([1,2], [3,4])  # 1, 2, 3, 4
itertools.islice(iter, 5)      # First 5 elements
itertools.takewhile(pred, iter)
itertools.dropwhile(pred, iter)
```

### logging module
```python
import logging
logging.basicConfig(level=logging.DEBUG)
logging.debug("Debug message")
logging.info("Info message")
logging.warning("Warning!")
logging.error("Error occurred")
logger = logging.getLogger("myapp")
```

### statistics module (16x faster)
```python
import statistics
statistics.mean([1, 2, 3, 4, 5])      # 3.0
statistics.median([1, 2, 3, 4, 5])    # 3.0
statistics.stdev([1, 2, 3, 4, 5])     # 1.58...
```

### Other Native Modules
- `base64` - Fast base64 encode/decode (4x faster)
- `datetime` - now, utcnow, timestamp, isoformat
- `glob` / `fnmatch` - File pattern matching
- `path` - basename, dirname, join, normalize
- `shutil` - copy, move, rmtree, exists, isfile
- `tempfile` - gettempdir, mkstemp, mkdtemp
- `textwrap` - wrap, fill, dedent, indent

## Python Library

The microcharm Python library auto-detects native modules:

```python
from microcharm.terminal import get_size, clear, hide_cursor
from microcharm.style import style, bold, colors
from microcharm.input import select, confirm, prompt
from microcharm.components import Box, Spinner, ProgressBar
from microcharm.table import Table
```

When running under `micropython-mcharm`, it uses native modules for speed.
Otherwise, it falls back to pure Python implementations.

## Performance Benchmarks

### Startup Time (Hello World)

| Runtime | Time | Memory |
|---------|------|--------|
| μcharm universal (cached) | ~6ms | 1.8MB |
| micropython-mcharm | ~0ms | 1.6MB |
| python3 | ~10ms | 15MB |
| uv run python | ~30ms | 26MB |

### Native Module Performance vs CPython

| Operation | μcharm | CPython | Speedup |
|-----------|--------|---------|---------|
| signal getsignal | 31.6M ops/s | 4.8M ops/s | **6.6x faster** |
| signal setup | 3.1M ops/s | 953K ops/s | **3.2x faster** |
| statistics (16x faster) | 3ms | 50ms | **16.7x faster** |
| base64 (10K ops) | 5ms | 20ms | **4x faster** |
| csv format | 1.2M ops/s | 747K ops/s | **1.6x faster** |
| subprocess shell | 2.74ms | 4.24ms | **1.5x faster** |
| subprocess capture | 1.54ms | 1.99ms | **1.3x faster** |

### Binary Sizes

| Output | Size |
|--------|------|
| Universal binary (full app) | ~945KB |
| micropython-mcharm binary | ~806KB |
| mcharm CLI tool | ~220KB |
| Loader stub (macos-aarch64) | ~98KB |
| Loader stub (linux-x86_64) | ~45KB |
| Go hello world (typical) | 1.2-2MB |
| Python installation | ~77MB |

## Development Workflow

1. **Edit Python library**: `microcharm/*.py`
2. **Edit CLI**: `cli/src/*.zig`
3. **Edit loader**: `loader/src/*.zig`
4. **Edit native modules**: `native/*/` (Zig + C bridge)
5. **Run tests**: `cd cli && zig build test && ./test_e2e.sh`
6. **Test native modules**: `./native/dist/micropython-mcharm native/<module>/test_<module>.py`
7. **Rebuild native MicroPython**: `cd native && ./build.sh`
8. **Rebuild CLI**: `cd cli && zig build -Doptimize=ReleaseSmall`

## Adding Native Modules

Each native module follows this pattern:

```
native/modulename/
├── modulename.zig      # Core Zig implementation
├── modmodulename.c     # MicroPython C API bridge
├── mpy_bridge.h        # Bridge macros (shared)
├── micropython.mk      # MicroPython build integration
├── build.zig           # Zig build for static library
└── test_modulename.py  # Tests (work on both μcharm and CPython)
```

Steps:
1. Create module directory with files above
2. Implement Zig logic in `modulename.zig`
3. Create C bridge using `mpy_bridge.h` macros
4. Add to `native/build.sh` USER_C_MODULES path
5. Rebuild: `cd native && ./build.sh`
6. Test: `./native/dist/micropython-mcharm native/modulename/test_modulename.py`

## Testing Interactive Components

For automated testing of interactive CLI components (select, confirm, prompt, etc.), 
microcharm supports two methods of injecting keystrokes:

### Method 1: Environment Variable (works everywhere)
```bash
# Comma-separated key names
MCHARM_TEST_KEYS="down,down,enter" ./my_app

# Key names: up, down, left, right, enter, space, escape, backspace, tab
# Single characters are sent as-is: MCHARM_TEST_KEYS="y" ./my_app
```

### Method 2: File Descriptor 3 (CPython only)
```bash
# Newline-separated key names via fd 3
echo -e "down\ndown\nenter" | ./my_app 3<&0

# Or from a file
./my_app 3< keystrokes.txt
```

**Note:** File descriptor 3 only works with CPython. MicroPython (universal binaries) 
must use the environment variable method.

### Example Test Script
```bash
#!/bin/bash
# Test select component
if MCHARM_TEST_KEYS="down,enter" ./my_app 2>&1 | grep -q "Option 2"; then
    echo "PASS: Select works"
else
    echo "FAIL: Select broken"
fi
```

## Common Issues

### "micropython not found"
Install: `brew install micropython` or build custom: `cd native && ./build.sh`

### "term module not found"
Use standard micropython (falls back to Python) or build `micropython-mcharm`

### Build on Linux
The native modules use POSIX APIs (termios, ioctl) that work on both macOS and Linux.
Run `cd native && ./build.sh` on Linux to build micropython-mcharm with native modules.
Universal binaries use `memfd_create` on Linux for zero-disk execution.

## Roadmap

See `TODO.md` for full roadmap. Current status:
- ✅ Phase 1: Native modules (term, ansi, base64, statistics, etc.)
- ✅ Phase 2: Python library integration
- ✅ Phase 3: Native Zig loader for universal binaries (instant startup)
- ✅ Phase 4: CLI stdlib modules (subprocess, signal, csv, functools, itertools, logging)
- 🔲 Phase 5: Remaining stdlib (contextlib, copy, enum, uuid)
- 🔲 Phase 6: Tree-shaking for smaller binaries
- 🔲 Phase 7: Developer experience (`mcharm check`, `mcharm dev`)
