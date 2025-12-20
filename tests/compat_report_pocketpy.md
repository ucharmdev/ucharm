# μcharm Compatibility Report

Generated: 2025-12-20 14:56:34

## Summary

### Targeted Modules

- **Tests passing**: 1,245/1,604 (77.6%)
- **Modules at 100%**: 28/41
- **Modules partial**: 5/41

### CPython Stdlib Coverage

- **Modules targeted**: 41/159 (25.8%)
- **Not yet started**: 119 modules

## Targeted Module Status

| Module | Category | CPython | μcharm | Parity | Notes |
|--------|----------|---------|--------|--------|-------|
| glob | stdlib | 3/3 | 4/3 | 133% | ✅ Full |
| shutil | stdlib | 6/6 | 8/6 | 133% | ✅ Full |
| tempfile | stdlib | 9/9 | 12/9 | 133% | ✅ Full |
| argparse | stdlib | 26/26 | 26/26 | 100% | ✅ Full |
| base64 | stdlib | 18/18 | 18/18 | 100% | ✅ Full |
| csv | stdlib | 24/24 | 24/24 | 100% | ✅ Full |
| datetime | stdlib | 21/21 | 21/21 | 100% | ✅ Full |
| errno | stdlib | 38/38 | 38/38 | 100% | ✅ Full |
| fnmatch | stdlib | 55/55 | 55/55 | 100% | ✅ Full |
| hashlib | stdlib | 29/29 | 29/29 | 100% | ✅ Full |
| heapq | stdlib | 42/42 | 42/42 | 100% | ✅ Full |
| io | stdlib | 53/53 | 53/53 | 100% | ✅ Full |
| itertools | stdlib | 33/33 | 33/33 | 100% | ✅ Full |
| logging | stdlib | 39/39 | 39/39 | 100% | ✅ Full |
| math | stdlib | 82/82 | 82/82 | 100% | ✅ Full |
| operator | stdlib | 114/115 | 115/115 | 100% | ✅ Full |
| os | stdlib | 45/45 | 45/45 | 100% | ✅ Full |
| pathlib | stdlib | 40/40 | 40/40 | 100% | ✅ Full |
| random | stdlib | 46/46 | 46/46 | 100% | ✅ Full |
| re | stdlib | 79/79 | 79/79 | 100% | ✅ Full |
| signal | stdlib | 15/15 | 15/15 | 100% | ✅ Full |
| statistics | stdlib | 28/28 | 28/28 | 100% | ✅ Full |
| struct | stdlib | 68/68 | 68/68 | 100% | ✅ Full |
| subprocess | stdlib | 14/14 | 14/14 | 100% | ✅ Full |
| sys | stdlib | 58/58 | 58/58 | 100% | ✅ Full |
| textwrap | stdlib | 24/24 | 24/24 | 100% | ✅ Full |
| time | stdlib | 42/42 | 42/42 | 100% | ✅ Full |
| typing | stdlib | 43/43 | 43/43 | 100% | ✅ Full |
| json | stdlib | 70/70 | 65/70 | 93% | 6 skipped |
| functools | stdlib | 40/40 | 35/40 | 88% | 5 skipped |
| collections | stdlib | 49/49 | 42/49 | 86% | 11 skipped |
| configparser | stdlib | 26/26 | 1/26 | 4% | 1 skipped |
| unittest | stdlib | 40/40 | 1/40 | 2% | 1 skipped |
| array | stdlib | 69/69 | 0/69 | 0% | 1 failing |
| binascii | stdlib | 55/55 | 0/55 | 0% | 1 failing |
| bisect | stdlib | 44/44 | 0/44 | 0% | 1 failing |
| contextlib | stdlib | 14/14 | 0/14 | 0% | 1 failing |
| copy | stdlib | 39/39 | 0/39 | 0% | 1 failing |
| enum | stdlib | 21/21 | 0/21 | 0% | 1 failing |
| urllib_parse | stdlib | 24/24 | 0/24 | 0% | 1 failing |
| uuid | stdlib | 18/18 | 0/18 | 0% | 1 failing |

## Failed Tests

### array

- `error: PocketPyExecFailed
`

### binascii

- `error: PocketPyExecFailed
`

### bisect

- `error: PocketPyExecFailed
`

### contextlib

- `error: PocketPyExecFailed
`

### enum

- `error: PocketPyExecFailed
`

### urllib_parse

- `error: PocketPyExecFailed
`

### uuid

- `error: PocketPyExecFailed
`

### copy

- `error: PocketPyExecFailed
`


## Skipped Tests

These tests require features not available in pocketpy-ucharm:

### collections

- 11 tests skipped

### configparser

- 1 tests skipped

### json

- 6 tests skipped

### functools

- 5 tests skipped

### unittest

- 1 tests skipped


## Not Yet Started Modules

The following 119 CPython stdlib modules are not yet targeted:

### Text Processing

- `difflib` - Helpers for computing deltas
- `readline` - GNU readline interface
- `rlcompleter` - Completion function for readline
- `string` - Common string operations
- `stringprep` - Internet string preparation
- `unicodedata` - Unicode database

### Binary Data

- `codecs` - Codec registry and base classes

### Data Types

