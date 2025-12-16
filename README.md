# μcharm (microcharm)

Beautiful CLIs with MicroPython. Fast startup, tiny binaries, Python syntax.

```
╭─ μcharm ─────────────────────────╮
│ Write Python                     │
│ Get 6ms startup                  │
│ Ship a 690KB standalone binary   │
│ With beautiful terminal UI       │
╰──────────────────────────────────╯
```

## Why?

| Runtime | Startup | Binary Size | Nice TUI | Easy to Write |
|---------|---------|-------------|----------|---------------|
| Go + Charm | ~2ms | ~10MB | Yes | Medium |
| Rust + Ratatui | ~2ms | ~5MB | Yes | Hard |
| Python + Rich | ~50ms | ~84MB+ | Yes | Yes |
| **MicroPython + μcharm** | **~6ms** | **690KB** | **Yes** | **Yes** |

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

# Add to PATH (optional)
export PATH="$PWD/zig-out/bin:$PATH"
```

### Pre-built Binaries

Coming soon! For now, build from source using Zig.

## Quick Start

```python
#!/usr/bin/env micropython
import sys
sys.path.insert(0, "/path/to/microcharm")

from microcharm import (
    style, box, spinner, progress,
    success, error, warning, info,
    select, confirm, prompt, table
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

# Progress
for i in range(101):
    progress(i, 100, label="Loading")
    time.sleep(0.02)

# Spinner
spinner("Processing...", duration=2)

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
```

## Building Standalone Binaries

μcharm includes the `mcharm` CLI tool to create distributable executables:

```bash
# Single .py file (34KB, needs micropython at runtime)
mcharm build myapp.py -o myapp.py --mode single

# Shell wrapper (46KB, needs micropython at runtime)
mcharm build myapp.py -o myapp --mode executable

# Universal binary (690KB, fully standalone - no dependencies!)
mcharm build myapp.py -o myapp --mode universal
```

### Universal Binary Performance

The universal binary embeds MicroPython and caches extraction for fast subsequent runs:

| Run | Startup Time |
|-----|--------------|
| First run (cold) | ~200ms |
| Subsequent runs (warm) | **~6ms** |

Cache location: `~/.cache/microcharm/`

### How Universal Binary Packaging Works

The universal binary is a self-contained executable that bundles everything needed to run your app:

```
┌─────────────────────────────────────────┐
│ Shell Script Header (4KB)               │  ← Bootstraps extraction & execution
├─────────────────────────────────────────┤
│ MicroPython Binary (~668KB)             │  ← Complete interpreter
├─────────────────────────────────────────┤
│ Bundled Python Code (~35KB)             │  ← Your app + μcharm library
└─────────────────────────────────────────┘
         Total: ~690KB standalone
```

**How it works:**

1. **First run (cold start):**
   - Shell header extracts MicroPython binary using `dd` with 4KB block alignment
   - Extracts bundled Python code using `tail`
   - Caches both to `~/.cache/microcharm/<hash>/`
   - Executes your app with the extracted MicroPython

2. **Subsequent runs (warm start):**
   - Detects cached files exist
   - Directly executes from cache
   - Achieves ~6ms startup (same as native MicroPython)

**The bundled Python code includes:**
- Your application source
- The entire μcharm library (style, components, input, tables)
- All inlined into a single `.py` file with imports resolved

**Cache invalidation:**
- Each build generates a unique hash based on content
- Different versions coexist in separate cache directories
- No conflicts between different apps or versions

## Features

### Styling
- 16 standard colors + bright variants
- True color (24-bit RGB) via hex codes or tuples
- Bold, dim, italic, underline, strikethrough
- Background colors

```python
style("Red text", fg="red")
style("Bold cyan", fg="cyan", bold=True)
style("RGB!", fg="#FF6B6B")
style("Background", bg="blue", fg="white")
```

### Components
- `box()` - Bordered boxes with titles (rounded, square, double, heavy)
- `spinner()` - Animated spinners
- `progress()` - Progress bars
- `rule()` - Horizontal rules
- `success/error/warning/info()` - Status messages

### Input
- `select()` - Arrow-key selection menu (also supports j/k vim keys)
- `multiselect()` - Multi-choice selection
- `confirm()` - Yes/no prompt
- `prompt()` - Text input with validation
- `password()` - Hidden password input

### Tables
- `table()` - Full-featured tables with borders
- `simple_table()` - Borderless tables
- `key_value()` - Key-value pair display

## API Reference

### style(text, **kwargs)
Style text with ANSI codes.

**Arguments:**
- `fg` - Foreground color (name, "#RRGGBB", or (r,g,b) tuple)
- `bg` - Background color
- `bold` - Bold text
- `dim` - Dim/faint text
- `italic` - Italic text
- `underline` - Underlined text
- `strikethrough` - Strikethrough text

### box(content, **kwargs)
Draw a box around content.

**Arguments:**
- `title` - Optional title
- `border` - Border style ("rounded", "square", "double", "heavy")
- `border_color` - Color for the border
- `padding` - Horizontal padding

### select(prompt, options, default=0)
Interactive selection menu. Navigate with arrow keys or j/k.

**Returns:** Selected option string, or None if cancelled (Escape).

### confirm(prompt, default=True)
Yes/no confirmation.

**Returns:** Boolean, or None if cancelled.

### prompt(message, default=None, validator=None)
Text input.

**Arguments:**
- `default` - Default value
- `validator` - Function returning True or error message

### table(data, **kwargs)
Render a table.

**Arguments:**
- `headers` - List of header strings
- `border` - Show borders (default True)
- `header_style` - Dict of style kwargs for headers
- `column_alignments` - List of "left", "right", "center"

## Project Structure

```
microcharm/
├── cli/                  # Zig CLI tool (mcharm)
│   ├── src/
│   │   ├── main.zig      # Entry point, argument parsing
│   │   ├── build_cmd.zig # Build command implementation
│   │   ├── new_cmd.zig   # Project scaffolding
│   │   ├── run_cmd.zig   # Run with micropython
│   │   ├── io.zig        # I/O helpers
│   │   └── tests.zig     # Unit tests
│   ├── build.zig         # Zig build configuration
│   └── test_e2e.sh       # End-to-end tests
├── microcharm/           # Python TUI library
│   ├── __init__.py       # Public API
│   ├── terminal.py       # Terminal utilities
│   ├── style.py          # Text styling (colors, bold, etc.)
│   ├── components.py     # UI components (box, spinner, progress)
│   ├── input.py          # Interactive input (select, confirm, prompt)
│   └── table.py          # Table rendering
└── examples/
    ├── demo.py           # Feature showcase
    └── simple_cli.py     # Example CLI application
```

## Development

### Building the CLI

The `mcharm` CLI is written in Zig for fast startup (~1.7ms) and small binary size (120KB).

```bash
cd cli

# Debug build
zig build

# Release build (smaller, faster)
zig build -Doptimize=ReleaseSmall

# Run directly
zig build run -- --help
```

### Running Tests

```bash
cd cli

# Unit tests
zig build test

# End-to-end tests
./test_e2e.sh
```

### CLI Performance

| Metric | Value |
|--------|-------|
| mcharm binary size | ~120KB |
| mcharm startup | ~1.7ms |
| Built app (warm) | ~6ms |

## Limitations

- **macOS/Linux only** - Uses termios for terminal input (no Windows support yet)
- **Limited stdlib** - MicroPython's stdlib is minimal (no subprocess, etc.)
- **No pip packages** - Everything must be pure Python or frozen in
- **Performance** - Slower than Go/Rust for compute-heavy tasks (it's still interpreted)

## Why "μcharm"?

- **μ (mu)** - The Greek letter for "micro", representing MicroPython
- **charm** - Inspired by the beautiful CLI tools from [Charm](https://charm.sh)
- **CLI command**: `mcharm`

The μ symbol can be used in branding/logos, while "microcharm" is the full searchable name.

## License

MIT

## Contributing

PRs welcome! Areas of interest:
- Windows support
- More components (file picker, autocomplete, markdown rendering)
- Linux `libc.so.6` support for input.py
- Cross-compilation support in the Zig CLI
- Performance optimizations
- Better error messages

## Requirements

- **Runtime:** MicroPython 1.20+
- **Build:** Zig 0.15+ (for building the CLI from source)
- **Platforms:** macOS, Linux (no Windows support yet)
