"""
csv - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

QUOTE_MINIMAL: int
QUOTE_ALL: int
QUOTE_NONNUMERIC: int
QUOTE_NONE: int

def writerow() -> None:
    ...

def writerows() -> None:
    ...

def parse() -> None:
    ...

def format() -> None:
    ...

def reader() -> None:
    ...

def writer() -> None:
    ...

def get_dialect() -> dict:
    ...
