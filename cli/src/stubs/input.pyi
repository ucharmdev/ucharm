"""
input - Native interactive input module for ucharm
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def confirm(prompt: str, *, default: Optional[Any] = False) -> bool:
    ...

def select() -> None:
    ...

def multiselect() -> None:
    ...

def prompt() -> None:
    ...

def password(value: Any) -> str:
    ...
