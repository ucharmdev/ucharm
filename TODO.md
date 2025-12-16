# μcharm Roadmap

## Vision

Python syntax + Zig native modules + tiny binaries = Go killer for CLI tools

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
│   term, ansi, fetch, sqlite, etc.   │
├─────────────────────────────────────┤
│        Single Binary                │
└─────────────────────────────────────┘
```

## Phase 1: Native Module Foundation

C modules compiled into custom MicroPython build

- [x] `term` - Terminal size, raw mode, cursor control, key reading
- [x] `ansi` - ANSI escape code generation (fg, bg, rgb, styles)
- [x] `args` - CLI argument parsing (int/float validation, flag parsing)
- [x] `env` - Environment variables (get, has, is_ci, no_color, etc.)
- [x] `path` - Path manipulation (join, basename, dirname, normalize, etc.)
- [x] `ui` - UI rendering (progress bars, boxes, tables, spinners, symbols)
- [ ] `utf8` - UTF-8 string operations, display width
- [ ] `io` - Buffered stdin/stdout
- [ ] `fs` - File operations
- [ ] `json` - Fast JSON parse/stringify
- [ ] `fetch` - HTTP client
- [ ] `sqlite` - SQLite database (optional, larger)

### Completed Native Modules

**term** (14 functions):
- `size()`, `raw_mode()`, `read_key()`, `write()`
- `cursor_pos()`, `cursor_up/down/left/right()`
- `clear()`, `clear_line()`, `hide_cursor()`, `show_cursor()`
- `is_tty()`

**ansi** (13 functions):
- `fg()`, `bg()`, `rgb()` - Color codes (names, 0-255, #hex, RGB)
- `bold()`, `dim()`, `italic()`, `underline()`, `strikethrough()`
- `blink()`, `reverse()`, `hidden()`, `reset()`

**args** (14 functions):
- `is_valid_int()`, `is_valid_float()`, `parse_int()` - Number validation
- `is_long_flag()`, `is_short_flag()`, `get_flag_name()` - Flag parsing
- `is_truthy()`, `is_falsy()`, `is_negated_flag()` - Boolean handling

**env** (18 functions):
- `get()`, `has()`, `get_or()`, `get_int()` - Variable access
- `is_truthy()`, `is_falsy()` - Boolean checks
- `is_ci()`, `is_debug()`, `no_color()`, `force_color()` - Common checks
- `home()`, `user()`, `shell()`, `pwd()`, `path()`, `editor()` - System paths

**path** (14 functions):
- `basename()`, `dirname()`, `extname()`, `stem()` - Path components
- `join()`, `join3()`, `normalize()`, `relative()` - Path manipulation
- `is_absolute()`, `is_relative()`, `has_extension()`, `has_ext()` - Checks
- `component_count()`, `component()` - Path splitting

**ui** (40+ functions):
- Text: `visible_len()`, `pad()`, `repeat_str()`
- Progress: `progress_bar()`, `percent_str()`
- Boxes: `box_top()`, `box_middle()`, `box_bottom()`, `box_chars()`
- Tables: `table_top()`, `table_divider()`, `table_bottom()`, `table_cell()`
- Spinners: `spinner_frame()`, `spinner_frame_count()`
- Symbols: `symbol_success()`, `symbol_error()`, `symbol_warning()`, etc.
- Cursor: `cursor_up()`, `cursor_down()`, `hide_cursor()`, `show_cursor()`

## Phase 2: Rebuild microcharm on Native Modules

Use native modules for performance, keep Python API

- [x] Rewrite terminal.py → native `term` module (with fallback)
- [x] Rewrite style.py → native `ansi` module (with fallback)
- [x] Rewrite input.py → native `term` for raw mode (with fallback)
- [ ] Full Charm Bracelet API parity (lipgloss, bubbles, huh)

## Phase 3: Smart Builds

Tree-shaking and modular builds for minimal size

- [ ] Analyze imports, include only used modules
- [ ] `--with` flag for explicit module inclusion
- [ ] Target: 5-15KB for simple CLIs, 30-50KB with TUI

## Phase 4: Compatibility Checker

Static analysis for MicroPython compatibility

- [ ] `mcharm check` - Detect unsupported syntax/imports
- [ ] Clear error messages with suggestions
- [ ] `--fix` flag for auto-fixable issues

## Phase 5: Developer Experience

- [ ] `mcharm init` - Interactive project setup
- [ ] `mcharm dev` - Watch mode with hot reload
- [ ] Pre-built binaries for macOS/Linux/Windows

## Binary Size Targets

| App Type | Target Size |
|----------|-------------|
| Hello world | ~5KB |
| Simple CLI (args, env) | ~10KB |
| TUI app (select, prompt) | ~20KB |
| Full TUI + HTTP + JSON | ~50KB |
| With SQLite | ~350KB |

## Immediate Tasks

- [x] Clean up `cli/src/root.zig` (unused file)
- [x] Integrate custom MicroPython build into `mcharm build`
- [x] Update microcharm Python library to use native modules when available

## Next Steps

- [ ] Add more native modules: `utf8`, `io`, `fs`, `json`
- [ ] Implement tree-shaking for smaller binaries
- [ ] Add `mcharm check` command for compatibility checking
