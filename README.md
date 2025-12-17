# μcharm (microcharm)

Beautiful CLIs with MicroPython. Fast startup, tiny binaries, Python syntax.

```
╭─ μcharm ─────────────────────────╮
│ Write Python                     │
│ Get 6ms startup                  │
│ Ship a 945KB standalone binary   │
│ With beautiful terminal UI       │
╰──────────────────────────────────╯
```

## Why?

| Runtime | Startup | Binary Size | Memory | Nice TUI | Easy to Write |
|---------|---------|-------------|--------|----------|---------------|
| Rust + Ratatui | ~2ms | ~2-5MB | ~2MB | Yes | Hard |
| Go + Charm | ~18ms | ~2.3MB | 3.7MB | Yes | Medium |
| Python + Rich | ~33ms | 84MB+ | 14.6MB | Yes | Yes |
| **μcharm** | **~6ms** | **945KB** | **1.8MB** | **Yes** | **Yes** |

**μcharm gives you the smallest binaries, lowest memory usage, fastest startup, and Python's ease of use.**

## Performance

### Startup Time (10 iterations)
| Runtime | Time | vs μcharm |
|---------|------|-----------|
| **μcharm** | **19ms** | 1.0x |
| Python 3 | 166ms | 8.7x slower |

### Compute Performance (Fibonacci 30)
| Runtime | Time | Notes |
|---------|------|-------|
| Python 3 | 76ms | CPython optimized |
| **μcharm** | **116ms** | 1.5x slower |

### Loop Performance (1M iterations)
| Runtime | Time | vs Python |
|---------|------|-----------|
| **μcharm** | **32ms** | **1.9x faster** |
| Python 3 | 61ms | 1.0x |

### Native Module Performance
| Operation | μcharm | CPython | Speedup |
|-----------|--------|---------|---------|
| base64 (10K ops) | 5ms | 20ms | **4x faster** |
| statistics (1K ops) | 3ms | 50ms | **16.7x faster** |
| signal getsignal | 31.6M ops/s | 4.8M ops/s | **6.6x faster** |
| signal setup | 3.1M ops/s | 953K ops/s | **3.2x faster** |
| functools partial | 16.3M ops/s | 18.5M ops/s | 0.9x (comparable) |
| functools reduce | 32K ops/s | 37K ops/s | 0.9x (comparable) |
| csv parse | 578K ops/s | 1.8M ops/s | 0.3x (CPython C impl) |
| csv format | 1.2M ops/s | 747K ops/s | **1.6x faster** |
| itertools chain | 50K ops/s | 146K ops/s | 0.3x (CPython C impl) |
| subprocess spawn | 2.04ms | 1.96ms | 1.0x (comparable) |
| subprocess capture | 1.54ms | 1.99ms | **1.3x faster** |
| subprocess shell | 2.74ms | 4.24ms | **1.5x faster** |

### Memory Usage
| Runtime | Peak RSS |
|---------|----------|
| **μcharm** | **1.7 MB** |
| Python 3 | 15 MB |

μcharm uses **8.8x less memory** than Python 3.

### Binary Size
| Binary | Size |
|--------|------|
| **μcharm app** | **945 KB** |
| Go app | 2.3 MB |

μcharm binaries are **2.4x smaller** than Go.

## Standard Library Comparison

μcharm includes MicroPython's stdlib plus 18 native Zig modules for enhanced performance.

### Available Modules

