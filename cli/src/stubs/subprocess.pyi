"""
subprocess - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def run() -> None:
    ...

def call(value: Any) -> int:
    ...

def check_call(value: Any) -> int:
    ...

def check_output() -> None:
    ...

def getoutput(value: Any) -> str:
    ...

def getstatusoutput(value: Any) -> None:
    ...

def getpid() -> int:
    ...

def getppid() -> int:
    ...
