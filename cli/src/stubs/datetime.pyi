"""
datetime - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def now() -> dict:
    ...

def utcnow() -> dict:
    ...

def fromtimestamp(value: Any) -> dict:
    ...

def timestamp() -> None:
    ...

def isoformat() -> None:
    ...

def date_isoformat() -> None:
    ...

def weekday() -> None:
    ...

def isoweekday() -> None:
    ...

def toordinal() -> None:
    ...

def is_valid() -> None:
    ...

def is_leap_year(value: Any) -> bool:
    ...

def days_in_month() -> None:
    ...

def add_days() -> None:
    ...

def timedelta() -> None:
    ...

def timedelta_total_seconds() -> None:
    ...
