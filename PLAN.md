# Implementation Plan: Pure Zig Architecture

## Overview

Transform ucharm to a **100% Zig architecture** with zero Python files to maintain:

1. All stdlib modules as native Zig modules
2. All UI components (Box, Spinner, select, etc.) as native Zig modules  
3. Generated `.pyi` stubs for IDE support
4. Generated config files (pyrightconfig.json)
5. CPython test suite for compatibility verification

**End state**: The `ucharm/` Python directory is deleted entirely.

---

## Current State Analysis

### What Exists in Python (to be reimplemented in Zig)

| Category | Module/File | Functions | Complexity |
|----------|-------------|-----------|------------|
| **Stdlib** | compat/functools.py | partial, reduce, wraps, lru_cache | Medium |
| | compat/datetime.py | datetime, date, time, timedelta | High |
| | compat/pathlib.py | Path class | Medium |
| | compat/statistics.py | mean, median, stdev, variance | Medium |
| | compat/base64.py | b64encode, b64decode, urlsafe | Low |
| | compat/textwrap.py | wrap, fill, dedent, indent | Low |
| | compat/copy.py | copy, deepcopy | Medium |
| | compat/fnmatch.py | fnmatch, filter, translate | Low |
| | compat/typing.py | Type hints (no-op) | Low |
| **UI Components** | components.py | box, rule, spinner, progress, success/error/warning/info | Medium |
| | table.py | table, simple_table, key_value | Medium |
| | input.py | select, multiselect, confirm, prompt, password | High |
| **Styling** | style.py | style, colors, bold, dim, italic, underline | Medium |
| **Terminal** | terminal.py | get_size, clear, hide_cursor, move_cursor | Low |
| **Utilities** | args.py | parse, get, has, value, positional | Medium |
| | env.py | get, has, is_truthy, is_ci, no_color | Low |
| | path.py | basename, dirname, join, normalize | Low |
| | json.py | parse, stringify, get, path | Medium |

### What Already Exists in Native Zig

```
native/
├── term/        ✓ Terminal control
├── ansi/        ✓ ANSI colors
├── args/        ✓ Argument parsing
├── base64/      ✓ Base64 encoding
├── csv/         ✓ CSV parsing
├── datetime/    ✓ Date/time operations
├── functools/   ✓ reduce, partial, cmp_to_key
├── glob/        ✓ File pattern matching
├── itertools/   ✓ Iterators
├── logging/     ✓ Logging framework
├── path/        ✓ Path manipulation
├── pathlib/     ✓ Path class
├── shutil/      ✓ File operations
├── signal/      ✓ Signal handling
├── statistics/  ✓ Statistical functions
├── subprocess/  ✓ Process spawning
├── tempfile/    ✓ Temporary files
├── textwrap/    ✓ Text wrapping
├── env/         ✓ Environment variables
├── json/        ✓ JSON utilities
└── ui/          ✓ UI rendering helpers
```

### Gap Analysis: What's Missing

| Module | Status | Notes |
|--------|--------|-------|
| `copy` | **Missing** | Need copy, deepcopy |
| `fnmatch` | **Missing** | Need fnmatch, filter, translate |
| `typing` | **Missing** | No-op stubs for type hints |
| `charm` | **Missing** | New unified module for UI components |

The `charm` module will be a new native module containing:
- Box, Rule, Spinner, Progress components
- Select, Multiselect, Confirm, Prompt, Password inputs
- Success, Error, Warning, Info message helpers
- Table rendering

---

## Architecture: Final State

```
ucharm/
├── cli/                          # Zig CLI tool
│   └── src/
│       ├── main.zig
│       ├── build_cmd.zig
│       ├── run_cmd.zig           # UPDATED: No Python bundle needed
│       ├── new_cmd.zig
│       ├── test_cmd.zig          # NEW: ucharm test --compat
│       └── stubs_cmd.zig         # NEW: ucharm stubs
├── loader/                       # Universal binary loader
├── native/                       # All Zig modules
│   ├── term/
│   ├── ansi/
│   ├── charm/                    # NEW: UI components
│   ├── copy/                     # NEW
│   ├── fnmatch/                  # NEW
│   ├── typing/                   # NEW
│   └── ... (existing modules)
├── tests/
│   ├── cpython/                  # Vendored CPython tests
│   └── compat_report.md          # Generated report
└── (no ucharm/ Python directory)
```

### User Code Example (Final)

