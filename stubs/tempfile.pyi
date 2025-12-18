"""
tempfile - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def gettempdir() -> str:
    ...

def mktemp() -> None:
    ...

def mkstemp() -> None:
    ...

def mkdtemp() -> None:
    ...

def unlink(value: Any) -> None:
    ...

def rmdir(value: Any) -> None:
    ...

def rmtree(value: Any) -> None:
    ...