- `calendar` - Calendar-related functions
- `collections.abc` - Abstract base classes for containers
- `graphlib` - Topological sorting
- `pprint` - Pretty-print data structures
- `reprlib` - Alternate repr() implementation
- `types` - Dynamic type creation
- `weakref` - Weak references
- `zoneinfo` - IANA time zone support

### Numeric and Mathematical

- `cmath` - Math for complex numbers
- `decimal` - Decimal fixed point arithmetic
- `fractions` - Rational numbers
- `numbers` - Numeric abstract base classes

### File and Directory Access

- `filecmp` - File and directory comparisons
- `fileinput` - Iterate over lines from input
- `linecache` - Random access to text lines
- `os.path` - Common pathname manipulations
- `stat` - Interpreting stat() results

### Data Persistence

- `copyreg` - Register pickle support functions
- `dbm` - Interfaces to Unix databases
- `marshal` - Internal Python object serialization
- `pickle` - Python object serialization
- `shelve` - Python object persistence
- `sqlite3` - DB-API 2.0 interface for SQLite

### Data Compression

- `bz2` - Support for bzip2 compression
- `gzip` - Support for gzip files
- `lzma` - Compression using LZMA algorithm
- `tarfile` - Read and write tar archives
- `zipfile` - Work with ZIP archives
- `zlib` - Compression compatible with gzip

### File Formats

- `netrc` - netrc file processing
- `plistlib` - Generate and parse Apple plist files
- `tomllib` - Parse TOML files

### Cryptographic

- `hmac` - Keyed-hashing for message auth
- `secrets` - Generate secure random numbers

### OS Services

- `ctypes` - Foreign function library
- `curses` - Terminal handling for character-cell
- `curses.ascii` - ASCII character utilities
- `curses.panel` - Panel stack extension for curses
- `curses.textpad` - Text input widget for curses
- `getopt` - C-style parser for command line
- `getpass` - Portable password input
- `logging.config` - Logging configuration
- `logging.handlers` - Logging handlers
- `platform` - Access to platform's identifying data

### Concurrent Execution

- `concurrent.futures` - Launching parallel tasks
- `contextvars` - Context variables
- `multiprocessing` - Process-based parallelism
- `multiprocessing.shared_memory` - Shared memory
- `queue` - Synchronized queue class
- `sched` - Event scheduler
- `threading` - Thread-based parallelism

### Networking

- `asyncio` - Asynchronous I/O
- `mmap` - Memory-mapped file support
- `select` - Waiting for I/O completion
- `selectors` - High-level I/O multiplexing
- `socket` - Low-level networking interface
- `ssl` - TLS/SSL wrapper for sockets

### Internet Data Handling

- `email` - Email and MIME handling
- `mailbox` - Manipulate mailboxes
- `mimetypes` - Map filenames to MIME types
- `quopri` - Encode and decode MIME quoted-printable

### HTML/XML

- `html` - HyperText Markup Language support
- `html.entities` - HTML entity definitions
- `html.parser` - Simple HTML and XHTML parser
- `xml.dom` - Document Object Model API
- `xml.dom.minidom` - Minimal DOM implementation
- `xml.etree.ElementTree` - ElementTree XML API
- `xml.sax` - SAX2 parser support

### Internet Protocols

- `ftplib` - FTP protocol client
- `http` - HTTP modules
- `http.client` - HTTP protocol client
- `http.cookies` - HTTP cookie handling
- `http.server` - HTTP servers
- `imaplib` - IMAP4 protocol client
- `ipaddress` - IPv4/IPv6 manipulation
- `poplib` - POP3 protocol client
- `smtplib` - SMTP protocol client
- `socketserver` - Framework for network servers
- `urllib` - URL handling modules
- `urllib.parse` - Parse URLs into components
- `urllib.request` - URL opening library

### Development Tools

- `doctest` - Test interactive Python examples
- `pydoc` - Documentation generator
- `test` - Regression test package
- `unittest.mock` - Mock object library

### Debugging and Profiling

- `bdb` - Debugger framework
- `faulthandler` - Dump Python tracebacks
- `pdb` - Python debugger
- `timeit` - Measure execution time
- `trace` - Trace Python statement execution
- `tracemalloc` - Trace memory allocations

### Runtime Services

- `__future__` - Future statement definitions
- `__main__` - Top-level code environment
- `abc` - Abstract base classes
- `atexit` - Exit handlers
- `builtins` - Built-in objects
- `dataclasses` - Data class decorator
- `gc` - Garbage collector interface
- `inspect` - Inspect live objects
- `site` - Site-specific configuration hook
- `sysconfig` - Python's configuration info
- `traceback` - Print or retrieve a traceback
- `warnings` - Warning control

### Custom Python Interpreters

- `code` - Interpreter base classes
- `codeop` - Compile Python code

### Importing

- `importlib` - Import machinery
- `importlib.metadata` - Package metadata
- `importlib.resources` - Package resources
- `modulefinder` - Find modules used by a script
- `pkgutil` - Package extension utilities
- `runpy` - Locate and run Python modules
- `zipimport` - Import modules from ZIP archives


## Notes

- Tests are adapted from CPython's test suite
- Some tests require features not available in PocketPy (threading, gc introspection)
- μcharm-specific modules (ansi, charm, input, term, args) have custom tests
- Report generated by `ucharm test --compat`