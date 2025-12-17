# CLAUDE.md - AI Assistant Guide for ucharm

## Project Overview

**ucharm** is a CLI toolkit for building beautiful, fast, tiny command-line applications with MicroPython. The goal is "Bun for MicroPython" - Python syntax with native performance and tiny binaries.

**Repository**: https://github.com/ucharmdev/ucharm

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

## The ucharm CLI

The `ucharm` CLI is a **fully self-contained binary** (~1.0MB) that embeds:
- **micropython-ucharm**: Custom MicroPython with 18 native Zig modules
- **ucharm Python library**: Pure Python TUI components for MicroPython

This means `ucharm run script.py` works with zero external dependencies.

## Directory Structure

```
ucharm/
├── cli/                      # Zig CLI tool (ucharm)
│   ├── src/
│   │   ├── main.zig          # Entry point, command routing
│   │   ├── build_cmd.zig     # Build command (single/executable/universal)
│   │   ├── new_cmd.zig       # Project scaffolding
│   │   ├── run_cmd.zig       # Run Python scripts (embeds micropython)
│   │   ├── io.zig            # Shared I/O utilities
│   │   ├── tests.zig         # Unit tests
│   │   ├── ucharm_bundle.py  # Embedded pure Python ucharm library
│   │   └── stubs/            # Embedded binaries
│   │       ├── loader-macos-aarch64
│   │       ├── loader-macos-x86_64
│   │       ├── loader-linux-x86_64
│   │       └── micropython-ucharm-macos-aarch64
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
│   ├── bridge/               # MicroPython C API bridge
│   ├── build.sh              # Builds micropython-ucharm
│   └── dist/                 # Built micropython-ucharm binary
├── ucharm/                   # Python TUI library (for CPython dev)
│   ├── __init__.py           # Public API
│   ├── _native.py            # Native library bindings (ctypes)
│   ├── terminal.py           # Terminal ops
│   ├── style.py              # Text styling
│   ├── components.py         # UI components (boxes, spinners, progress)
│   ├── input.py              # Interactive input (select, confirm, prompt)
│   └── table.py              # Table rendering
├── scripts/
│   ├── release.py            # Interactive release script (uses ucharm TUI)
│   └── update-homebrew.sh    # Homebrew formula generator
├── .github/
│   ├── workflows/
│   │   ├── ci.yml            # CI: test on push/PR
│   │   └── release.yml       # Release: build binaries, AI release notes
│   └── scripts/
│       └── generate_release_notes.py  # AI-powered release notes
├── examples/
│   ├── simple_cli.py         # Demo of all features
│   └── demo.py               # Quick demo
├── justfile                  # Development commands (just)
├── TODO.md                   # Roadmap
└── README.md
```

## Key Commands

```bash
# Using just (recommended)
just setup        # Check deps and build CLI
just build        # Build CLI in release mode
just test         # Run all tests
just demo         # Run demo
just release      # Interactive release (uses ucharm TUI!)

# Manual commands
cd cli && zig build -Doptimize=ReleaseSmall   # Build CLI
cd cli && zig build test                       # Unit tests
cd cli && ./test_e2e.sh                        # E2E tests
cd native && ./build.sh                        # Build micropython-ucharm

# Running scripts
./cli/zig-out/bin/ucharm run examples/demo.py
./cli/zig-out/bin/ucharm run scripts/release.py

# Building standalone binaries
./cli/zig-out/bin/ucharm build app.py -o app --mode universal
```

## How `ucharm run` Works

The `ucharm run` command is fully self-contained:

```
ucharm run script.py
        │
        ▼
┌──────────────────────────────────────┐
│ 1. Extract embedded micropython      │
│    → /tmp/ucharm-<hash>/micropython  │
│    (cached by content hash)          │
├──────────────────────────────────────┤
│ 2. Bundle script with ucharm lib     │
│    → /tmp/ucharm_run.py              │
│    (ucharm_bundle.py + user script)  │
├──────────────────────────────────────┤
│ 3. Execute                           │
│    micropython /tmp/ucharm_run.py    │
└──────────────────────────────────────┘
```

No external dependencies needed - micropython and the ucharm library are embedded in the CLI binary.

## Build Modes

| Mode | Output | Size | Dependencies |
|------|--------|------|--------------|
| `single` | Bundled .py file | ~41KB | Requires micropython |
| `executable` | Bash wrapper + base64 | ~55KB | Requires micropython |
| `universal` | Native loader binary | ~945KB | **None** (fully standalone) |

### Universal Binary Format

```
┌────────────────────────────────────────┐
│  Zig Loader Stub (~98KB)               │  ← Native executable
├────────────────────────────────────────┤
│  MicroPython Binary (~806KB)           │  ← Interpreter + 18 native modules
├────────────────────────────────────────┤
│  Python Code (~41KB)                   │  ← User app + ucharm library
├────────────────────────────────────────┤
│  Trailer (48 bytes)                    │  ← Offsets and magic
└────────────────────────────────────────┘
```

**Platform-specific execution:**
- **Linux**: Uses `memfd_create` for zero-disk execution (~2ms)
- **macOS**: Extracts to `/tmp/ucharm-{hash}/` with caching (~6ms cached)

## Native Modules (18 total)

### Core Terminal
- `term` - Terminal control (size, raw mode, cursor, keys)
- `ansi` - ANSI colors (fg, bg, rgb, bold, etc.)

