# ucharm Project

This project uses **ucharm** - a CLI toolkit for building beautiful command-line applications with PocketPy.

## Critical Context

- **Runtime**: PocketPy with native Zig modules (NOT CPython)
- **No pip packages**: Cannot use packages with C extensions (no requests, numpy, pandas)
- **Output**: Standalone binaries (~900KB)
- **24 runtime modules**: ansi, args, base64, charm, copy, csv, datetime, fnmatch, functools, glob, heapq, input, itertools, logging, operator, random, shutil, signal, statistics, subprocess, tempfile, term, textwrap, typing

## Import Pattern

```python
# Use 'from ucharm import' for TUI components
from ucharm import box, success, error, select, confirm, prompt

# Or import native modules directly
import charm
import input
```

## Available TUI Functions

- `box(content, title=None, border="rounded", border_color=None)` - Draw a box
- `success(msg)`, `error(msg)`, `warning(msg)`, `info(msg)` - Status messages
- `select(prompt, choices)` -> str - Interactive selection
- `multiselect(prompt, choices)` -> list - Multiple selection
- `confirm(prompt, default=True)` -> bool - Yes/no prompt
- `prompt(message, default=None)` -> str - Text input
- `password(message)` -> str - Hidden input

## Running & Building

```bash
ucharm run myapp.py           # Run script
ucharm build myapp.py -o app  # Build standalone binary
```

## Do NOT Suggest

- requests, httpx, aiohttp (use subprocess + curl)
- numpy, pandas, scipy (pure Python alternatives only)
- async/await patterns (limited PocketPy support)
- Runtime type checking (use stubs for IDE only)
