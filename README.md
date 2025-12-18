# μcharm

**Build beautiful command-line apps in Python. Ship them as tiny, fast binaries.**

[![CI](https://github.com/ucharmdev/ucharm/actions/workflows/ci.yml/badge.svg)](https://github.com/ucharmdev/ucharm/actions/workflows/ci.yml)
[![Release](https://github.com/ucharmdev/ucharm/actions/workflows/release.yml/badge.svg)](https://github.com/ucharmdev/ucharm/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

```
╭─────────────────────────────────────────────────╮
│                                                 │
│   Write Python. Ship a 900KB binary.            │
│   6ms startup. No dependencies.                 │
│                                                 │
╰─────────────────────────────────────────────────╯
```

μcharm combines Python's ease of use with the performance of native code. Write your CLI in familiar Python syntax, then compile it to a single standalone binary that starts instantly and runs anywhere.

---

## Quick Demo

```python
from ucharm import box, select, confirm, success, style

# Beautiful boxes
box("Welcome to μcharm!", title="Hello", border_color="cyan")

# Interactive prompts
choice = select("What would you like to do?", [
    "Create a new project",
    "Run tests", 
    "Deploy to production"
])

# Confirmations
if confirm("Are you sure?"):
    success(f"You selected: {style(choice, bold=True)}")
```

<img src="https://github.com/user-attachments/assets/placeholder-demo.gif" alt="μcharm demo" width="600">

---

## Why μcharm?

| | Python + Rich | Go + Charm | Rust + Ratatui | **μcharm** |
|---|:---:|:---:|:---:|:---:|
| **Startup time** | 166ms | 18ms | 2ms | **6ms** |
| **Binary size** | 84MB+ | 2.3MB | 2-5MB | **900KB** |
| **Memory usage** | 15MB | 3.7MB | 2MB | **1.7MB** |
| **Easy to write** | Yes | Medium | Hard | **Yes** |
| **Beautiful TUI** | Yes | Yes | Yes | **Yes** |

**μcharm gives you Python's simplicity with native performance.**

- **Tiny binaries** — 900KB standalone executables, 2.4x smaller than Go
- **Instant startup** — 6ms cold start, 27x faster than Python
- **Zero dependencies** — Single binary, runs anywhere
- **Familiar syntax** — It's just Python
- **88% CPython compatible** — 28 stdlib modules work out of the box

---

## Installation

### Homebrew (macOS/Linux)

```bash
brew install ucharmdev/tap/ucharm
```

### Direct Download

```bash
# macOS (Apple Silicon)
curl -L https://github.com/ucharmdev/ucharm/releases/latest/download/ucharm-macos-aarch64 -o ucharm
chmod +x ucharm

# macOS (Intel)
curl -L https://github.com/ucharmdev/ucharm/releases/latest/download/ucharm-macos-x86_64 -o ucharm
chmod +x ucharm

# Linux
curl -L https://github.com/ucharmdev/ucharm/releases/latest/download/ucharm-linux-x86_64 -o ucharm
chmod +x ucharm
```

---

## Getting Started

### 1. Write your app

```python
# hello.py
from ucharm import box, style, success

name = "World"
box(
    f"Hello, {style(name, fg='cyan', bold=True)}!",
    title="Greeting",
    border_color="green"
)
success("μcharm is working!")
```

### 2. Run it

```bash
ucharm run hello.py
```

### 3. Build a standalone binary

```bash
ucharm build hello.py -o hello

# That's it! Ship it anywhere
./hello  # 900KB, starts in 6ms, no dependencies
```

---

## Features

### Beautiful Output

```python
from ucharm import style, box, rule, success, error, warning, info

# Styled text
print(style("Bold cyan text", fg="cyan", bold=True))
print(style("Custom RGB", fg="#FF6B6B"))

# Status messages
success("Operation completed")
error("Something went wrong")  
warning("Check your config")
info("Server running on port 3000")

# Boxes with titles
box("Important announcement here", title="Notice", border_color="yellow")

# Horizontal rules
rule("Section Divider")
```

### Interactive Prompts

```python
from ucharm import select, multiselect, confirm, prompt, password

# Single selection (arrow keys to navigate)
choice = select("Pick a framework:", ["React", "Vue", "Svelte"])

# Multiple selection (space to toggle)
features = multiselect("Select features:", [
    "TypeScript",
    "ESLint", 
    "Prettier",
    "Testing"
])

# Yes/No confirmation
if confirm("Deploy to production?", default=False):
    print("Deploying...")

# Text input
name = prompt("Project name:", default="my-app")

# Password input (hidden)
token = password("API token:")
```

### Tables

```python
from ucharm import table

data = [
    ["Alice", "Engineer", "San Francisco"],
    ["Bob", "Designer", "New York"],
    ["Carol", "Manager", "Seattle"],
]

table(data, headers=["Name", "Role", "Location"])
```

### Progress & Spinners

```python
from ucharm import progress, spinner
import time

# Progress bar
for i in range(100):
    progress(i + 1, 100, label="Downloading")
    time.sleep(0.02)

# Spinner (context manager)
with spinner("Installing dependencies..."):
    time.sleep(2)
```

---

## Native Performance

μcharm includes 23 native Zig modules that outperform CPython:

| Module | Speedup | What it does |
|--------|---------|--------------|
| `statistics` | **16x faster** | mean, median, stdev, variance |
| `signal` | **6.6x faster** | Signal handling, process control |
| `base64` | **4x faster** | Encode/decode base64 |
| `subprocess` | **1.5x faster** | Run shell commands |

```python
import statistics
import base64
import subprocess

# All these are native Zig implementations
data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
print(statistics.mean(data))      # 5.5
print(statistics.stdev(data))     # 3.03

encoded = base64.b64encode(b"Hello μcharm!")
result = subprocess.run(["echo", "Fast!"], capture_output=True)
```

### Full Module List

<details>
<summary><strong>23 Native Zig Modules</strong></summary>

| Module | Functions | Description |
|--------|-----------|-------------|
| `term` | 14 | Terminal size, raw mode, cursor control |
| `ansi` | 13 | ANSI colors and formatting |
| `args` | 14 | CLI argument parsing |
| `base64` | 6 | Base64 encoding/decoding |
| `copy` | 2 | Deep/shallow copy |
| `csv` | 6 | RFC 4180 CSV parsing |
| `datetime` | 15 | Date and time operations |
| `fnmatch` | 3 | Filename pattern matching |
| `functools` | 3 | reduce, partial, cmp_to_key |
| `glob` | 3 | File pattern matching |
| `itertools` | 10 | Iterators: chain, cycle, islice... |
| `logging` | 10 | Logging framework |
| `path` | 12 | Path manipulation |
| `pathlib` | 8 | Object-oriented paths |
| `shutil` | 11 | File operations |
| `signal` | 12 | Signal handling |
| `statistics` | 11 | Statistical functions |
| `subprocess` | 8 | Process spawning |
| `tempfile` | 7 | Temporary files |
| `textwrap` | 5 | Text wrapping |
| `typing` | - | Type hint stubs |
| `charm` | 10 | TUI components |
| `input` | 5 | Interactive prompts |

</details>

<details>
<summary><strong>MicroPython Built-in Modules</strong></summary>

| Module | Description |
|--------|-------------|
| `os` | File system operations |
| `sys` | System parameters |
| `json` | JSON encoding/decoding |
| `re` | Regular expressions |
| `time` | Time functions |
| `math` | Mathematical functions |
| `random` | Random numbers |
| `collections` | Container datatypes |
| `hashlib` | Secure hashes |
| `struct` | Binary data packing |
| `asyncio` | Async/await support |
| `argparse` | Argument parsing |
| `socket` | Network sockets |
| `ssl` | TLS/SSL support |
| ... and more |

</details>

---

## CPython Compatibility

μcharm achieves **88.2% compatibility** with Python's standard library.

**28 modules at 100% compatibility:**
argparse, base64, bisect, collections, copy, csv, datetime, errno, fnmatch, functools, glob, heapq, itertools, logging, math, operator, os, pathlib, random, shutil, signal, statistics, subprocess, tempfile, textwrap, time, typing, unittest

Run the compatibility tests yourself:

```bash
python3 tests/compat_runner.py --report
```

---

## Build Modes

| Mode | Size | Dependencies | Use case |
|------|------|--------------|----------|
| `universal` | ~900KB | None | Production deployment |
| `executable` | ~3KB | micropython-ucharm | Dev machines with runtime |
| `single` | ~2KB | micropython-ucharm | Scripting |

```bash
# Fully standalone binary (recommended)
ucharm build app.py -o app --mode universal

# Shell wrapper (needs micropython-ucharm installed)
ucharm build app.py -o app --mode executable

# Just transform the Python file  
ucharm build app.py -o app.py --mode single
```

### Universal Binary Format

```
┌─────────────────────────────────────────┐
│ Native Loader (~95KB)                   │ ← Zig executable  
├─────────────────────────────────────────┤
│ MicroPython + Native Modules (~804KB)   │ ← Interpreter
├─────────────────────────────────────────┤
│ Your Python Code                        │ ← Your app
├─────────────────────────────────────────┤
│ Trailer (48 bytes)                      │ ← Metadata
└─────────────────────────────────────────┘
```

---

## Development

### Prerequisites

- [Zig](https://ziglang.org/) 0.15+
- [just](https://github.com/casey/just) (optional, but recommended)

### Quick Start

```bash
git clone https://github.com/ucharmdev/ucharm
cd ucharm

# Build everything
just setup

# Run the demo
just demo

# Run tests
just test
```

### Project Structure

```
ucharm/
├── cli/           # Zig CLI tool
├── loader/        # Universal binary loader  
├── native/        # Native Zig modules (23 modules)
├── ucharm/        # Python library
├── tests/         # Test suite
└── examples/      # Example apps
```

### Building from Source

```bash
# Build CLI
cd cli && zig build -Doptimize=ReleaseSmall

# Build MicroPython with native modules
cd native && ./build.sh

# Run
./cli/zig-out/bin/ucharm run examples/demo.py
```

---

## FAQ

<details>
<summary><strong>How does μcharm achieve such small binaries?</strong></summary>

μcharm uses MicroPython instead of CPython. MicroPython is a lean implementation of Python designed for microcontrollers. Combined with Zig's excellent cross-compilation and dead code elimination, we get tiny binaries without sacrificing functionality.

</details>

<details>
<summary><strong>Is it really Python?</strong></summary>

Yes! μcharm uses MicroPython, which implements Python 3.4+ syntax. Most Python code works unchanged. The main differences are:
- Some stdlib modules are missing or simplified
- No C extensions (but our Zig modules are faster anyway)
- Slightly different edge-case behaviors

</details>

<details>
<summary><strong>What platforms are supported?</strong></summary>

- macOS (Apple Silicon & Intel)
- Linux (x86_64)
- Windows support is planned

</details>

<details>
<summary><strong>Can I use pip packages?</strong></summary>

Pure Python packages work if they're compatible with MicroPython. Packages with C extensions won't work, but μcharm's native modules cover most common use cases (HTTP, JSON, subprocess, etc.).

</details>

---

## Contributing

Contributions are welcome! Here are some areas we'd love help with:

- **Windows support**
- **More TUI components** (trees, tabs, charts)
- **Additional stdlib modules**
- **Documentation and examples**

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>μcharm</strong> — Python CLIs, native speed
</p>
