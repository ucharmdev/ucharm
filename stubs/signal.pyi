"""
signal - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def signal() -> None:
    ...

def getsignal(value: Any) -> handler:
    ...

def check_pending(value: Any) -> bool:
    ...

def dispatch(value: Any) -> bool:
    ...

def dispatch_all() -> int:
    ...

def kill() -> None:
    ...

def raise_signal(value: Any) -> None:
    ...

def pause() -> None:
    ...

def alarm(value: Any) -> int:
    ...

def getpid() -> int:
    ...

def getppid() -> int:
    ...

def block(value: Any) -> None:
    ...

def unblock(value: Any) -> None:
    ...
