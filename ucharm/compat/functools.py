# ucharm/compat/functools.py
"""
Pure Python implementation of functools for MicroPython.

Provides:
- partial: Partial function application
- reduce: Reduce iterable to single value
- wraps: Decorator to preserve function metadata
- lru_cache: Simple LRU cache (limited implementation)
- cache: Unbounded cache (alias for lru_cache(maxsize=None))
- update_wrapper: Update wrapper function to look like wrapped
- WRAPPER_ASSIGNMENTS, WRAPPER_UPDATES: Constants for wraps
"""

# Constants used by update_wrapper
WRAPPER_ASSIGNMENTS = (
    "__module__",
    "__name__",
    "__qualname__",
    "__doc__",
    "__annotations__",
)
WRAPPER_UPDATES = ("__dict__",)


class partial:
    """
    Partial function application.

    partial(func, *args, **kwargs) returns a callable that, when called,
    will call func with the stored args/kwargs plus any new ones.

    Example:
        def add(a, b): return a + b
        add5 = partial(add, 5)
        add5(3)  # Returns 8
    """

    def __init__(self, func, *args, **kwargs):
        if not callable(func):
            raise TypeError("the first argument must be callable")
        self.func = func
        self.args = args
        self.keywords = kwargs

    def __call__(self, *args, **kwargs):
        # Merge stored kwargs with new kwargs (new ones win)
        new_kwargs = dict(self.keywords)
        new_kwargs.update(kwargs)
        # Prepend stored args to new args
        return self.func(*(self.args + args), **new_kwargs)

    def __repr__(self):
        args_repr = ", ".join(repr(a) for a in self.args)
        kwargs_repr = ", ".join(k + "=" + repr(v) for k, v in self.keywords.items())
        all_args = ", ".join(filter(None, [args_repr, kwargs_repr]))
        func_name = getattr(self.func, "__name__", repr(self.func))
        return "functools.partial(" + func_name + ", " + all_args + ")"


def reduce(function, iterable, initializer=None):
    """
    Apply function of two arguments cumulatively to items of iterable.

    reduce(f, [a, b, c, d]) = f(f(f(a, b), c), d)

    If initializer is provided, it's placed before the items of iterable.

    Example:
        reduce(lambda x, y: x + y, [1, 2, 3, 4])  # Returns 10
        reduce(lambda x, y: x * y, [1, 2, 3, 4], 10)  # Returns 240
    """
    it = iter(iterable)

    if initializer is None:
        try:
            value = next(it)
        except StopIteration:
            raise TypeError("reduce() of empty sequence with no initial value")
    else:
        value = initializer

    for element in it:
        value = function(value, element)

    return value


def update_wrapper(
    wrapper, wrapped, assigned=WRAPPER_ASSIGNMENTS, updated=WRAPPER_UPDATES
):
    """
    Update a wrapper function to look like the wrapped function.

    Copies attributes from wrapped to wrapper.
    Note: MicroPython doesn't support setting __name__ on functions,
    so some attributes may not be copied.
    """
    for attr in assigned:
        try:
            value = getattr(wrapped, attr)
            try:
                setattr(wrapper, attr, value)
            except (AttributeError, TypeError):
                # MicroPython doesn't allow setting some attributes on functions
                pass
        except AttributeError:
            pass

    for attr in updated:
        try:
            getattr(wrapper, attr).update(getattr(wrapped, attr, {}))
        except AttributeError:
            pass

    # Set reference to original function
    try:
        wrapper.__wrapped__ = wrapped
    except (AttributeError, TypeError):
        pass

    return wrapper


def wraps(wrapped, assigned=WRAPPER_ASSIGNMENTS, updated=WRAPPER_UPDATES):
    """
    Decorator factory to apply update_wrapper to a wrapper function.

    Example:
        @wraps(original_func)
        def wrapper(*args, **kwargs):
            return original_func(*args, **kwargs)
    """

    def decorator(wrapper):
        return update_wrapper(wrapper, wrapped, assigned, updated)

    return decorator


