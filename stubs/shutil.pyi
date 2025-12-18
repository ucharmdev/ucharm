"""
shutil - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def copy() -> None:
    ...

def copy2() -> None:
    ...

def copyfile() -> None:
    ...

def copytree() -> None:
    ...

def move() -> None:
    ...

def rmtree(value: Any) -> None:
    ...

def makedirs(value: Any) -> None:
    ...

def exists(value: Any) -> bool:
    ...

def isfile(value: Any) -> bool:
    ...

def isdir(value: Any) -> bool:
    ...

def getsize(value: Any) -> int:
    ...
