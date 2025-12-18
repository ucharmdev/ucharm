"""
statistics - Native module
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

def mean(value: Any) -> float:
    ...

def fmean(value: Any) -> float:
    ...

def median(value: Any) -> float:
    ...

def median_low(value: Any) -> float:
    ...

def median_high(value: Any) -> float:
    ...

def mode(value: Any) -> most:
    """
    Works with any hashable type (numbers, strings, etc.)
    """
    ...

def variance(value: Any) -> float:
    ...

def pvariance(value: Any) -> float:
    ...

def stdev(value: Any) -> float:
    ...

def pstdev(value: Any) -> float:
    ...

def harmonic_mean(value: Any) -> float:
    ...

def geometric_mean(value: Any) -> float:
    ...

def quantiles() -> None:
    ...

def linear_regression() -> None:
    ...

def correlation() -> None:
    ...
