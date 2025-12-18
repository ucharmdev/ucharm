"""
args - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def raw() -> list:
    ...

def get() -> None:
    ...

def count() -> int:
    ...

def has(value: Any) -> bool:
    ...

def value() -> None:
    ...

def int_value() -> None:
    ...

def positional() -> list:
    ...

def parse(value: Any) -> dict:
    ...