#### Core (MicroPython Built-in)
| Module | Status | Notes |
|--------|--------|-------|
| `os` | ✅ | listdir, getcwd, mkdir, remove, rename, stat |
| `sys` | ✅ | argv, path, exit, stdin, stdout, stderr |
| `json` | ✅ | loads, dumps (+ native Zig version) |
| `re` | ✅ | match, search, findall, sub |
| `time` | ✅ | time, sleep, localtime, gmtime |
| `math` | ✅ | Full math functions |
| `random` | ✅ | random, randint, choice, shuffle |
| `struct` | ✅ | pack, unpack |
| `hashlib` | ✅ | sha256, sha1, md5 |
| `collections` | ✅ | OrderedDict, deque, namedtuple |
| `io` | ✅ | StringIO, BytesIO |
| `errno` | ✅ | Error constants |
| `binascii` | ✅ | hexlify, unhexlify, crc32 |
| `socket` | ✅ | TCP/UDP sockets |
| `select` | ✅ | I/O multiplexing |
| `ssl` | ✅ | TLS support |
| `asyncio` | ✅ | Async/await, tasks, events |
| `argparse` | ✅ | ArgumentParser |
| `heapq` | ✅ | Heap queue |
| `array` | ✅ | Typed arrays |
| `gc` | ✅ | Garbage collection |
| `platform` | ✅ | Basic platform info |
| `deflate` | ✅ | Compression/decompression |
| `cryptolib` | ✅ | AES encryption |

#### μcharm Native Modules (Zig-powered)
| Module | Functions | Notes |
|--------|-----------|-------|
| `term` | 14 | Terminal size, raw mode, cursor, colors |
| `ansi` | 13 | ANSI colors (fg, bg, rgb, bold, etc.) |
| `args` | 14 | CLI parsing, validation, flags |
| `base64` | 6 | Fast base64 encode/decode (4x faster) |
| `csv` | 6 | RFC 4180 parser: reader, writer, parse, format |
| `datetime` | 15 | now, utcnow, timestamp, isoformat |
| `functools` | 3 | reduce, partial, cmp_to_key |
| `glob` | 3 | glob, rglob patterns |
| `fnmatch` | 2 | fnmatch, filter |
| `itertools` | 10 | count, cycle, repeat, chain, islice, etc. |
| `logging` | 10 | debug, info, warning, error, Logger class |
| `path` | 12 | basename, dirname, join, normalize |
| `shutil` | 11 | copy, move, rmtree, exists, isfile |
| `signal` | 12 | signal, alarm, kill, getpid (6.6x faster) |
| `statistics` | 11 | mean, median, stdev (16x faster) |
| `subprocess` | 8 | run, call, check_output, Popen |
| `tempfile` | 7 | gettempdir, mkstemp, mkdtemp |
| `textwrap` | 5 | wrap, fill, dedent, indent |

### Missing from MicroPython

These Python stdlib modules are **not available** in μcharm:

#### Functional Programming
| Module | Alternative |
|--------|-------------|
| `contextlib` | Manual try/finally |
| `copy` | Manual dict/list copying |

#### Type Safety
| Module | Alternative |
|--------|-------------|
| `typing` | Comments or skip types |
| `dataclasses` | Regular classes |
| `enum` | Constants or dicts |

#### Data Formats
| Module | Alternative |
|--------|-------------|
| `toml` | JSON or manual parsing |
| `yaml` | JSON or manual parsing |
| `configparser` | JSON config files |
| `pickle` | JSON serialization |

#### Compression & Archives
| Module | Alternative |
|--------|-------------|
| `gzip` | Use `deflate` module |
| `zipfile` | External tools |
| `tarfile` | External tools |

#### Networking
| Module | Alternative |
|--------|-------------|
| `urllib` | `requests` (bundled) or raw sockets |
| `http.client` | `requests` or raw sockets |

#### Security
| Module | Alternative |
|--------|-------------|
| `uuid` | `random` + formatting |
| `secrets` | `random` (less secure) |
| `getpass` | `term.raw_mode()` + manual input |

#### Database
| Module | Alternative |
|--------|-------------|
| `sqlite3` | JSON files or external DB |

## Installation

```bash
# Install MicroPython
brew install micropython  # macOS
# or: apt install micropython  # Linux

# Clone μcharm
git clone https://github.com/niklas-heer/microcharm
cd microcharm

# Build the CLI (requires Zig 0.15+)
cd cli
zig build -Doptimize=ReleaseSmall

# Build custom MicroPython with native modules
cd native && ./build.sh

# Add to PATH (optional)
export PATH="$PWD/cli/zig-out/bin:$PATH"
```

## Quick Start

