"""
term - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def size() -> None:
    ...

def raw_mode(value: Any) -> None:
    ...

def read_key() -> str:
    ...

def cursor_pos() -> None:
    ...

def cursor_up() -> None:
    ...

def cursor_down() -> None:
    ...

def cursor_left() -> None:
    ...

def cursor_right() -> None:
    ...

def clear() -> None:
    ...

def clear_line() -> None:
    ...

def hide_cursor() -> None:
    ...

def show_cursor() -> None:
    ...

def is_tty() -> bool:
    ...

def write(value: Any) -> None:
    ...