```python
#!/usr/bin/env micropython-ucharm

# All imports are native Zig modules
import term
import ansi
import charm
import subprocess
import signal

# Terminal control
cols, rows = term.size()
term.clear()

# Styling
print(ansi.bold() + ansi.fg("cyan") + "Hello!" + ansi.reset())

# UI Components
charm.box("Welcome to μcharm", title="Info", border="rounded")
charm.success("Operation completed")
charm.progress(50, 100, label="Loading")

# Interactive input
choice = charm.select("Pick one:", ["Option A", "Option B", "Option C"])
confirmed = charm.confirm("Are you sure?")
name = charm.prompt("Enter your name:")

# Tables
charm.table([
    ["Name", "Age", "City"],
    ["Alice", "30", "NYC"],
    ["Bob", "25", "LA"],
], headers=True)

# Spinner with context
with charm.spinner("Processing..."):
    subprocess.run(["sleep", "2"])
```

---

## Phase 0: Update `ucharm run` and `ucharm build` for Native Architecture

### Current State

**`ucharm run`** currently:
1. Extracts embedded `micropython-ucharm` binary to `/tmp/ucharm-<hash>/`
2. Bundles user script with `ucharm_bundle.py` (embedded Python TUI library)
3. Executes bundled script with micropython

**`ucharm build --mode universal`** currently:
1. Bundles user script with `ucharm_bundle.py`
2. Appends bundled Python to loader + micropython binary
3. Creates self-contained universal binary (~945KB)

### Target State

With pure-Zig native modules, both commands become simpler:

**`ucharm run`**:
1. Extract embedded `micropython-ucharm` binary (contains all native modules including `charm` and `input`)
2. Execute user script directly - no Python bundle needed

**`ucharm build --mode universal`**:
1. Append user script directly to loader + micropython binary
2. Creates smaller, faster universal binary (~900KB - no Python bundle overhead)

### Changes to `run_cmd.zig`

```zig
// BEFORE: Bundle Python library with user script
// const bundled = ucharm_bundle_py ++ "\n" ++ user_script;

// AFTER: Just run the user script directly
// All imports (charm, input, term, ansi, etc.) are native modules
// baked into micropython-ucharm
const script = user_script;
```

### Changes to `build_cmd.zig`

```zig
// BEFORE: Bundle Python library with user script
// const python_payload = ucharm_bundle_py ++ "\n" ++ user_script;

// AFTER: Just use the user script directly
// micropython-ucharm already has all UI modules as native code
const python_payload = user_script;
```

### Universal Binary Format: Before vs After

**Before (with Python bundle):**
```
┌────────────────────────────────────────┐
│  Zig Loader Stub (~98KB)               │
├────────────────────────────────────────┤
│  MicroPython Binary (~806KB)           │
├────────────────────────────────────────┤
│  ucharm_bundle.py (~35KB)              │  ← Python TUI library
├────────────────────────────────────────┤
│  User Python Code (~5KB)               │
├────────────────────────────────────────┤
│  Trailer (48 bytes)                    │
└────────────────────────────────────────┘
Total: ~945KB
```

**After (native modules):**
```
┌────────────────────────────────────────┐
│  Zig Loader Stub (~98KB)               │
├────────────────────────────────────────┤
│  MicroPython Binary (~850KB)           │  ← Includes native charm/input modules
├────────────────────────────────────────┤
│  User Python Code (~5KB)               │  ← Just the user's script
├────────────────────────────────────────┤
│  Trailer (48 bytes)                    │
└────────────────────────────────────────┘
Total: ~900KB (smaller, faster startup)
```

### Benefits

| Aspect | Before (Python bundle) | After (Native modules) |
|--------|------------------------|------------------------|
| Startup | Parse ~35KB bundle + script | Parse script only |
| Binary size | ~945KB | ~900KB |
| Performance | Python interpretation | Native Zig execution |
| Complexity | Bundle generation logic | Direct execution |

### Implementation

1. Remove `ucharm_bundle.py` from `cli/src/`
2. Update `run_cmd.zig` to execute scripts directly
3. Update `build_cmd.zig` to bundle only user script (no Python library)
4. Ensure `micropython-ucharm` has all native modules (`charm`, `input`, etc.)
5. Remove import stripping logic (no longer needed)
6. Update embedded `micropython-ucharm` stubs in `cli/src/stubs/`

---

## Phase 1: Compatibility Testing Infrastructure

### 1.1 New CLI Command: `ucharm test`

```zig
// cli/src/test_cmd.zig

// ucharm test --compat [--module functools] [--verbose]
//
// 1. For each module in tests/cpython/:
//    a. Run with python3, capture stdout/stderr/exit code
//    b. Run with micropython-ucharm, capture stdout/stderr/exit code
//    c. Compare results
// 2. Generate compat_report.md
// 3. Exit 0 if 100% parity, exit 1 otherwise
```

