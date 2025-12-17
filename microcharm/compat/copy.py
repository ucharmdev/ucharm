# microcharm/compat/copy.py
"""
Pure Python implementation of copy for MicroPython.

Provides:
- copy: Shallow copy
- deepcopy: Deep copy
"""


class Error(Exception):
    """Copy error."""

    pass


error = Error


def copy(x):
    """
    Create a shallow copy of x.

    For compound objects like lists or dicts, this creates a new
    object but doesn't copy the elements - they're just references
    to the same objects as in the original.

    Example:
        a = [1, [2, 3]]
        b = copy(a)
        b[0] = 99       # Doesn't affect a
        b[1][0] = 99    # DOES affect a[1][0]
    """
    # Check for __copy__ method
    if hasattr(x, "__copy__"):
        return x.__copy__()

    # Handle common types
    t = type(x)

    # Immutable types - return as-is
    if t in (type(None), bool, int, float, str, bytes, tuple, frozenset):
        return x

    # Mutable types - create new instance
    if t is list:
        return list(x)

    if t is dict:
        return dict(x)

    if t is set:
        return set(x)

    if t is bytearray:
        return bytearray(x)

    # Try to use __class__ constructor
    try:
        if hasattr(x, "__dict__"):
            # Object with __dict__
            new = object.__new__(t)
            new.__dict__.update(x.__dict__)
            return new
    except:
        pass

    raise Error("cannot copy object of type " + str(t))


def deepcopy(x, memo=None):
    """
    Create a deep copy of x.

    For compound objects, this recursively copies all elements,
    so the copy is fully independent of the original.

    Example:
        a = [1, [2, 3]]
        b = deepcopy(a)
        b[1][0] = 99    # Doesn't affect a[1][0]

    Args:
        x: Object to copy
        memo: Dictionary to track already-copied objects (for cycles)
    """
    if memo is None:
        memo = {}

    # Check if already copied (handles circular references)
    d = id(x)
    if d in memo:
        return memo[d]

    # Check for __deepcopy__ method
    if hasattr(x, "__deepcopy__"):
        result = x.__deepcopy__(memo)
        memo[d] = result
        return result

    t = type(x)

    # Immutable types - return as-is (no need to copy)
    if t in (type(None), bool, int, float, str, bytes):
        return x

    # Tuple - deepcopy elements
    if t is tuple:
        result = tuple(deepcopy(item, memo) for item in x)
        memo[d] = result
        return result

    # Frozenset - deepcopy elements
    if t is frozenset:
        result = frozenset(deepcopy(item, memo) for item in x)
        memo[d] = result
        return result

    # List - deepcopy elements
    if t is list:
        result = []
        memo[d] = result  # Add to memo before recursing (for cycles)
        result.extend(deepcopy(item, memo) for item in x)
        return result

    # Dict - deepcopy keys and values
    if t is dict:
        result = {}
        memo[d] = result
        for k, v in x.items():
            result[deepcopy(k, memo)] = deepcopy(v, memo)
        return result

    # Set - deepcopy elements
    if t is set:
        result = set()
        memo[d] = result
        for item in x:
            result.add(deepcopy(item, memo))
        return result

    # Bytearray
    if t is bytearray:
        result = bytearray(x)
        memo[d] = result
        return result

    # General object with __dict__
    if hasattr(x, "__dict__"):
        result = object.__new__(t)
        memo[d] = result
        for k, v in x.__dict__.items():
            result.__dict__[k] = deepcopy(v, memo)
        return result

    # Fall back to shallow copy
    return copy(x)


def replace(obj, **changes):
    """
    Return a copy of obj with specified attributes replaced.

    This is useful for objects that support the replace protocol,
    like namedtuples or dataclasses.

    Example:
        from dataclasses import dataclass
        @dataclass
        class Point:
            x: int
            y: int

        p = Point(1, 2)
        q = replace(p, x=10)  # Point(10, 2)
    """
    # Check for _replace method (namedtuple style)
    if hasattr(obj, "_replace"):
        return obj._replace(**changes)

    # Check for __replace__ method (Python 3.13+)
    if hasattr(obj, "__replace__"):
        return obj.__replace__(**changes)

    # Try to use __class__ and __dict__
    try:
        new_dict = dict(obj.__dict__)
        new_dict.update(changes)
        result = object.__new__(type(obj))
        result.__dict__.update(new_dict)
        return result
    except AttributeError:
        raise TypeError("replace() requires an object with __dict__ or _replace method")
