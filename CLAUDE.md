# CLAUDE.md - AI Assistant Guide for ucharm

## Project Overview

**ucharm** is a CLI toolkit for building beautiful, fast, tiny command-line applications with Python syntax powered by **PocketPy**. The goal is a Pythonic DX with instant startup and tiny single-file binaries.

**Repository**: https://github.com/ucharmdev/ucharm

## Architecture

```
┌─────────────────────────────────────┐
│         Your Python Code            │
│   (standard Python syntax)          │
├─────────────────────────────────────┤
│         PocketPy VM                 │
│   (bytecode interpreter)            │
├─────────────────────────────────────┤
│   Runtime Modules (Zig)             │
│   term, ansi, charm, input, ...     │
├─────────────────────────────────────┤
│        Single Binary                │
│   (universal, no dependencies)      │
└─────────────────────────────────────┘
```

## The ucharm CLI

The `ucharm` CLI is a **fully self-contained binary** that embeds:
- **pocketpy-ucharm**: PocketPy with runtime modules implemented in Zig

This means `ucharm run script.py` works with zero external dependencies. All TUI functionality (boxes, colors, prompts) is provided by Zig runtime modules.

## Directory Structure

```
ucharm/
├── cli/                      # Zig CLI tool (ucharm)
│   ├── src/
│   │   ├── main.zig          # Entry point, command routing
│   │   ├── build_cmd.zig     # Build command (single/executable/universal)
│   │   ├── init_cmd.zig      # Initialize project (stubs, AI instructions)
│   │   ├── new_cmd.zig       # Project scaffolding
│   │   ├── run_cmd.zig       # Run scripts (embeds pocketpy)
│   │   ├── stubs/            # Embedded binaries and type stubs
│   │   └── templates/        # AI instruction templates (edit these!)
│   └── build.zig             # Zig build configuration
├── runtime/                  # Zig runtime modules (PocketPy bindings + cores)
│   ├── ucharm/               # ucharm-native UX modules
│   │   ├── ansi/
│   │   ├── charm/
│   │   ├── input/
│   │   ├── term/
│   │   └── args/
│   └── compat/               # CPython-compat modules (argparse, csv, etc.)
├── pocketpy/                 # PocketPy runtime build + Zig modules
│   ├── src/modules/          # PocketPy module bindings (Zig)
│   ├── src/runtime.zig       # Module registration
│   └── build.zig             # pocketpy-ucharm build
├── loader/                   # Universal binary loader (Zig)
├── website/                  # Documentation site (Fumadocs + Next.js)
│   ├── content/docs/         # MDX documentation files
│   ├── src/components/       # React components (Terminal, etc.)
│   └── src/app/              # Next.js app
├── scripts/
├── tests/
└── README.md
```

## Key Commands

```bash
# Build PocketPy runtime
cd pocketpy && zig build -Doptimize=ReleaseSmall

# Build CLI
cd cli && zig build -Doptimize=ReleaseSmall

# Run Vision tests
python3 tests/vision/run_vision.py --timeout 20 --runtime ./pocketpy/zig-out/bin/pocketpy-ucharm

# Run compatibility tests (defaults to pocketpy-ucharm)
python3 tests/compat_runner.py --report --runtime ./pocketpy/zig-out/bin/pocketpy-ucharm

# Run a script
./cli/zig-out/bin/ucharm run examples/demo.py
```

## Zig-Only Policy (No C/Python Implementations)

All new functionality must be implemented in **Zig**. Do not add C or Python implementations for runtime modules. Use the PocketPy C API from Zig as needed, but keep the module logic in Zig.

This ensures:
- Consistent architecture
- Small binaries
- High performance

## PocketPy Vendor Policy

Avoid direct edits to `pocketpy/vendor/pocketpy.c` / `pocketpy.h`. If a vendor change is necessary, capture it as a patch in `pocketpy/patches/` and update `pocketpy/patches/manifest.json` so `scripts/apply-pocketpy-patches.sh` stays idempotent.