def lru_cache(maxsize=128, typed=False):
    """
    Least Recently Used cache decorator.

    This is a simplified implementation that:
    - Caches based on all positional and keyword arguments
    - Uses a dict (no LRU eviction in this simple version if maxsize is small)
    - typed parameter is accepted but ignored (always typed)

    Example:
        @lru_cache(maxsize=100)
        def fibonacci(n):
            if n < 2:
                return n
            return fibonacci(n-1) + fibonacci(n-2)
    """

    def decorator(func):
        cache = {}
        hits = 0
        misses = 0

        def make_key(args, kwargs):
            """Create a hashable cache key from arguments."""
            key = args
            if kwargs:
                # Sort kwargs for consistent key
                sorted_items = tuple(sorted(kwargs.items()))
                key = key + (sorted_items,)
            return key

        def wrapper(*args, **kwargs):
            nonlocal hits, misses

            key = make_key(args, kwargs)

            if key in cache:
                hits += 1
                return cache[key]

            misses += 1
            result = func(*args, **kwargs)

            # Simple size limit - just clear if too big
            # (Real LRU would evict oldest, but this is simpler)
            if maxsize is not None and len(cache) >= maxsize:
                cache.clear()

            cache[key] = result
            return result

        def cache_info():
            """Return cache statistics."""
            return {
                "hits": hits,
                "misses": misses,
                "maxsize": maxsize,
                "currsize": len(cache),
            }

        def cache_clear():
            """Clear the cache."""
            nonlocal hits, misses
            cache.clear()
            hits = 0
            misses = 0

        wrapper.cache_info = cache_info
        wrapper.cache_clear = cache_clear
        wrapper.__wrapped__ = func

        # Copy function metadata
        try:
            wrapper.__name__ = func.__name__
            wrapper.__doc__ = func.__doc__
        except AttributeError:
            pass

        return wrapper

    # Handle @lru_cache without parentheses
    if callable(maxsize):
        func = maxsize
        maxsize = 128
        return decorator(func)

    return decorator


def cache(func):
    """
    Simple unbounded cache decorator.

    Equivalent to lru_cache(maxsize=None).

    Example:
        @cache
        def expensive_function(x):
            return x ** 2
    """
    return lru_cache(maxsize=None)(func)


def cmp_to_key(mycmp):
    """
    Convert a cmp= function into a key= function.

    Used for sorting functions that take key= argument.
    """

    class K:
        __slots__ = ["obj"]

        def __init__(self, obj):
            self.obj = obj

        def __lt__(self, other):
            return mycmp(self.obj, other.obj) < 0

        def __gt__(self, other):
            return mycmp(self.obj, other.obj) > 0

        def __eq__(self, other):
            return mycmp(self.obj, other.obj) == 0

        def __le__(self, other):
            return mycmp(self.obj, other.obj) <= 0

        def __ge__(self, other):
            return mycmp(self.obj, other.obj) >= 0

        def __hash__(self):
            raise TypeError("hash not implemented")

    return K


def total_ordering(cls):
    """
    Class decorator that fills in missing ordering methods.

    Given a class defining __eq__ and one of __lt__, __le__, __gt__, or __ge__,
    this decorator supplies the rest.
    """
    roots = {"__lt__", "__le__", "__gt__", "__ge__"}
    defined = roots & set(dir(cls))

    if not defined:
        raise ValueError("must define at least one ordering operation")

    # Define all methods in terms of __lt__ and __eq__
    def __lt__(self, other):
        if hasattr(other, "__class__") and other.__class__ is self.__class__:
            return not self.__eq__(other) and not self.__gt__(other)
        return NotImplemented

    def __le__(self, other):
        if hasattr(other, "__class__") and other.__class__ is self.__class__:
            return self.__eq__(other) or self.__lt__(other)
        return NotImplemented

    def __gt__(self, other):
        if hasattr(other, "__class__") and other.__class__ is self.__class__:
            return not self.__eq__(other) and not self.__lt__(other)
        return NotImplemented

    def __ge__(self, other):
        if hasattr(other, "__class__") and other.__class__ is self.__class__:
            return self.__eq__(other) or self.__gt__(other)
        return NotImplemented

    # Fill in missing methods
    if "__lt__" not in defined:
        cls.__lt__ = __lt__
    if "__le__" not in defined:
        cls.__le__ = __le__
    if "__gt__" not in defined:
        cls.__gt__ = __gt__
    if "__ge__" not in defined:
        cls.__ge__ = __ge__

    return cls
