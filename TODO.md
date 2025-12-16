# μcharm TODO

## Immediate Tasks

- [ ] Clean up `cli/src/root.zig` (unused file)

## Platform Support

- [ ] **Linux support** - Change `libc.dylib` to `libc.so.6` detection in `input.py`
- [ ] **Windows support** - Replace termios-based input with Windows console API

## Build & Distribution

- [ ] **Cross-compilation** - Build Linux/Windows binaries from macOS using Zig
- [ ] **Pre-built binaries** - Add GitHub releases with binaries for major platforms
- [ ] **Embed MicroPython** - Link against MicroPython as C library (no extraction needed)

## Features

- [ ] **Package management** - pip-like system for micropython-lib packages
- [ ] **File picker component** - Interactive file/directory browser
- [ ] **Autocomplete input** - Text input with suggestions
- [ ] **Markdown rendering** - Simple markdown to terminal output
- [ ] **Themes** - Built-in color themes (dark, light, high-contrast)

## Testing

- [ ] **MicroPython library tests** - Unit tests for the Python TUI components
- [ ] **CI/CD pipeline** - GitHub Actions for automated testing and releases

## Documentation

- [ ] **API documentation** - Generate docs from docstrings
- [ ] **Tutorial** - Step-by-step guide for building a CLI app
- [ ] **Examples** - More example applications (todo app, file manager, etc.)

## Performance

- [ ] **Startup profiling** - Identify and optimize cold start bottlenecks
- [ ] **Bundle size optimization** - Minimize embedded Python code size