```python
#!/usr/bin/env micropython
import sys
sys.path.insert(0, "/path/to/microcharm")

from microcharm import (
    style, box, spinner, progress,
    success, error, warning, info,
    select, confirm, prompt, table,
    args, env, json, path
)

# Styled text
print(style("Hello!", fg="cyan", bold=True))

# Status messages
success("Task completed")
error("Something went wrong")
warning("Check this out")
info("FYI")

# Boxes
box("Content here", title="My Box", border_color="cyan")

# Interactive select (arrow keys + j/k to navigate)
choice = select("Pick one:", ["Option A", "Option B", "Option C"])

# Confirmation
if confirm("Continue?"):
    print("Continuing...")

# Text input
name = prompt("Your name?", default="World")

# Tables
table(
    [["Alice", 25], ["Bob", 30]],
    headers=["Name", "Age"],
    header_style={"bold": True, "fg": "cyan"}
)

# CLI argument parsing
opts = args.parse({
    '--name': str,
    '--count': (int, 1),
    '--verbose': bool,
    '-v': '--verbose',
})
print(f"Hello {opts['name']}!")

# Native modules
import base64
print(base64.b64encode(b"Hello"))  # Fast Zig implementation

import statistics
print(statistics.mean([1, 2, 3, 4, 5]))  # 16x faster than Python

import datetime
now = datetime.now()
print(f"Year: {now['year']}, Month: {now['month']}")
```

## Building Standalone Binaries

```bash
# Universal binary (818KB, fully standalone - no dependencies!)
mcharm build myapp.py -o myapp --mode universal

# Shell wrapper (46KB, needs micropython at runtime)
mcharm build myapp.py -o myapp --mode executable

# Single .py file (34KB, needs micropython at runtime)
mcharm build myapp.py -o myapp.py --mode single
```

### Universal Binary Format

```
┌─────────────────────────────────────────┐
│ Zig Loader Stub (~98KB)                 │  ← Native executable
├─────────────────────────────────────────┤
│ MicroPython Binary (~806KB)             │  ← Interpreter + 18 native modules
├─────────────────────────────────────────┤
│ Bundled Python Code (~41KB)             │  ← Your app + μcharm library
├─────────────────────────────────────────┤
│ Trailer (48 bytes)                      │  ← Offsets and magic
└─────────────────────────────────────────┘
         Total: ~945KB standalone
```

**Platform-specific execution:**
- **Linux:** Uses `memfd_create` for zero-disk execution (~2ms overhead)
- **macOS:** Extracts to `/tmp/mcharm-<hash>/` with content-hash caching (~6ms)

## Features

### Styling
```python
style("Red text", fg="red")
style("Bold cyan", fg="cyan", bold=True)
style("RGB!", fg="#FF6B6B")
style("Background", bg="blue", fg="white")
```

### Components
- `box()` - Bordered boxes with titles
- `spinner()` - Animated spinners
- `progress()` - Progress bars
- `rule()` - Horizontal rules
- `success/error/warning/info()` - Status messages

### Input
- `select()` - Arrow-key selection menu
- `multiselect()` - Multi-choice selection
- `confirm()` - Yes/no prompt
- `prompt()` - Text input with validation
- `password()` - Hidden password input

### Tables
- `table()` - Full-featured tables with borders
- `simple_table()` - Borderless tables
- `key_value()` - Key-value pair display

### Native Modules

#### term - Terminal Control
```python
import term
cols, rows = term.size()
term.raw_mode(True)
key = term.read_key()
term.cursor_pos(10, 5)
term.clear()
```

#### ansi - ANSI Colors
```python
import ansi
print(ansi.fg("cyan") + "Hello" + ansi.reset())
print(ansi.bold() + ansi.fg("#FF5500") + "Orange bold" + ansi.reset())
```

#### base64 - Fast Encoding
```python
import base64
encoded = base64.b64encode(b"Hello World")
decoded = base64.b64decode(encoded)
```

#### statistics - Fast Math
```python
import statistics
data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
print(statistics.mean(data))      # 5.5
print(statistics.median(data))    # 5.5
print(statistics.stdev(data))     # 3.03
print(statistics.variance(data))  # 9.17
```

