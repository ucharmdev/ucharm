# μcharm Plan and Roadmap

This is the single source of truth for priorities and next steps.

## Snapshot

- Goal: build beautiful CLI apps with Python syntax, shipped as tiny, fast binaries.
- Runtime: PocketPy + runtime Zig modules + Zig loader for universal binaries.
- Compatibility status: `tests/compat_report_pocketpy.md` shows 50/52 targeted modules at 100% parity (2 have no baseline on older CPython versions). Refresh with `python3 tests/compat_runner.py --report`.
- PocketPy vendor patches are tracked under `pocketpy/patches/` and verified via `python3 scripts/verify-pocketpy-patches.py --check-upstream`.

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
- Targeted stdlib parity is now at 100% for the current module set (see `tests/compat_report_pocketpy.md`).
- Maintain parity by re-running `python3 tests/compat_runner.py --report` after runtime changes.

### Phase 3: DX + packaging alignment
- Align stubs with the PocketPy import surface and regenerate with a single command.
- Update templates/examples to reference the PocketPy runtime and current modules.
- Add CI target for PocketPy compatibility report generation.

## What to Focus on Next

1. Keep the compatibility story crisp: document what’s implemented vs intentionally missing, and keep `tests/compat_report_pocketpy.md` current.
2. Only after module coverage feels good: consolidate stub generation and make it a predictable workflow (one command, single source of truth).
3. Add CI targets for Vision + compatibility report generation.
4. Keep cross-target builds working: ensure `ucharm build --target <target>` continues to fetch/run the correct `pocketpy-ucharm` runtime.
   - In a source checkout, `ucharm build` can build missing target runtimes locally via Zig (no release assets required).

## Plan (near-term)

### Phase A: Close feature gap (Vision)
- Maintain the Vision “nice-to-have” surface (`toml`/`tomllib`, `http.client`, `secrets`, `hmac`, `dataclasses`, `xml.etree`, `sqlite3`, and archive helpers).
- Keep the suite honest by expanding tests when behavior changes.

### Phase B: Developer experience
- Decide the canonical stub source (Zig annotations or `stubs/`) and wire `scripts/generate_stubs.py` or a CLI command to regenerate them.
- Update templates and docs to reference the canonical stubs and correct import paths.

### Phase C: Packaging + release hygiene
- Add a CI step that runs `python3 tests/compat_runner.py --report` and uploads the report as an artifact.
- Add a CI step that runs `python3 scripts/verify-pocketpy-patches.py --check-upstream`.
- Validate cross-target build support (`ucharm build --targets` and a sample `--target` build).
 - Consider producing all `pocketpy-ucharm` target runtimes from one host via Zig cross-compilation (may remove the need for a matrix).

## Backlog (ordered)

- Tree-shaking or module selection for smaller binaries.
- `ucharm dev` (watch mode / hot reload).
- Networking and formats: `http.client`, `toml`, `yaml`, `gzip`, `zipfile`, `tarfile`.
- Security: `secrets`, `hmac`.
- Concurrency: `threading`, `queue` (PocketPy threading support TBD).
- Database: `sqlite3` (likely large; consider an optional build flag / separate release flavor).