PocketPy is vendored from upstream releases. Any patches become a maintenance burden that must be re-applied on every update. Instead:

1. **Extend existing modules from Zig** - Use `c.py_getmodule("modulename")` to get a built-in module and add functions to it. Example: `runtime/compat/math.zig` extends the built-in `math` module with `sinh`, `cosh`, `tanh`, `frexp`, `ldexp`.

2. **Create new modules in Zig** - For missing stdlib modules, implement them entirely in Zig under `runtime/compat/`.

3. **Report upstream issues** - If PocketPy is missing functionality that can't be added via Zig, open an issue or PR upstream.

To update PocketPy:
```bash
# Download latest release
curl -sL https://github.com/pocketpy/pocketpy/releases/download/vX.Y.Z/pocketpy.c -o pocketpy/vendor/pocketpy.c
curl -sL https://github.com/pocketpy/pocketpy/releases/download/vX.Y.Z/pocketpy.h -o pocketpy/vendor/pocketpy.h
```

### μcharm Patchset (vendor)

If we *must* patch PocketPy, keep it:
- Small and surgical
- Marked with `ucharm patch:` anchors in `pocketpy/vendor/pocketpy.c`
- Tracked as a re-applicable patch file under `pocketpy/patches/`

After updating PocketPy, re-apply and verify:

```bash
./scripts/apply-pocketpy-patches.sh
python3 scripts/verify-pocketpy-patches.py --check-upstream
```

### Required Patch (part of patchset): `match` Soft Keyword

PocketPy treats `match` as a hard keyword, but Python 3.10+ treats it as a soft keyword (only a keyword in pattern matching contexts). This breaks `re.match()` and similar APIs.

After updating PocketPy, apply this patch to `pocketpy/vendor/pocketpy.c` in the `exprAttrib` function:

```c
static Error* exprAttrib(Compiler* self) {
    // ucharm patch: allow 'match' soft keyword as attribute name (for re.match, etc.)
    if(curr()->type == TK_MATCH) {
        advance();
    } else {
        consume(TK_ID);
    }
    py_Name name = py_namev(Token__sv(prev()));
    // ... rest of function
}
```

This patch is tracked in `pocketpy/patches/0001-match-soft-keyword.patch` (along with a small patchset required for CPython-compat modules).
Prefer upstream fixes where possible; keep the local patchset minimal.

### Known PocketPy Limitations

Some Python features are not supported by PocketPy:

1. **Implicit string concatenation** - `"a" "b"` or `f"a" f"b"` syntax is not supported. Use explicit concatenation: `"a" + "b"`.

2. **Native function kwargs** - Use `funcSigWrapped` instead of `funcWrapped` for kwargs support (see Kwargs Support section below).

3. **Some stdlib modules** - Missing modules are implemented in `runtime/compat/`. Run `python3 tests/compat_runner.py --report` to see current compatibility status.

## Writing Great Zig Runtime Modules

**Goals:** fast startup, small code, predictable behavior.

Guidelines:
- Keep APIs minimal and explicit; mirror CPython only where needed.
- Prefer pure Zig for logic; use OS syscalls via `std.posix`.
- Validate inputs early and return clear errors via PocketPy exceptions.
- Avoid allocations in hot paths; use stack buffers and small helpers.
- Keep module state explicit and minimal (no hidden globals unless required).
- Add short comments only when the intent is non-obvious.

### Module Pattern

1. Core logic in `runtime/<module>/<module>.zig` (if shared elsewhere).
2. PocketPy bindings in `runtime/**/pocketpy.zig`.
3. Register modules in `pocketpy/src/runtime.zig`.
4. Update type stubs in `stubs/` and copy to `cli/src/stubs/`.

### The pk.zig Extension API

Use `pocketpy/src/pk.zig` for all new module bindings. It provides safer, ergonomic wrappers:

```zig
const pk = @import("../../pocketpy/src/pk.zig");
const c = pk.c;

fn greetFn(ctx: *pk.Context) bool {
    const name = ctx.argStr(0) orelse return ctx.typeError("expected string");
    // ... do work ...
    return ctx.returnStr(result);
}

pub fn register() void {
    const builder = pk.ModuleBuilder.new("mymodule");
    _ = builder.funcWrapped("greet", 1, 1, greetFn);
}
```

**Key types:**
- `pk.Value` - Safe wrapper around `py_TValue` with type checks and extraction
- `pk.Context` - Argument access (`argStr`, `argInt`, `argFloat`, `argBool`) and returns (`returnStr`, `returnInt`, etc.)
- `pk.ModuleBuilder` - Fluent API for module creation and function binding
- `pk.TypeBuilder` - Fluent API for custom type creation with methods and properties

**Critical pattern - String arguments:**
```zig
// CORRECT: Use argStr which accesses argv directly
const s = ctx.argStr(0) orelse return ctx.typeError("expected string");

// OK (but prefer argStr for simple args): Value.toStr() returns a slice into the
// Python string data. Keep the Value alive for as long as you need the slice.
var v = ctx.arg(0) orelse return false;
const s = v.toStr() orelse return ctx.typeError("expected string");
```

**Register clobbering:** The PocketPy C API uses global registers (`py_r0()`, `py_r1()`, etc.) that get overwritten by many API calls. The `pk.Value` type copies values to local storage; prefer `ctx.argStr()` for direct argv access when extracting string arguments.

### Kwargs Support

Native functions (`nativefunc`) in PocketPy do NOT support keyword arguments. To get kwargs support, use signature-based binding which creates a `function` object instead:

```zig
// NO kwargs support - uses py_bindfunc internally
builder.funcWrapped("style", 1, 8, styleFn);

// WITH kwargs support - uses py_bind with signature
builder.funcSigWrapped("style(text, fg=None, bg=None, bold=False)", 1, 8, styleFn);
```

The signature tells PocketPy the parameter names and defaults, enabling `style("hello", bold=True)` syntax.

### Extending Built-in Types

You can add methods to built-in types like `str` from Zig without modifying `pocketpy.c`:

```zig
pub fn register() void {
    const str_type = c.py_tpobject(c.tp_str);
    c.py_bind(str_type, "isdigit(self)", pk.wrapFn(1, 1, isdigitFn));
}
```

Example: `runtime/compat/str_ext.zig` adds `isdigit()`, `isalpha()`, `isalnum()`, etc. to the `str` type.

### Legacy Binding Tips (raw C API)

For edge cases where pk.zig doesn't fit:
- Use `py_bind(module, "fn(sig)", fn)` for functions.
- Use `py_check*` and `py_to*` to validate/convert values.
- Return strings with `py_newstr` / `py_newstrn` / `py_newstrv`.
- Use `py_exception(tp_TypeError, "...")` for invalid arguments.
- **Use stack-allocated `py_TValue` for dict items** - `py_dict_setitem` takes `py_Ref` pointers that must remain valid.

## Keeping Templates and Stubs Up To Date

When adding or modifying runtime modules, update:

- `stubs/*.pyi` and copy to `cli/src/stubs/`.
- `cli/src/templates/AGENTS.md`, `cli/src/templates/CLAUDE.md`, and `cli/src/templates/copilot-instructions.md`.
- `README.md` if public APIs or workflows changed.
- `website/content/docs/` if module APIs or features changed.

## Website (ucharm.dev)

The documentation website is in `website/` and deployed via Vercel.

```bash
# Run dev server
cd website && bun run dev

# Build for production
cd website && bun run build
```

Update docs when:
- Adding new modules → `website/content/docs/modules/`
- Changing APIs → Update relevant MDX files
- Adding features → Update getting started guides

## Committing Changes

Use the `/commit` command before committing. It runs the repo checklist and keeps docs/templates/stubs in sync.