#### datetime - Date/Time
```python
import datetime
now = datetime.now()
print(f"{now['year']}-{now['month']:02d}-{now['day']:02d}")
ts = datetime.timestamp(2024, 12, 17, 10, 30, 0)
print(datetime.isoformat(2024, 12, 17, 10, 30, 0))
```

#### path - Path Operations
```python
import path
print(path.basename("/foo/bar/test.py"))  # test.py
print(path.dirname("/foo/bar/test.py"))   # /foo/bar
print(path.join("src", "lib", "main.py")) # src/lib/main.py
print(path.normalize("a/../b/./c"))       # b/c
```

#### shutil - File Operations
```python
import shutil
shutil.copy("src.txt", "dst.txt")
shutil.move("old.txt", "new.txt")
shutil.rmtree("mydir")
print(shutil.exists("file.txt"))
print(shutil.isdir("mydir"))
```

#### glob/fnmatch - Pattern Matching
```python
import glob
import fnmatch
files = glob.glob("*.py")
if fnmatch.fnmatch("test.py", "*.py"):
    print("Matches!")
```

#### tempfile - Temporary Files
```python
import tempfile
tmp_dir = tempfile.gettempdir()
tmp_file = tempfile.mkstemp(prefix="my_", suffix=".txt")
tmp_folder = tempfile.mkdtemp(prefix="my_dir_")
```

#### textwrap - Text Wrapping
```python
import textwrap
lines = textwrap.wrap("Long text here...", width=40)
dedented = textwrap.dedent("    indented text")
indented = textwrap.indent("text", ">>> ")
```

## Project Structure

```
microcharm/
├── cli/                  # Zig CLI tool (mcharm)
│   ├── src/
│   │   ├── main.zig      # Entry point
│   │   ├── build_cmd.zig # Build command
│   │   └── stubs/        # Embedded loader binaries
│   └── build.zig
├── loader/               # Universal binary loader (Zig)
│   └── src/
│       ├── main.zig      # Read self, parse trailer, exec
│       ├── trailer.zig   # 48-byte trailer format
│       └── executor.zig  # Platform-specific execution
├── native/               # Native Zig modules
│   ├── term/             # Terminal control
│   ├── ansi/             # ANSI colors
│   ├── args/             # CLI argument parsing
│   ├── base64/           # Fast base64
│   ├── datetime/         # Date/time operations
│   ├── glob/             # File patterns
│   ├── path/             # Path manipulation
│   ├── shutil/           # File operations
│   ├── statistics/       # Statistical functions
│   ├── tempfile/         # Temp files
│   ├── textwrap/         # Text wrapping
│   └── build.sh          # Builds micropython-mcharm
├── microcharm/           # Python library
│   ├── __init__.py       # Public API
│   ├── style.py          # Text styling
│   ├── components.py     # UI components
│   ├── input.py          # Interactive input
│   ├── table.py          # Tables
│   ├── args.py           # Argument parsing
│   ├── env.py            # Environment utilities
│   ├── path.py           # Path utilities
│   └── json.py           # JSON utilities
└── examples/
    ├── demo.py           # Feature showcase
    └── simple_cli.py     # Example CLI
```

## Development

### Building Native Modules

```bash
cd native
./build.sh  # Builds micropython-mcharm with all native modules
```

### Running Tests

```bash
cd cli
zig build test          # Unit tests
./test_e2e.sh           # End-to-end tests
```

### Testing Interactive Components

```bash
# Inject keystrokes for testing
MCHARM_TEST_KEYS="down,down,enter" ./my_app
```

## Limitations

- **macOS/Linux only** - No Windows support yet
- **Minimal stdlib** - Some Python modules unavailable (see Missing section above)

## Requirements

- **Runtime:** MicroPython 1.20+
- **Build:** Zig 0.15+
- **Platforms:** macOS (ARM64, x86_64), Linux (x86_64)

## License

MIT

## Contributing

PRs welcome! Areas of interest:
- Windows support
- More UI components
- Performance optimizations
- Additional stdlib modules (contextlib, copy, typing stubs)
