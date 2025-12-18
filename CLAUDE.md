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
│   24 modules: term, ansi, charm,    │
│   input, copy, fnmatch, typing, etc.│
├─────────────────────────────────────┤
│        Single Binary                │
│   (universal, no dependencies)      │
└─────────────────────────────────────┘
```

## The ucharm CLI

The `ucharm` CLI is a **fully self-contained binary** (~1.0MB) that embeds:
- **micropython-ucharm**: Custom MicroPython with 24 native Zig modules

This means `ucharm run script.py` works with zero external dependencies. All TUI functionality (boxes, colors, prompts) is provided by native modules.

## Directory Structure

```
ucharm/
├── cli/                      # Zig CLI tool (ucharm)
│   ├── src/
│   │   ├── main.zig          # Entry point, command routing
│   │   ├── build_cmd.zig     # Build command (single/executable/universal)
│   │   ├── init_cmd.zig      # Initialize project (stubs, AI instructions)
│   │   ├── new_cmd.zig       # Project scaffolding
│   │   ├── run_cmd.zig       # Run Python scripts (embeds micropython)
│   │   ├── io.zig            # Shared I/O utilities
│   │   ├── tests.zig         # Unit tests
│   │   ├── stubs/            # Embedded binaries and type stubs
│   │   │   ├── *.pyi         # Python type stubs for native modules
│   │   │   ├── loader-*      # Platform-specific loaders
│   │   │   └── micropython-* # MicroPython binaries
│   │   └── templates/        # AI instruction templates (edit these!)
│   │       ├── AGENTS.md     # Universal (Cursor, Windsurf, Zed)
│   │       ├── CLAUDE.md     # Claude Code instructions
│   │       └── copilot-instructions.md  # GitHub Copilot
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
│   ├── charm/                # TUI components (box, rule, progress, status)
│   ├── copy/                 # copy, deepcopy
│   ├── csv/                  # CSV parsing (RFC 4180)
│   ├── datetime/             # Date/time operations
│   ├── fnmatch/              # Filename pattern matching
│   ├── functools/            # reduce, partial, cmp_to_key
│   ├── glob/                 # File pattern matching
│   ├── input/                # Interactive prompts (select, confirm, prompt)
│   ├── itertools/            # Iterators (count, cycle, chain, etc.)
│   ├── logging/              # Logging framework
│   ├── path/                 # Path manipulation
│   ├── shutil/               # File operations
│   ├── signal/               # Signal handling (6.6x faster)
│   ├── statistics/           # Statistical functions (16x faster)
│   ├── subprocess/           # Process spawning
│   ├── tempfile/             # Temporary files
│   ├── textwrap/             # Text wrapping
│   ├── typing/               # Type hint stubs (no-op)
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
│ 2. Transform imports                 │
│    from ucharm import X              │
│    → from charm/input import X       │
├──────────────────────────────────────┤
│ 3. Execute                           │
│    micropython /tmp/ucharm_run.py    │
└──────────────────────────────────────┘
```

No external dependencies needed - micropython with all native modules is embedded in the CLI binary.

## Build Modes

| Mode | Output | Size | Dependencies |
|------|--------|------|--------------|
| `single` | Transformed .py file | ~2KB | Requires micropython-ucharm |
| `executable` | Bash wrapper + base64 | ~3KB | Requires micropython-ucharm |
| `universal` | Native loader binary | ~899KB | **None** (fully standalone) |

### Universal Binary Format

```
┌────────────────────────────────────────┐
│  Zig Loader Stub (~95KB)               │  ← Native executable
├────────────────────────────────────────┤
│  MicroPython Binary (~804KB)           │  ← Interpreter + 24 native modules
├────────────────────────────────────────┤
│  Python Code (~2KB)                    │  ← User app (transformed)
├────────────────────────────────────────┤
│  Trailer (48 bytes)                    │  ← Offsets and magic
└────────────────────────────────────────┘
```

**Platform-specific execution:**
- **Linux**: Uses `memfd_create` for zero-disk execution (~2ms)
- **macOS**: Extracts to `/tmp/ucharm-{hash}/` with caching (~6ms cached)

## Native Modules (24 total)

### Core Terminal
- `term` - Terminal control (size, raw mode, cursor, keys)
- `ansi` - ANSI colors (fg, bg, rgb, bold, etc.)

### TUI Components
- `charm` - Box, rule, progress bar, status messages (success/error/warning/info), style
- `input` - Interactive prompts: select, multiselect, confirm, prompt, password

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
- `copy` - copy, deepcopy with circular reference support
- `heapq` - Heap queue algorithm
- `operator` - Standard operators as functions
- `random` - Random number generation

### File System
- `shutil` - copy, move, rmtree, exists
- `glob` - File pattern matching
- `fnmatch` - Filename pattern matching (fnmatch, filter, translate)
- `tempfile` - Temporary files and directories

### Utilities
- `textwrap` - wrap, fill, dedent, indent
- `logging` - debug, info, warning, error, Logger class
- `typing` - Type hint stubs (no-op for MicroPython compatibility)

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
| Universal binary (full app) | ~899KB |
| micropython-ucharm binary | ~804KB |
| Loader stub (macos-aarch64) | ~95KB |

## CPython Compatibility

μcharm achieves **88.2% CPython compatibility** across 36 tested standard library modules.

### Modules at 100% Compatibility (28 modules)

argparse, base64, bisect, collections, copy, csv, datetime, errno, fnmatch, functools, glob, heapq, itertools, logging, math, operator, os, pathlib, random, shutil, signal, statistics, subprocess, tempfile, textwrap, time, typing, unittest

### Partial Compatibility

| Module | Compatibility | Notes |
|--------|---------------|-------|
| json | 97.2% | MicroPython allows trailing commas |
| sys | 96.2% | sys.modules behavior differs |
| re | 94.8% | MicroPython regex limitations |
| hashlib | 74.1% | Some algorithms missing |

### Running Compatibility Tests

```bash
python3 tests/compat_runner.py --report  # Full test suite
./native/dist/micropython-ucharm tests/cpython/test_os.py  # Single module
```

### Key Enhancements for Compatibility

The following MicroPython patches enable higher compatibility:

1. **Module delegation chaining** (`py/objmodule.c`): Allows multiple extensions per module
2. **os module extension** (`native/os/modos.c`): Adds environ, os.path, os.name, os.linesep
3. **sys module extension** (`native/sys/modsys.c`): Adds getrecursionlimit, getsizeof, intern, flags
4. **collections enhancements** (`py/objdict.c`, `py/objdeque.c`, `py/objnamedtuple.c`): 
   - OrderedDict.move_to_end()
   - deque.clear(), deque.rotate()
   - namedtuple._replace(), namedtuple._fields
5. **argparse improvements** (micropython-lib): subparsers, mutually_exclusive_group, choices, required

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

1. **Edit Python library**: `ucharm/*.py` (for CPython development)
2. **Edit CLI**: `cli/src/*.zig`
3. **Edit loader**: `loader/src/*.zig`
4. **Edit native modules**: `native/*/` (Zig + C bridge)
5. **Run tests**: `just test`
6. **Rebuild CLI**: `just build`
7. **Rebuild native MicroPython**: `just build-micropython`

## Committing Changes

**IMPORTANT**: Always use the `/commit` slash command before committing changes. This runs through a checklist to ensure:

- All tests pass (e2e and compatibility)
- Type stubs are regenerated and up to date
- AI instruction templates are updated (`cli/src/templates/`)
- Documentation is in sync (CLAUDE.md, README.md)
- CLI templates are updated
- Changes are grouped into logical commits with conventional commit format

Never commit directly without running `/commit` first.

## Adding Native Modules

**IMPORTANT: Zig/C Only Policy**

All native modules MUST be implemented in Zig (with C bridge for MicroPython). **NEVER write Python files for compatibility modules. No exceptions. Do not argue with yourself about this.**

- Primary: Zig implementation + C bridge
- Fallback: Pure C (only when Zig is genuinely not applicable)
- **NEVER: Python** (not for "complex" modules, not for "framework" modules, not for any reason)

This ensures:
- Maximum performance (native code, not interpreted)
- Smallest binary size (no Python bytecode overhead)
- Consistent architecture across all modules

Each native module follows this pattern:

```
native/modulename/
├── modulename.zig      # Core Zig implementation (optional if pure C)
├── modmodulename.c     # MicroPython C API bridge
├── micropython.mk      # MicroPython build integration
├── build.zig           # Zig build for static library (if using Zig)
└── test_modulename.py  # Tests (work on both ucharm and CPython)
```

**Module Types:**

1. **New standalone modules** (e.g., `charm`, `input`): Full Zig implementation + C bridge
2. **Module extensions/delegations** (e.g., `time`, `errno`, `re`): C-only, use `MP_REGISTER_MODULE_DELEGATION()` to add attributes to existing MicroPython modules
3. **Module replacements** (e.g., `heapq`, `random`, `json`): Disable built-in with `-DMICROPY_PY_<MODULE>=0` in build.sh, provide full replacement

Steps:
1. Create module directory with files above
2. Implement Zig logic in `modulename.zig` (or pure C for simple extensions)
3. Create C bridge using `native/bridge/mpy_bridge.h` macros
4. Add to `native/build.sh` USER_C_MODULES path (automatic if micropython.mk exists)
5. Rebuild: `cd native && ./build.sh`
6. Test: `./native/dist/micropython-ucharm native/modulename/test_modulename.py`
7. Update CLI stubs: `cp native/dist/micropython-ucharm cli/src/stubs/micropython-ucharm-macos-aarch64`
8. Rebuild CLI: `cd cli && zig build -Doptimize=ReleaseSmall`

## Keeping Templates and Stubs Up to Date

When adding or modifying native modules, **keep these files in sync**:

### Type Stubs (`stubs/` and `cli/src/stubs/`)

Type stubs provide IDE autocomplete for ucharm users. Update them when:
- Adding new native modules
- Adding/changing functions in existing modules
- Changing function signatures or return types

```bash
# Regenerate stubs from C source
python3 scripts/generate_stubs.py