### 1.2 CPython Test Extraction

Download and adapt tests from https://github.com/python/cpython/tree/main/Lib/test

For each module:
1. Copy test file
2. Remove tests requiring unavailable features (threading, gc introspection)
3. Add skip markers with reasons
4. Ensure tests work standalone (no test framework dependencies)

### 1.3 Report Format

```markdown
# μcharm Compatibility Report

Generated: 2025-12-17
Overall: 847/892 tests passing (95.0%)

| Module      | CPython | μcharm  | Parity | Notes |
|-------------|---------|---------|--------|-------|
| functools   | 47/47   | 47/47   | 100%   | ✓ Full |
| itertools   | 89/89   | 85/89   | 95%    | 4 skipped |
| datetime    | 156/156 | 142/156 | 91%    | tz pending |
| copy        | 34/34   | 34/34   | 100%   | ✓ Full |
| ...         |         |         |        |       |

## Skipped Tests

### itertools
- `test_tee_threading`: requires threading module
- `test_groupby_gc`: requires gc.get_objects

### datetime  
- `test_timezone_*`: timezone support not implemented
```

---

## Phase 2: New Native Modules

### 2.1 `copy` Module

```zig
// native/copy/copy.zig

/// Shallow copy - new container, same element references
pub export fn copy_copy(obj: mp_obj_t) mp_obj_t { ... }

/// Deep copy - recursively copy all nested objects
pub export fn copy_deepcopy(obj: mp_obj_t) mp_obj_t { ... }
```

### 2.2 `fnmatch` Module

```zig
// native/fnmatch/fnmatch.zig

/// Match filename against pattern (*, ?, [seq], [!seq])
pub export fn fnmatch_fnmatch(pattern: [*:0]const u8, name: [*:0]const u8) bool { ... }

/// Filter list of names by pattern
pub export fn fnmatch_filter(names: mp_obj_t, pattern: [*:0]const u8) mp_obj_t { ... }

/// Convert shell pattern to regex
pub export fn fnmatch_translate(pattern: [*:0]const u8) mp_obj_t { ... }
```

### 2.3 `typing` Module

```zig
// native/typing/typing.zig

// No-op module - just exports names for import compatibility
// All type hints are erased at runtime

pub export fn typing_get_attr(name: [*:0]const u8) mp_obj_t {
    // Return a no-op callable for any attribute access
    // e.g., typing.List, typing.Optional, etc.
    return mp_const_none;
}
```

### 2.4 `charm` Module (UI Components)

Display components only (inputs moved to `input` module).

```zig
// native/charm/charm.zig

// === Box Component ===
pub export fn charm_box(content: [*:0]const u8, opts: mp_obj_t) void { ... }

// === Rule Component ===
pub export fn charm_rule(title: [*:0]const u8, opts: mp_obj_t) void { ... }

// === Spinner (with context manager support) ===
// Returns a Spinner object with __enter__/__exit__ for `with` statement
pub export fn charm_spinner(message: [*:0]const u8) mp_obj_t { ... }

// === Progress Bar ===
pub export fn charm_progress(current: i32, total: i32, opts: mp_obj_t) void { ... }

// === Status Messages ===
pub export fn charm_success(message: [*:0]const u8) void { ... }
pub export fn charm_error(message: [*:0]const u8) void { ... }
pub export fn charm_warning(message: [*:0]const u8) void { ... }
pub export fn charm_info(message: [*:0]const u8) void { ... }

// === Table ===
pub export fn charm_table(data: mp_obj_t, opts: mp_obj_t) void { ... }
```

### 2.5 `input` Module (Interactive Input)

Separated from charm for intuitive imports.

```zig
// native/input/input.zig

// === Single Selection ===
pub export fn input_select(prompt: [*:0]const u8, options: mp_obj_t) mp_obj_t { ... }

// === Multiple Selection ===
pub export fn input_multiselect(prompt: [*:0]const u8, options: mp_obj_t) mp_obj_t { ... }

// === Yes/No Confirmation ===
pub export fn input_confirm(prompt: [*:0]const u8, default: bool) bool { ... }

// === Text Input ===
pub export fn input_prompt(message: [*:0]const u8, opts: mp_obj_t) mp_obj_t { ... }

// === Hidden Text Input ===
pub export fn input_password(message: [*:0]const u8) mp_obj_t { ... }
```

### 2.6 Context Manager Implementation

For `with` statement support (e.g., spinner), we implement `__enter__` and `__exit__` 
methods in the C bridge layer:

