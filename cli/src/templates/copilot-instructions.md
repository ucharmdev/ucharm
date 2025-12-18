# GitHub Copilot Instructions for ucharm

This project uses ucharm (MicroPython + native Zig modules).

## Key Facts

- MicroPython runtime, not CPython
- No pip packages with C extensions
- Native modules: charm, input, term, ansi, subprocess, etc.

## Preferred Patterns

```python
from ucharm import box, success, select, confirm
```

## Avoid

- requests/httpx (use subprocess + curl)
- numpy/pandas (pure Python alternatives)
- async/await
