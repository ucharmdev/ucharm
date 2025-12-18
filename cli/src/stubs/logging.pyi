"""
logging - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

NOTSET: int
DEBUG: int
INFO: int
WARNING: int
WARN: int
ERROR: int
CRITICAL: int
FATAL: int

def debug() -> None:
    ...

def info() -> None:
    ...

def warning() -> None:
    ...

def error() -> None:
    ...

def critical() -> None:
    ...

def setLevel(value: Any) -> None:
    ...

def basicConfig() -> None:
    ...

def debug() -> None:
    ...

def info() -> None:
    ...

def warning() -> None:
    ...

def warn() -> None:
    ...

def error() -> None:
    ...

def critical() -> None:
    ...

def fatal() -> None:
    ...

def log() -> None:
    ...

def setLevel(value: Any) -> None:
    ...

def getLevel() -> None:
    ...

def getLevelName(value: Any) -> None:
    ...

def disable() -> None:
    ...

def isEnabledFor(value: Any) -> None:
    ...

def getLogger() -> None:
    ...
