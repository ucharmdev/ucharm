# ucharm Project

This project uses **ucharm** - a CLI toolkit for building beautiful command-line applications with MicroPython.

## Key Concepts

- **MicroPython, not CPython**: This runs on MicroPython with native Zig modules, not standard Python
- **Native modules**: 24 high-performance modules implemented in Zig (see list below)
- **No pip packages**: You cannot use pip packages that have C extensions
- **Single binary output**: Apps compile to standalone executables (~900KB)

## Available Modules

### TUI Components
- `charm` - Box, rule, progress bar, status messages (success/error/warning/info)
- `input` - Interactive prompts: select, multiselect, confirm, prompt, password
- `term` - Terminal control (size, raw mode, cursor, colors)
- `ansi` - ANSI escape codes for styling

### Standard Library (Native)
- `args` - CLI argument parsing
- `base64`, `copy`, `csv`, `datetime`, `fnmatch`, `functools`, `glob`
- `heapq`, `itertools`, `logging`, `operator`, `random`, `shutil`
- `signal`, `statistics`, `subprocess`, `tempfile`, `textwrap`, `typing`

## Import Pattern

```python
# Use 'from ucharm import' syntax - it gets transformed automatically
from ucharm import box, success, select, confirm

# Or import native modules directly
import charm
import input
```

## Example Usage

```python
from ucharm import box, success, select

box("Welcome!", title="My App", border_color="cyan")
choice = select("Pick one:", ["Option A", "Option B", "Exit"])
success(f"You chose: {choice}")
```

## Running & Building

```bash
# Run script
ucharm run myapp.py

# Build standalone binary
ucharm build myapp.py -o myapp --mode universal
```

## What NOT to Use

- No `requests`, `httpx`, `aiohttp` (use `subprocess` with `curl`)
- No `numpy`, `pandas` (pure Python alternatives only)
- No async/await (MicroPython has limited async support)
- No type annotations at runtime (use for IDE only via stubs)
