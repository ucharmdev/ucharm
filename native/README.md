# μcharm Native Modules

Native C modules compiled into a custom MicroPython build for fast terminal operations.

## Modules

### term
Terminal control operations:
- `term.size()` - Get terminal size as (cols, rows)
- `term.raw_mode(enable)` - Enable/disable raw terminal mode
- `term.read_key()` - Read single keypress (returns key name or None)
- `term.cursor_pos(x, y)` - Move cursor to position
- `term.cursor_up/down/left/right(n)` - Move cursor
- `term.clear()` - Clear screen
- `term.clear_line()` - Clear current line
- `term.hide_cursor()` / `term.show_cursor()` - Cursor visibility
- `term.write(text)` - Direct write to stdout (no buffering)
- `term.is_tty()` - Check if stdout is a terminal

### ansi
ANSI escape code generation:
- `ansi.fg(color)` - Foreground color code (name, index 0-255, or #hex)
- `ansi.bg(color)` - Background color code
- `ansi.rgb(r, g, b, bg=False)` - 24-bit true color
- `ansi.bold()`, `ansi.dim()`, `ansi.italic()`, `ansi.underline()` - Style codes
- `ansi.strikethrough()`, `ansi.reverse()`, `ansi.blink()`, `ansi.hidden()`
- `ansi.reset()` - Reset all styles

**Supported color names:** black, red, green, yellow, blue, magenta, cyan, white, gray/grey, and bright_* variants

## Building

### Prerequisites

1. C compiler (gcc or clang)
2. Git (for cloning MicroPython)

### Build Commands

```bash
# Build custom MicroPython with native modules
./build.sh

# Output: dist/micropython-mcharm
```

The build script will:
1. Clone MicroPython repository (if needed)
2. Initialize required submodules
3. Build mpy-cross compiler
4. Build MicroPython Unix port with our native modules

### Output

```
dist/
└── micropython-mcharm   # Custom MicroPython binary (~530KB)
```

## Usage

```python
import term
import ansi

# Get terminal size
cols, rows = term.size()

# Enable raw mode for key reading
term.raw_mode(True)
try:
    key = term.read_key()
    if key == "up":
        print("Up arrow pressed!")
    elif key == "escape":
        print("Escape pressed!")
finally:
    term.raw_mode(False)

# Print colored text
print(ansi.fg("cyan") + "Hello" + ansi.reset())
print(ansi.fg("#FF6B6B") + ansi.bold() + "Bold RGB!" + ansi.reset())
print(ansi.bg("blue") + ansi.fg("white") + " Inverse " + ansi.reset())

# 256-color mode
print(ansi.fg(208) + "Orange (256 color)" + ansi.reset())
```

## Architecture

These are **external C modules** that get compiled directly into MicroPython (not dynamic .mpy files). This approach:
- Gives full access to system APIs (termios, ioctl, etc.)
- Eliminates module loading overhead
- Allows building a single custom binary with all features

## Development

The modules use MicroPython's external C module API.
See [MicroPython cmodules docs](https://docs.micropython.org/en/latest/develop/cmodules.html).

### Adding a new module

1. Create directory: `native/mymod/`
2. Create `modmymod.c` with module implementation
3. Create `micropython.mk` with: `SRC_USERMOD_C += $(USERMOD_DIR)/modmymod.c`
4. Rebuild with `./build.sh`