### CLI & Parsing
- `args` - CLI argument parsing with validation
- `csv` - RFC 4180 CSV parser

### Process & System
- `subprocess` - Process spawning (1.5x faster shell)
- `signal` - Signal handling (6.6x faster)

### Functional Programming
- `functools` - reduce, partial, cmp_to_key
- `itertools` - count, cycle, chain, islice, takewhile, dropwhile

### Data & Math
- `base64` - Fast encoding (4x faster)
- `statistics` - mean, median, stdev (16x faster)
- `datetime` - now, utcnow, timestamp, isoformat

### File System
- `path` - basename, dirname, join, normalize
- `shutil` - copy, move, rmtree, exists
- `glob` / `fnmatch` - Pattern matching
- `tempfile` - Temporary files and directories

### Utilities
- `textwrap` - wrap, fill, dedent, indent
- `logging` - debug, info, warning, error, Logger class

## Performance Benchmarks

### Native Module Performance vs CPython

| Operation | ucharm | CPython | Speedup |
|-----------|--------|---------|---------|
| signal getsignal | 31.6M ops/s | 4.8M ops/s | **6.6x faster** |
| statistics | 3ms | 50ms | **16.7x faster** |
| base64 (10K ops) | 5ms | 20ms | **4x faster** |
| subprocess shell | 2.74ms | 4.24ms | **1.5x faster** |

### Binary Sizes

| Component | Size |
|-----------|------|
| ucharm CLI (with embedded micropython) | ~1.0MB |
| Universal binary (full app) | ~945KB |
| micropython-ucharm binary | ~806KB |
| Loader stub (macos-aarch64) | ~98KB |

## CI/CD

The project uses GitHub Actions:

### CI Workflow (`ci.yml`)
- Runs on push to main and PRs
- Tests on Ubuntu and macOS
- Zig 0.14.0 with ReleaseSmall

### Release Workflow (`release.yml`)
- Triggered by version tags (`v*`)
- Builds for: macos-aarch64, macos-x86_64, linux-x86_64
- Generates AI-powered release notes (Claude Haiku via OpenRouter)
- Creates GitHub release with binaries
- Updates Homebrew formula

### Creating a Release

```bash
just release  # Interactive release using ucharm TUI!
```

This runs `scripts/release.py` which:
1. Shows current version and recent commits
2. Lets you select version bump (patch/minor/major)
3. Creates and pushes a git tag
4. Triggers the release workflow

## Development Workflow

1. **Edit Python library**: `ucharm/*.py`
2. **Edit CLI**: `cli/src/*.zig`
3. **Edit embedded Python bundle**: `cli/src/ucharm_bundle.py`
4. **Edit loader**: `loader/src/*.zig`
5. **Edit native modules**: `native/*/` (Zig + C bridge)
6. **Run tests**: `just test`
7. **Rebuild CLI**: `just build`
8. **Rebuild native MicroPython**: `just build-micropython`

## Adding Native Modules

Each native module follows this pattern:

```
native/modulename/
├── modulename.zig      # Core Zig implementation
├── modmodulename.c     # MicroPython C API bridge
├── micropython.mk      # MicroPython build integration
├── build.zig           # Zig build for static library
└── test_modulename.py  # Tests (work on both ucharm and CPython)
```

Steps:
1. Create module directory with files above
2. Implement Zig logic in `modulename.zig`
3. Create C bridge using `native/bridge/mpy_bridge.h` macros
4. Add to `native/build.sh` USER_C_MODULES path
5. Rebuild: `cd native && ./build.sh`
6. Test: `./native/dist/micropython-ucharm native/modulename/test_modulename.py`
7. Update `cli/src/ucharm_bundle.py` if needed for bundled usage

## Environment Setup

```bash
# Copy .env.example to .env
cp .env.example .env

# Required for AI release notes
OPENROUTER_API_KEY=your_key

# Optional for Homebrew updates
HOMEBREW_TAP_TOKEN=your_github_pat
```

## Homebrew Installation

```bash
brew tap ucharmdev/tap
brew install ucharm
```

## Common Issues

### "micropython not found"
The `ucharm run` command embeds micropython, so this shouldn't happen. For `ucharm build`, install micropython: `brew install micropython` or build custom: `cd native && ./build.sh`

### "Module not found" when using ucharm run
The bundler strips `from ucharm import ...` statements. Make sure your imports match what's available in `cli/src/ucharm_bundle.py`.

### Build fails on Linux
Native modules use POSIX APIs that work on both macOS and Linux. Run `cd native && ./build.sh` on Linux to build micropython-ucharm.

## Roadmap

See `TODO.md` for full roadmap. Current status:
- ✅ Phase 1: Native modules (term, ansi, base64, statistics, etc.)
- ✅ Phase 2: Python library integration
- ✅ Phase 3: Native Zig loader for universal binaries
- ✅ Phase 4: CLI stdlib modules (subprocess, signal, csv, functools, itertools, logging)
- ✅ Phase 5: Self-contained CLI with embedded micropython
- ✅ Phase 6: CI/CD with AI release notes
- 🔲 Phase 7: Remaining stdlib (contextlib, copy, enum, uuid)
- 🔲 Phase 8: Tree-shaking for smaller binaries
- 🔲 Phase 9: Developer experience (`ucharm check`, `ucharm dev`)
