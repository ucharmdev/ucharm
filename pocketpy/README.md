# PocketPy Runtime

This folder contains the **PocketPy-based Python runtime** for ucharm. PocketPy is the primary execution engine, replacing the previous MicroPython implementation.

## What's in here?

- `vendor/pocketpy.c` + `vendor/pocketpy.h`  
  Vendored from PocketPy release (see `POCKETPY_VERSION` for current version).

- `src/`  
  Zig sources for the runtime:
  - `main.zig` - Entry point, initializes PocketPy and runs scripts
  - `runtime.zig` - Module registration for all native Zig modules
  - `pk.zig` - High-level extension API for safer PocketPy bindings

- `POCKETPY_VERSION`  
  Tracks the current vendored PocketPy version.

## Build

```bash
# Debug build
zig build

# Release build (smaller binary)
zig build -Doptimize=ReleaseSmall

# The binary is output to:
# zig-out/bin/pocketpy-ucharm
```

## Usage

```bash
# Run a Python script
./zig-out/bin/pocketpy-ucharm script.py

# Run with arguments
./zig-out/bin/pocketpy-ucharm script.py arg1 arg2
```

## Runtime Modules

The runtime includes native Zig implementations of:

**ucharm modules** (TUI/CLI):
- `ansi` - ANSI escape codes
- `args` - CLI argument parsing
- `charm` - TUI components (boxes, rules, spinners)
- `input` - Interactive prompts (select, confirm)
- `term` - Terminal control

**CPython compatibility modules** (in `runtime/compat/`):
- Full implementations: `csv`, `datetime`, `errno`, `fnmatch`, `functools`, `glob`, `itertools`, `json`, `logging`, `pathlib`, `shutil`, `signal`, `statistics`, `subprocess`, `tempfile`, `textwrap`, `typing`
- Extensions to built-in modules: `math`, `os`, `time`, `collections`

## Updating PocketPy

Use the version check script:

```bash
# Check for updates
./scripts/check-pocketpy-version.sh

# Download and update
./scripts/check-pocketpy-version.sh --update
```

After updating, apply the required `match` soft keyword patch (see CLAUDE.md) and rebuild.

## Compatibility Testing

```bash
# Run CPython compatibility tests
python3 tests/compat_runner.py --report

# Test a specific module
python3 tests/compat_runner.py -m json
```

Current compatibility: ~77% (1,245/1,604 tests passing across 41 targeted modules).
