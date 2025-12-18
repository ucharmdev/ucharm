"""
charm - Native UI components module for ucharm
"""

from typing import Optional, Any, List, Callable, TypeVar, Iterable, Iterator

BORDER_ROUNDED: int
BORDER_SQUARE: int
BORDER_DOUBLE: int
BORDER_HEAVY: int
BORDER_NONE: int
ALIGN_LEFT: int
ALIGN_RIGHT: int
ALIGN_CENTER: int

def style(text: str, *, fg: Optional[str] = None, bg: Optional[str] = None, bold: bool = False, dim: bool = False, italic: bool = False, underline: bool = False, strikethrough: bool = False) -> str:
    """
    Apply ANSI styling to text and return the styled string.
    """
    ...

def box(content: str, *, title: Optional[str] = None, border: str = None, border_color: Optional[str] = None, padding: int = 0) -> None:
    ...

def rule(title: Optional[str] = None, char: Optional[str] = None, color: Optional[str] = None, width: int = 0) -> None:
    """
    Print a horizontal rule with optional centered title.
    """
    ...

def progress(current: int, total: int, *, label: Optional[str] = None, width: int = 0, color: Optional[str] = None) -> None:
    """
    Display an animated progress bar with percentage.
    """
    ...

def visible_len(value: Any) -> int:
    """
    Calculate visible length of text, ignoring ANSI escape sequences.
    """
    ...

def success(value: Any) -> None:
    """
    Print a success message with a green checkmark symbol.
    """
    ...

def error(value: Any) -> None:
    """
    Print an error message with a red cross symbol.
    """
    ...

def warning(value: Any) -> None:
    """
    Print a warning message with a yellow warning symbol.
    """
    ...

def info(value: Any) -> None:
    """
    Print an info message with a blue info symbol.
    """
    ...

def spinner_frame(value: Any) -> str:
    """
    Get a spinner animation frame by index (cycles through frames).
    """
    ...
