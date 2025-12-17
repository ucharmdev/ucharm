# ucharm/compat/typing.py
"""
Stub implementation of typing for MicroPython.

This provides no-op versions of all typing constructs so that
code using type hints can run without modification.

Type hints have no runtime effect in Python, so we just need
to provide the names - they don't need to do anything.
"""


# Special typing primitives
class _SpecialForm:
    """Base for special typing forms."""

    def __init__(self, name):
        self._name = name

    def __repr__(self):
        return "typing." + self._name

    def __getitem__(self, params):
        return self

    def __call__(self, *args, **kwargs):
        # For things like cast()
        if args:
            return args[0]
        return None


# Basic type aliases - these are just identity for actual types
Any = _SpecialForm("Any")
NoReturn = _SpecialForm("NoReturn")
Never = _SpecialForm("Never")

# Generic aliases
Union = _SpecialForm("Union")
Optional = _SpecialForm("Optional")
List = _SpecialForm("List")
Dict = _SpecialForm("Dict")
Set = _SpecialForm("Set")
FrozenSet = _SpecialForm("FrozenSet")
Tuple = _SpecialForm("Tuple")
Type = _SpecialForm("Type")
Callable = _SpecialForm("Callable")
Sequence = _SpecialForm("Sequence")
Mapping = _SpecialForm("Mapping")
MutableMapping = _SpecialForm("MutableMapping")
MutableSequence = _SpecialForm("MutableSequence")
MutableSet = _SpecialForm("MutableSet")
Iterable = _SpecialForm("Iterable")
Iterator = _SpecialForm("Iterator")
Generator = _SpecialForm("Generator")
Coroutine = _SpecialForm("Coroutine")
AsyncGenerator = _SpecialForm("AsyncGenerator")
AsyncIterable = _SpecialForm("AsyncIterable")
AsyncIterator = _SpecialForm("AsyncIterator")
Awaitable = _SpecialForm("Awaitable")
ContextManager = _SpecialForm("ContextManager")
AsyncContextManager = _SpecialForm("AsyncContextManager")
Pattern = _SpecialForm("Pattern")
Match = _SpecialForm("Match")
IO = _SpecialForm("IO")
TextIO = _SpecialForm("TextIO")
BinaryIO = _SpecialForm("BinaryIO")

# Python 3.9+ style generics
Literal = _SpecialForm("Literal")
Final = _SpecialForm("Final")
ClassVar = _SpecialForm("ClassVar")
Annotated = _SpecialForm("Annotated")
TypeGuard = _SpecialForm("TypeGuard")
Concatenate = _SpecialForm("Concatenate")
ParamSpec = _SpecialForm("ParamSpec")
TypeVarTuple = _SpecialForm("TypeVarTuple")
Unpack = _SpecialForm("Unpack")
Self = _SpecialForm("Self")
LiteralString = _SpecialForm("LiteralString")
Required = _SpecialForm("Required")
NotRequired = _SpecialForm("NotRequired")


class TypeVar:
    """Type variable for generic types."""

    def __init__(
        self, name, *constraints, bound=None, covariant=False, contravariant=False
    ):
        self.__name__ = name
        self.__constraints__ = constraints
        self.__bound__ = bound
        self.__covariant__ = covariant
        self.__contravariant__ = contravariant

    def __repr__(self):
        return "~" + self.__name__


class Generic:
    """Base class for generic types."""

    def __class_getitem__(cls, params):
        return cls


class Protocol:
    """Base class for protocol classes."""

    pass


class NamedTuple:
    """Typed version of namedtuple."""

    def __init_subclass__(cls, **kwargs):
        pass


class TypedDict(dict):
    """Dictionary with a fixed set of keys and value types."""

    def __init_subclass__(cls, total=True, **kwargs):
        pass


# Functions
def cast(typ, val):
    """Cast a value to a type (no-op at runtime)."""
    return val


def overload(func):
    """Decorator for overloaded functions (no-op at runtime)."""
    return func


def final(func):
    """Decorator to indicate a final method/class (no-op at runtime)."""
    return func


def no_type_check(func):
    """Decorator to indicate no type checking (no-op at runtime)."""
    return func


def no_type_check_decorator(decorator):
    """Decorator to disable type checking for a decorator."""
    return decorator


def runtime_checkable(cls):
    """Mark a protocol as runtime checkable."""
    return cls


def get_type_hints(obj, globalns=None, localns=None, include_extras=False):
    """Return type hints for an object."""
    hints = getattr(obj, "__annotations__", None)
    return hints if hints else {}


def get_origin(tp):
    """Get the unparameterized version of a type."""
    return getattr(tp, "__origin__", None)


def get_args(tp):
    """Get type arguments of a parameterized type."""
    return getattr(tp, "__args__", ())


def is_typeddict(tp):
    """Check if a type is a TypedDict."""
    return isinstance(tp, type) and issubclass(tp, TypedDict)


# Type aliases that are just the real types
AnyStr = TypeVar("AnyStr", str, bytes)
Text = str

# Collections
Counter = dict
Deque = list
DefaultDict = dict
OrderedDict = dict
ChainMap = dict

# For typing.TYPE_CHECKING
TYPE_CHECKING = False


# NewType creates a distinct type for type checkers
def NewType(name, tp):
    """Create a distinct type for type checking purposes."""

    def new_type(x):
        return x

    new_type.__name__ = name
    new_type.__supertype__ = tp
    return new_type


# reveal_type is used for debugging type inference
def reveal_type(obj):
    """Reveal the inferred type of an expression (for debugging)."""
    return obj


# assert_type is used for type assertions
def assert_type(val, typ):
    """Assert that a value has the expected type."""
    return val


# assert_never is used for exhaustiveness checking
def assert_never(arg):
    """Assert that this code is never reached."""
    raise AssertionError("Expected code to be unreachable")


# dataclass_transform decorator (Python 3.11+)
def dataclass_transform(**kwargs):
    """Decorator for dataclass-like decorators."""

    def decorator(cls_or_fn):
        return cls_or_fn

    return decorator
