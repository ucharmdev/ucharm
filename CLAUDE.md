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
│   Native Modules (C → MicroPython)  │
│   term, ansi (more planned)         │
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
│   │   └── tests.zig         # Unit tests
│   ├── build.zig             # Zig build configuration
│   └── test_e2e.sh           # End-to-end test suite
├── native/                   # Native C modules for MicroPython
│   ├── term/
│   │   ├── modterm.c         # Terminal control (size, raw mode, keys)
│   │   └── micropython.mk
│   ├── ansi/
│   │   ├── modansi.c         # ANSI escape codes (colors, styles)
│   │   └── micropython.mk
│   ├── build.sh              # Builds custom micropython-mcharm
│   └── README.md
├── microcharm/               # Python TUI library
│   ├── __init__.py
│   ├── terminal.py           # Terminal ops (uses native term if available)
│   ├── style.py              # Text styling (uses native ansi if available)
│   ├── components.py         # UI components (boxes, spinners, progress)
│   ├── input.py              # Interactive input (select, confirm, prompt)
│   └── table.py              # Table rendering
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
| `single` | Bundled .py file | ~37KB | Requires micropython |
| `executable` | Bash wrapper + base64 | ~50KB | Requires micropython |
| `universal` | Self-extracting binary | ~690KB | None (fully standalone) |

## Native Modules

The custom `micropython-mcharm` binary includes native C modules:

### term module
```python
import term
cols, rows = term.size()       # Terminal dimensions
term.raw_mode(True)            # Enable raw input
key = term.read_key()          # Read single keypress
term.cursor_pos(x, y)          # Move cursor
term.cursor_up(n), term.cursor_down(n)
term.clear(), term.clear_line()
term.hide_cursor(), term.show_cursor()
term.is_tty()                  # Check if TTY
term.write(text)               # Unbuffered write
```

### ansi module
```python
import ansi
ansi.fg("red")                 # Foreground color (name)
ansi.fg("#ff5500")             # Foreground color (hex)
ansi.fg(196)                   # Foreground color (256-color)
ansi.bg("blue")                # Background color
ansi.rgb(255, 100, 0)          # 24-bit color
ansi.bold(), ansi.dim(), ansi.italic()
ansi.underline(), ansi.strikethrough()
ansi.reset()                   # Reset all styles
```

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
| μcharm universal (cached) | ~0ms | 1.8MB |
| micropython-mcharm | ~0ms | 1.6MB |
| python3 | ~10ms | 15MB |
| uv run python | ~30ms | 26MB |

### Compute (Fibonacci 30)

| Runtime | Time | Notes |
|---------|------|-------|
| python3 | 80ms | CPython, fastest |
| micropython-mcharm | 110ms | With native modules |
| micropython | 140ms | Standard build |

### Loop (1M iterations)

| Runtime | Time |
|---------|------|
| micropython | 30ms |
| micropython-mcharm | 30ms |
| python3 | 60ms |

### Binary Sizes

| Output | Size |
|--------|------|
| Universal binary (simple app) | ~690KB |
| micropython-mcharm binary | 653KB |
| mcharm CLI tool | 1.5MB |
| Go hello world (typical) | 1.2-2MB |
| Python installation | ~77MB |

## Development Workflow

1. **Edit Python library**: `microcharm/*.py`
2. **Edit CLI**: `cli/src/*.zig`
3. **Edit native modules**: `native/*/mod*.c`
4. **Run tests**: `cd cli && zig build test && ./test_e2e.sh`
5. **Rebuild native MicroPython**: `cd native && ./build.sh`

## Adding Native Modules

1. Create `native/modulename/modname.c`
2. Create `native/modulename/micropython.mk`
3. Add to `native/build.sh` USER_C_MODULES path
4. Rebuild: `cd native && ./build.sh`

## Common Issues

### "micropython not found"
Install: `brew install micropython` or build custom: `cd native && ./build.sh`

### "term module not found"
Use standard micropython (falls back to Python) or build `micropython-mcharm`

### Build fails on Linux
The native module build currently targets macOS. Linux support planned.

## Roadmap

See `TODO.md` for full roadmap. Current status:
- ✅ Phase 1: Native term and ansi modules
- ✅ Phase 2: Python library integration
- 🔲 Phase 3: Tree-shaking for smaller binaries
- 🔲 Phase 4: Compatibility checker (`mcharm check`)
- 🔲 Phase 5: Developer experience (`mcharm init`, `mcharm dev`)