```c
// In modcharm.c - Spinner context manager

typedef struct _spinner_obj_t {
    mp_obj_base_t base;
    const char *message;
    bool active;
} spinner_obj_t;

// __enter__ - start the spinner animation
static mp_obj_t spinner_enter(mp_obj_t self_in) {
    spinner_obj_t *self = MP_OBJ_TO_PTR(self_in);
    spinner_start(self->message);  // Call Zig function
    self->active = true;
    return self_in;
}

// __exit__ - stop the spinner, restore terminal
static mp_obj_t spinner_exit(size_t n_args, const mp_obj_t *args) {
    spinner_obj_t *self = MP_OBJ_TO_PTR(args[0]);
    if (self->active) {
        spinner_stop();  // Call Zig function
        self->active = false;
    }
    return mp_const_false;  // Don't suppress exceptions
}

// Register methods in locals_dict
static const mp_rom_map_elem_t spinner_locals_dict_table[] = {
    { MP_ROM_QSTR(MP_QSTR___enter__), MP_ROM_PTR(&spinner_enter_obj) },
    { MP_ROM_QSTR(MP_QSTR___exit__), MP_ROM_PTR(&spinner_exit_obj) },
};
```

**Usage:**
```python
import charm

with charm.spinner("Loading..."):
    # Do work here
    subprocess.run(["make", "build"])
# Spinner automatically stopped, terminal restored
```

---

## Phase 3: Stub Generation

### 3.1 New CLI Command: `ucharm stubs`

```zig
// cli/src/stubs_cmd.zig

// ucharm stubs [--output ./typings]
//
// 1. Parse native/*/*.zig for exported functions
// 2. Extract function signatures and docstrings
// 3. Map Zig types to Python types
// 4. Generate .pyi files
```

### 3.2 Stub Metadata in Zig

Add docstrings and type hints as comments in Zig:

```zig
// native/term/term.zig

/// Get terminal dimensions
/// @python def size() -> tuple[int, int]: ...
pub export fn term_size() ... { ... }

/// Enable or disable raw input mode
/// @python def raw_mode(enable: bool) -> None: ...
pub export fn term_raw_mode(enable: bool) void { ... }
```

The stub generator parses these `@python` comments.

### 3.3 Generated Stubs

```python
# typings/term.pyi
"""Terminal control module."""

def size() -> tuple[int, int]:
    """Get terminal dimensions (columns, rows)."""
    ...

def raw_mode(enable: bool) -> None:
    """Enable or disable raw input mode."""
    ...

def read_key() -> str:
    """Read a single keypress."""
    ...
```

```python
# typings/charm.pyi
"""UI components and interactive input."""

def box(content: str, *, title: str | None = None, 
        border: str = "rounded", padding: int = 1) -> None:
    """Render a box around content."""
    ...

def select(prompt: str, options: list[str], default: int = 0) -> str | None:
    """Interactive single-choice selection."""
    ...

def table(data: list[list[str]], *, headers: bool = False,
          border: bool = True) -> None:
    """Render a table."""
    ...
```

### 3.4 Generated pyrightconfig.json

Generated by `ucharm new`:

```json
{
    "include": ["**/*.py"],
    "stubPath": "./typings",
    "pythonVersion": "3.10",
    "reportMissingModuleSource": "none",
    "typeCheckingMode": "basic",
    "extraPaths": []
}
```

---

## Phase 4: Delete Python Code

After all native modules are implemented and tests pass:

```bash
# Delete entire Python library
rm -rf ucharm/

# Delete Python tests that were for the Python implementation
rm -rf tests/test_compat_vs_cpython.py
rm -rf examples/test_compat*.py

# Keep native module tests
# native/*/test_*.py (these run on both CPython and micropython-ucharm)
```

---

## Phase 5: CI/CD

### 5.1 GitHub Actions

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    
    steps:
      - uses: actions/checkout@v4
      - uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.13.0
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      
      - name: Build CLI
        run: cd cli && zig build -Doptimize=ReleaseSmall
      
      - name: Build native modules
        run: cd native && ./build.sh
      
      - name: Run Zig tests
        run: cd cli && zig build test
      
      - name: Run compatibility tests
        run: ./cli/zig-out/bin/ucharm test --compat
      
      - name: Run E2E tests
        run: cd cli && ./test_e2e.sh
      
      - name: Generate stubs
        run: ./cli/zig-out/bin/ucharm stubs --output ./typings
      
      - name: Verify stubs are up to date
        run: git diff --exit-code typings/
