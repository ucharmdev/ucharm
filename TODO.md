# μcharm Roadmap

## Vision

Python syntax + Zig native modules + tiny binaries = Go killer for CLI tools

## Current Status

**What works today:**
- 18 native Zig modules compiled into MicroPython
- Instant startup universal binaries (~6ms warm, ~10ms cold)
- Cross-platform builds (macOS ARM64/x86_64, Linux x86_64)
- Full TUI support (select, confirm, prompt, tables, progress, spinners)
- CLI stdlib modules: subprocess, signal, csv, functools, itertools, logging

**Binary sizes:**
- Universal binary: ~945KB (fully standalone)
- micropython-mcharm: ~806KB
- mcharm CLI: ~220KB

## Module Comparison: Python vs MicroPython vs μcharm

### Core Modules (Available in All)

| Module | Python | MicroPython | μcharm | Notes |
|--------|--------|-------------|--------|-------|
| `os` | ✅ | ✅ | ✅ | listdir, getcwd, mkdir, remove, stat |
| `sys` | ✅ | ✅ | ✅ | argv, path, exit, stdin/stdout |
| `json` | ✅ | ✅ | ✅ Native | μcharm has fast Zig JSON |
| `re` | ✅ | ✅ | ✅ | Basic regex support |
| `time` | ✅ | ✅ | ✅ | time, sleep, localtime |
| `math` | ✅ | ✅ | ✅ | Full math functions |
| `random` | ✅ | ✅ | ✅ | random, randint, choice |
| `struct` | ✅ | ✅ | ✅ | Binary packing/unpacking |
| `hashlib` | ✅ | ✅ | ✅ | sha256, sha1, md5 |
| `collections` | ✅ | ⚠️ | ⚠️ | OrderedDict, deque (no Counter) |
| `io` | ✅ | ✅ | ✅ | StringIO, BytesIO |
| `errno` | ✅ | ✅ | ✅ | Error constants |
| `binascii` | ✅ | ✅ | ✅ | hexlify, unhexlify |
| `socket` | ✅ | ✅ | ✅ | TCP/UDP sockets |
| `select` | ✅ | ✅ | ✅ | I/O multiplexing |
| `ssl/tls` | ✅ | ✅ | ✅ | TLS support |
| `asyncio` | ✅ | ✅ | ✅ | Async/await support |
| `argparse` | ✅ | ✅ | ✅ | Argument parsing |
| `platform` | ✅ | ⚠️ | ⚠️ | Basic platform info |
| `gc` | ✅ | ✅ | ✅ | Garbage collection |
| `array` | ✅ | ✅ | ✅ | Typed arrays |
| `heapq` | ✅ | ✅ | ✅ | Heap queue |

### μcharm Native Modules (Zig-powered)

| Module | Functions | Performance vs Python |
|--------|-----------|----------------------|
| `term` | size, raw_mode, read_key, cursor, clear | N/A (not in stdlib) |
| `ansi` | fg, bg, rgb, bold, italic, reset | N/A (not in stdlib) |
| `args` | parse, is_flag, is_valid_int/float | N/A (not in stdlib) |
| `base64` | b64encode, b64decode, urlsafe | **4x faster** |
| `csv` | reader, writer, parse, format | **1.6x faster** (format) |
| `datetime` | now, utcnow, timestamp, isoformat | Similar |
| `functools` | reduce, partial, cmp_to_key | Similar |
| `glob` | glob, rglob | Similar |
| `fnmatch` | fnmatch, filter | Similar |
| `itertools` | count, cycle, repeat, chain, islice, etc. | Similar |
| `logging` | debug, info, warning, error, Logger | Similar |
| `path` | basename, dirname, join, normalize | Similar |
| `shutil` | copy, move, rmtree, exists, isfile | Similar |
| `signal` | signal, alarm, kill, getpid | **6.6x faster** |
| `statistics` | mean, median, stdev, variance | **16x faster** |
| `subprocess` | run, call, check_output, Popen | **1.5x faster** (shell) |
| `tempfile` | gettempdir, mkstemp, mkdtemp | Similar |
| `textwrap` | wrap, fill, dedent, indent | Similar |