# Copy to CLI for embedding
cp stubs/*.pyi cli/src/stubs/
```

### AI Instruction Templates (`cli/src/templates/`)

These templates are used by `ucharm init --ai` to help AI coding assistants understand ucharm projects. **Update them when**:
- Adding new native modules (update the module list)
- Adding new TUI functions (update Available Functions)
- Changing import patterns or API conventions

Files to update:
- `cli/src/templates/AGENTS.md` - Universal format (Cursor, Windsurf, Zed)
- `cli/src/templates/CLAUDE.md` - Claude Code specific
- `cli/src/templates/copilot-instructions.md` - GitHub Copilot

These are plain Markdown files that get embedded at compile time, so they're easy to edit and review in PRs.

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
The `ucharm run` command embeds micropython, so this shouldn't happen. If you see this, rebuild the CLI: `cd cli && zig build -Doptimize=ReleaseSmall`

### "Module not found" when using ucharm run
Make sure your imports use `from ucharm import X` syntax. The CLI automatically transforms these to native module imports (`from charm import X` or `from input import X`).

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
- ✅ Phase 7: Native TUI modules (charm, input, copy, fnmatch, typing)
- 🔲 Phase 8: Tree-shaking for smaller binaries
- 🔲 Phase 9: Developer experience (`ucharm check`, `ucharm dev`)
