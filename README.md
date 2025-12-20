<p align="center">
  <img src="assets/logo.png" alt="μcharm logo" width="200">
</p>

<h1 align="center">μcharm</h1>

<p align="center">
  <strong>Python CLIs. Tiny binaries. Instant startup.</strong>
</p>

<p align="center">
  <a href="https://github.com/ucharmdev/ucharm/actions/workflows/ci.yml"><img src="https://github.com/ucharmdev/ucharm/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/ucharmdev/ucharm/releases"><img src="https://github.com/ucharmdev/ucharm/actions/workflows/release.yml/badge.svg" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
</p>

```
╭─────────────────────────────────────────────────╮
│                                                 │
│   Write Python. Ship a tiny binary.             │
│   <= 10ms startup. No runtime deps.             │
│                                                 │
╰─────────────────────────────────────────────────╯
```

μcharm is a focused runtime for beautiful, fast CLI apps. You write Python-style
scripts, and μcharm ships them as single-file binaries that start instantly.

- Tiny, portable binaries (target < 2MB for typical CLIs)
- Beautiful TUI output (boxes, tables, prompts, progress)
- Fast startup (<= 10ms on macOS/Linux)
- Curated stdlib compatibility for CLI use cases

---

## Quickstart

```bash
# Run a script
ucharm run app.py

# Build a standalone binary
ucharm build app.py -o app
./app
```

---

## Example: Nice CLI

**app.py**
```python
import charm
import input
import subprocess

charm.box("Deploying build...", title="Release", border="rounded")
result = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True)
commit = result["stdout"].decode().strip()
charm.success(f"Built commit {commit}")

features = input.multiselect("Select features:", ["Logging", "HTTP", "Config"])
if input.confirm("Deploy now?", default=True):
    charm.progress(68, 100, label="Uploading")
    charm.success(f"Deployed with {len(features)} features")
else:
    charm.warning("Canceled")
```

**Output**
```
╭─ Release ─────────────────────────────╮
│ Deploying build...                    │
╰───────────────────────────────────────╯
✓ Built commit a1b2c3d

? Select features:  ◉ Logging  ◉ HTTP  ○ Config
? Deploy now? (Y/n) y
Uploading  [███████████░░░░░░] 68%  3.2s
✓ Deployed with 2 features
```

---

## Why μcharm

- Python ergonomics with Go-style shipping
- Tiny binaries, instant startup
- Rich TUI components out of the box
- No runtime dependency chain
- Honest, curated stdlib compatibility

## Comparison

| | Python + Rich | Go + Charm | Rust + Ratatui | **μcharm** |
|---|:---:|:---:|:---:|:---:|
| **Startup time** | 100ms+ | ~10-20ms | ~2-10ms | **<= 10ms** |
| **Binary size** | 80MB+ | 2-3MB | 2-5MB | **< 2MB** |
| **Easy to write** | Yes | Medium | Hard | **Yes** |
| **Beautiful TUI** | Yes | Yes | Yes | **Yes** |

---

## Features

### TUI Components

```python
import charm

print(charm.style("Bold cyan", fg="cyan", bold=True))
charm.box("Important notice", title="Notice")
charm.table([
    ["Name", "Role"],
    ["Alice", "Engineer"],
    ["Bob", "Designer"],
], headers=True)
charm.progress(50, 100, label="Downloading")
```

### Prompts

```python
import input

choice = input.select("Pick one:", ["Build", "Test", "Deploy"])
name = input.prompt("Project name:", default="my-app")
if input.confirm("Continue?", default=True):
    print("Running...")
```

### System Integration

```python
import subprocess

result = subprocess.run(["echo", "Fast!"], capture_output=True)
print(result["stdout"].decode().strip())
```

---

## Standard Library Support

μcharm targets a CLI-focused subset of CPython. See `compat_report.md` for
current compatibility and gaps.

**Essential for CLI apps:**
argparse, os, sys, time, pathlib, glob, fnmatch, subprocess, signal, json, csv,
logging, datetime, textwrap, tempfile, shutil, re, hashlib.

**Good to have:**
configparser, enum, uuid, urllib.parse, contextlib, typing, statistics,
functools, itertools, heapq.

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

## Build Modes

| Mode | Size | Dependencies | Use case |
|------|------|--------------|----------|
| `universal` | ~0.9-2.0MB | None | Production deployment |
| `executable` | ~3KB | pocketpy-ucharm | Dev machines with runtime |
| `single` | ~2KB | pocketpy-ucharm | Scripting |

```bash
# Fully standalone binary (recommended)
ucharm build app.py -o app --mode universal

# Shell wrapper (needs pocketpy-ucharm installed)
ucharm build app.py -o app --mode executable

# Just transform the Python file
ucharm build app.py -o app.py --mode single
```

---

## Development

### Prerequisites

- [Zig](https://ziglang.org/) 0.15+
- [just](https://github.com/casey/just) (optional, recommended)

### Quick Start

```bash
git clone https://github.com/ucharmdev/ucharm
cd ucharm

just setup
just demo
just test
```

### Project Structure

```
ucharm/
├── cli/           # Zig CLI tool
├── loader/        # Universal binary loader
├── runtime/       # Runtime Zig modules
├── tests/         # Test suite
├── examples/      # Example apps
└── assets/        # Branding
```

---

## Compatibility and Limitations

- μcharm is not a drop-in replacement for CPython.
- No pip or C-extension support.
- Pure-Python packages may work if compatible with PocketPy.
- See `tests/compat_report_pocketpy.md` for current parity.

## Status

Current compatibility summary (from `tests/compat_report_pocketpy.md`):

- 1,288/1,445 tests passing (89.1%)
- 28/36 targeted modules at 100% parity

## Showcase

Built something with μcharm? Open a PR to add it here.

- (your app)

---

## Docs

- `vision.md` for product direction
- `PLAN.md` for implementation priorities
- `LAUNCH.md` for go-to-market

---

## Contributing

Contributions are welcome. Areas that help the most:

- CLI ergonomics (subcommands, completions)
- Config and HTTP modules
- Unicode width correctness
- Docs and examples

---

## License

MIT License. See `LICENSE` for details.

<p align="center">
  <strong>μcharm</strong> — Python CLIs, native speed
</p>