### Missing from MicroPython (Need Pure Python or Native)

#### Priority 1: Essential for CLI Scripts

| Module | Status | Effort | Notes |
|--------|--------|--------|-------|
| `subprocess` | ✅ **Done** | Large | Native Zig - run, call, check_output, Popen |
| `signal` | ✅ **Done** | Medium | Native Zig - signal, alarm, kill, getpid |
| `csv` | ✅ **Done** | Small | Native Zig - RFC 4180 compliant |
| `configparser` | ❌ Missing | Small | INI file parsing |
| `logging` | ✅ **Done** | Medium | Native Zig - debug, info, warning, error, Logger |
| `getpass` | ❌ Missing | Small | Password input (no echo) |

#### Priority 2: Functional Programming

| Module | Status | Effort | Notes |
|--------|--------|--------|-------|
| `functools` | ✅ **Done** | Small | Native Zig - reduce, partial, cmp_to_key |
| `itertools` | ✅ **Done** | Medium | Native Zig - count, cycle, repeat, chain, islice, etc. |
| `contextlib` | ❌ Missing | Small | contextmanager, suppress |
| `copy` | ❌ Missing | Small | copy, deepcopy |

#### Priority 3: Type Safety

| Module | Status | Effort | Notes |
|--------|--------|--------|-------|
| `typing` | ❌ Missing | Small | Type hint stubs (no runtime) |
| `dataclasses` | ❌ Missing | Medium | @dataclass decorator |
| `enum` | ❌ Missing | Small | Enum, IntEnum |

#### Priority 4: Data Formats

| Module | Status | Effort | Notes |
|--------|--------|--------|-------|
| `toml` | ❌ Missing | Medium | TOML parsing (common in configs) |
| `yaml` | ❌ Missing | Medium | YAML parsing |
| `pickle` | ❌ Missing | Medium | Object serialization |

#### Priority 5: Compression & Archives

| Module | Status | Effort | Notes |
|--------|--------|--------|-------|
| `gzip` | ❌ Missing | Medium | Uses deflate (available) |
| `zipfile` | ❌ Missing | Medium | ZIP archives |
| `tarfile` | ❌ Missing | Medium | TAR archives |

#### Priority 6: Networking

| Module | Status | Effort | Notes |
|--------|--------|--------|-------|
| `urllib.parse` | ❌ Missing | Small | URL parsing |
| `http.client` | ❌ Missing | Medium | HTTP client |
| `http.server` | ❌ Missing | Medium | Simple HTTP server |

#### Priority 7: Security

| Module | Status | Effort | Notes |
|--------|--------|--------|-------|
| `uuid` | ❌ Missing | Small | UUID generation |
| `secrets` | ❌ Missing | Small | Secure random |
| `hmac` | ❌ Missing | Small | HMAC authentication |

#### Priority 8: Concurrency

| Module | Status | Effort | Notes |
|--------|--------|--------|-------|
| `threading` | ❌ Missing | Large | MicroPython has _thread |
| `multiprocessing` | ❌ Missing | Large | Not practical |
| `queue` | ❌ Missing | Small | Thread-safe queues |

#### Priority 9: Database

| Module | Status | Effort | Notes |
|--------|--------|--------|-------|
| `sqlite3` | ❌ Missing | Large | Would add ~200KB |

---

## Implementation Phases

### Phase 1: Native Module Foundation ✅ COMPLETE

- [x] `term` - Terminal control (14 functions)
- [x] `ansi` - ANSI colors (13 functions)
- [x] `args` - CLI argument parsing (14 functions)
- [x] `env` - Environment variables (18 functions)
- [x] `path` - Path manipulation (14 functions)
- [x] `ui` - UI rendering (40+ functions)
- [x] `json` - Fast JSON (19 functions)
- [x] `base64` - Base64 encoding/decoding
- [x] `datetime` - Date/time operations
- [x] `glob` / `fnmatch` - File pattern matching
- [x] `shutil` - File operations
- [x] `statistics` - Statistical functions
- [x] `tempfile` - Temporary files
- [x] `textwrap` - Text wrapping

