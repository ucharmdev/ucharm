# GitHub Copilot Instructions for ucharm

This project uses ucharm (PocketPy + native Zig modules).

## Key Facts

- PocketPy runtime, not CPython
- No pip packages with C extensions
- 50+ native modules: charm, input, term, ansi, fetch, template, sqlite3, json, re, etc.

## Preferred Patterns

```python
from ucharm import box, success, select, confirm

# HTTP requests
import fetch
resp = fetch.get("https://api.example.com/data")
print(resp["body"].decode())

# Templating
import template
html = template.render("Hello {{name}}!", {"name": "World"})
```

## Avoid

- requests/httpx (use `fetch` module instead)
- numpy/pandas (pure Python alternatives)
- async/await
