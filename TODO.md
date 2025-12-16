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
- [ ] `utf8` - UTF-8 string operations, display width
- [ ] `io` - Buffered stdin/stdout
- [ ] `args` - CLI argument parsing
- [ ] `env` - Environment variables
- [ ] `fs` - File operations
- [ ] `path` - Path manipulation
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

- [ ] Add more native modules: `utf8`, `io`, `args`
- [ ] Implement tree-shaking for smaller binaries
- [ ] Add `mcharm check` command for compatibility checking
