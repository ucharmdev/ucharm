# μcharm Plan and Roadmap

This is the single source of truth for priorities and next steps.

## Snapshot

- Goal: build beautiful CLI apps with Python syntax, shipped as tiny, fast binaries.
- Runtime: PocketPy + runtime Zig modules + Zig loader for universal binaries.
- Compatibility status: `tests/compat_report_pocketpy.md` shows ~77% (1,245/1,604 tests) passing with 28/41 modules at 100% parity. Refresh with `python3 tests/compat_runner.py --report`.

## Current State (from the repo)

- Native modules cover TUI (charm/input/ui), terminal + ANSI, and a growing stdlib set (copy, fnmatch, typing, csv, datetime, json, subprocess, signal, logging, etc.).
- Loader and CLI already build and run universal binaries; `cli/src/test_cmd.zig` and `tests/compat_runner.py` provide compatibility tooling.
- Stubs exist in `stubs/` and `cli/src/stubs/`; there is a generator script in `scripts/generate_stubs.py`.
- CPython tests are vendored under `tests/cpython/` and are used to track parity.

## PocketPy Migration Plan

### Phase 1: Runtime switch + tooling (COMPLETE)
- PocketPy is now the default and only runtime.
- MicroPython has been removed from the project.
- `tests/compat_runner.py` defaults to PocketPy.

### Phase 2: Module parity + API surface
- Keep Zig-only modules as the standard and avoid Python fallback modules.
- Close remaining parity gaps in the lowest-coverage stdlib modules (`array`, `binascii`, `io`, `struct`, `hashlib`).
- Refresh `tests/compat_report_pocketpy.md` after each module batch.

### Phase 3: DX + packaging alignment
- Align stubs with the PocketPy import surface and regenerate with a single command.
- Update templates/examples to reference the PocketPy runtime and current modules.
- Add CI target for PocketPy compatibility report generation.

## What to Focus on Next

1. Close parity gaps for the lowest-coverage stdlib modules (`array`, `binascii`, `io`, `struct`, and `hashlib`).
2. Refresh compatibility results and document the target set and skips in `compat_report.md`.
3. Consolidate stub generation and make it a predictable workflow for users (single source of truth, one command).
4. Align docs/examples with the actual import surface and module names shipped in the binary.
5. Tackle one or two high-leverage missing modules used by CLI tools (`configparser`, `enum`, `uuid`, `urllib.parse`).

## Plan (near-term)

### Phase A: Compatibility push
- Improve parity for `array`, `binascii`, `io`, `struct`, `hashlib`.
- Update `tests/cpython/` as needed to match PocketPy constraints and re-run `python3 tests/compat_runner.py --report`.
- Regenerate `tests/compat_report_pocketpy.md` and add short notes for remaining skips.

### Phase B: Developer experience
- Decide the canonical stub source (Zig annotations or `stubs/`) and wire `scripts/generate_stubs.py` or a CLI command to regenerate them.
- Update templates and docs to reference the canonical stubs and correct import paths.

### Phase C: Targeted stdlib expansion
- Implement small, high-impact modules: `configparser`, `enum`, `uuid`, `urllib.parse`, `contextlib`.
- Add tests for each new module using the compatibility runner.

## Backlog (ordered)

- Tree-shaking or module selection for smaller binaries.
- `ucharm dev` (watch mode / hot reload).
- Networking and formats: `http.client`, `toml`, `yaml`, `gzip`, `zipfile`, `tarfile`.
- Security: `secrets`, `hmac`.
- Concurrency: `threading`, `queue` (PocketPy threading support TBD).
- Database: `sqlite3`.
