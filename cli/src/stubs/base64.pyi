"""
base64 - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def b64encode(value: Any) -> bytes:
    ...

def b64decode(value: Any) -> bytes:
    ...

def urlsafe_b64encode(value: Any) -> bytes:
    ...

def urlsafe_b64decode(value: Any) -> bytes:
    ...

def encodebytes(value: Any) -> bytes:
    """
    For simplicity, this just calls b64encode without newlines
    """
    ...

def decodebytes(value: Any) -> bytes:
    ...