```

---

## Execution Plan: Parallel Agents

### Wave 1 (Parallel - 7 agents)

| Agent | Task | Deliverable |
|-------|------|-------------|
| 1 | Implement `copy` native module | native/copy/ |
| 2 | Implement `fnmatch` native module | native/fnmatch/ |
| 3 | Implement `typing` native module | native/typing/ |
| 4 | Implement `charm` module (UI display components) | native/charm/ |
| 5 | Implement `input` module (interactive input) | native/input/ |
| 6 | Build `ucharm test --compat` command | cli/src/test_cmd.zig |
| 7 | Build `ucharm stubs` command | cli/src/stubs_cmd.zig |

### Wave 2 (Parallel - 2 agents)

| Agent | Task | Deliverable |
|-------|------|-------------|
| 8 | Extract full CPython test files (skip only unplanned modules) | tests/cpython/*.py |
| 9 | Write stub metadata comments in existing native modules | native/*/*.zig updates |

### Wave 3 (Sequential)

1. Run full compatibility test suite
2. Fix any failing tests
3. Delete Python code
4. Update documentation
5. Set up CI/CD

### Wave 4: Update CLI Commands (After native modules complete)

| Task | Description |
|------|-------------|
| 1 | Rebuild `micropython-ucharm` with new native modules (`charm`, `input`, `copy`, `fnmatch`, `typing`) |
| 2 | Update embedded stubs in `cli/src/stubs/` with new micropython-ucharm binaries |
| 3 | Update `run_cmd.zig` to remove Python bundle logic |
| 4 | Update `build_cmd.zig` to remove Python bundle from universal binaries |
| 5 | Delete `cli/src/ucharm_bundle.py` |
| 6 | Test `ucharm run` with scripts using native imports |
| 7 | Test `ucharm build --mode universal` creates working self-contained binaries |
| 8 | Verify binary sizes are smaller without Python bundle overhead |

This ensures both commands remain fully self-contained:
- `ucharm run` - CLI embeds `micropython-ucharm` with all native modules
- `ucharm build --mode universal` - Produces single static binary with loader + micropython + user script

---

## Success Criteria

1. **Zero Python files** in repository (except test files that run on both runtimes)
2. **100% compatibility** with CPython for implemented modules
3. **IDE autocomplete** works via generated stubs
4. **All existing functionality** preserved in native modules
5. **CI passes** on every commit
6. **Self-contained CLI** - `ucharm run` works with zero external dependencies, all modules native in embedded micropython

---

## File Structure: Final

```
ucharm/
├── cli/
│   ├── src/
│   │   ├── main.zig
│   │   ├── build_cmd.zig
│   │   ├── run_cmd.zig
│   │   ├── new_cmd.zig
│   │   ├── test_cmd.zig      # NEW
│   │   └── stubs_cmd.zig     # NEW
│   ├── build.zig
│   └── test_e2e.sh
├── loader/
│   └── src/
│       ├── main.zig
│       ├── trailer.zig
│       └── executor.zig
├── native/
│   ├── term/
│   ├── ansi/
│   ├── charm/                # NEW - all UI
│   ├── copy/                 # NEW
│   ├── fnmatch/              # NEW
│   ├── typing/               # NEW
│   ├── args/
│   ├── base64/
│   ├── csv/
│   ├── datetime/
│   ├── env/
│   ├── functools/
│   ├── glob/
│   ├── itertools/
│   ├── json/
│   ├── logging/
│   ├── path/
│   ├── pathlib/
│   ├── shutil/
│   ├── signal/
│   ├── statistics/
│   ├── subprocess/
│   ├── tempfile/
│   ├── textwrap/
│   ├── build.sh
│   └── dist/
├── tests/
│   ├── cpython/              # Vendored CPython tests
│   │   ├── test_functools.py
│   │   ├── test_itertools.py
│   │   └── ...
│   └── compat_report.md      # Generated
├── typings/                  # Generated stubs
│   ├── term.pyi
│   ├── ansi.pyi
│   ├── charm.pyi
│   └── ...
├── examples/
│   ├── simple_cli.py
│   ├── demo.py
│   └── ...
├── .github/
│   └── workflows/
│       └── ci.yml
├── CLAUDE.md
├── README.md
└── TODO.md
```

---

## Decisions Made

1. **Module organization**: Interactive inputs (select, confirm, prompt) are in separate `input` module for intuitive imports
2. **Context managers**: Implemented via `__enter__`/`__exit__` methods in C bridge layer (works with Python's `with` statement)
3. **Test approach**: Vendor full CPython test files, only skip entire modules we don't plan to implement
4. **Stubs publishing**: Generate locally with config for now, publish to PyPI later
