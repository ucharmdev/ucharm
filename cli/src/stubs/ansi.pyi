"""
ansi - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def reset() -> str:
    ...

def fg(value: Any) -> str:
    """
    color can be: name ("red"), hex ("#ff5500"), or int (0-255)
    """
    ...

def bg(value: Any) -> str:
    ...

def rgb() -> None:
    ...

def bold() -> None:
    """
    Style Functions
    """
    ...

def dim() -> None:
    ...

def italic() -> None:
    ...

def underline() -> None:
    ...

def blink() -> None:
    ...

def reverse() -> None:
    ...

def hidden() -> None:
    ...

def strikethrough() -> None:
    ...