### Phase 2: Python Library Integration ✅ COMPLETE

- [x] Rewrite terminal.py → native `term` module
- [x] Rewrite style.py → native `ansi` module
- [x] Rewrite input.py → native `term` for raw mode
- [x] Pure Python fallbacks when native unavailable

### Phase 3: Instant Startup ✅ COMPLETE

- [x] Zig loader for universal binaries
- [x] Content-hash caching (~6ms warm start)
- [x] Linux memfd support
- [x] Cross-platform builds

### Phase 4: CLI Stdlib Modules ✅ COMPLETE

Native Zig implementations for CLI-critical modules:

- [x] `subprocess` - run, call, check_output, Popen (1.5x faster shell)
- [x] `signal` - signal, alarm, kill, getpid (6.6x faster)
- [x] `csv` - RFC 4180 reader/writer (1.6x faster format)
- [x] `functools` - reduce, partial, cmp_to_key
- [x] `itertools` - count, cycle, repeat, chain, islice, takewhile, dropwhile, accumulate, starmap
- [x] `logging` - debug, info, warning, error, critical, Logger, basicConfig

### Phase 5: Remaining Stdlib (IN PROGRESS)

Pure Python or native implementations:

- [ ] `contextlib` - contextmanager, suppress
- [ ] `copy` - copy, deepcopy
- [ ] `typing` - Type hint stubs
- [ ] `enum` - Enum, IntEnum
- [ ] `configparser` - INI parsing
- [ ] `uuid` - UUID4 generation
- [ ] `urllib.parse` - URL parsing

### Phase 6: Native Extensions (PLANNED)

High-performance native modules:

- [ ] `gzip` - Compression (use MicroPython's deflate)
- [ ] `utf8` - UTF-8 display width (for CJK)
- [ ] `fetch` - HTTP client

### Phase 7: Developer Experience (PLANNED)

- [ ] `mcharm check` - Compatibility checker
- [ ] `mcharm init` - Project scaffolding
- [ ] `mcharm dev` - Watch mode with hot reload
- [ ] Tree-shaking for smaller binaries

---

## Quick Wins (Pure Python, <50 lines each)

These can be implemented immediately:

```python
# contextlib.contextmanager - ~20 lines
# copy.copy/deepcopy - ~30 lines
# typing stubs - ~20 lines
# enum.Enum - ~40 lines
# uuid.uuid4 - ~10 lines (using random)
```

Note: functools, itertools, csv, logging, subprocess, signal are now native Zig modules.

## Performance Targets

| Benchmark | Current | Target |
|-----------|---------|--------|
| Startup (cold) | ~10ms | <10ms ✅ |
| Startup (warm) | ~6ms | ~5ms |
| Binary size | ~945KB | ~700KB (with tree-shaking) |
| Memory | 1.8MB | <2MB ✅ |

## Compatibility Target

**Goal**: Run 80% of typical CLI scripts without modification

| Level | Description | Current | Target |
|-------|-------------|---------|--------|
| Bronze | Basic (args, env, files) | 95% ✅ | 95% |
| Silver | Data (json, csv, paths) | 90% ✅ | 85% |
| Gold | Full CLI (subprocess, signal, logging) | 80% ✅ | 60% |
| Platinum | Complex (sqlite, compress) | 10% | 40% |

---

## Next Steps

1. **Immediate**: Add pure Python `contextlib`, `copy`, `enum`
2. **Short-term**: Add `uuid`, `urllib.parse`, `configparser`
3. **Medium-term**: Tree-shaking for smaller binaries
4. **Long-term**: `mcharm check`, `mcharm dev`
