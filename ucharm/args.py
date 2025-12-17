# ucharm/args.py - CLI argument parsing
"""
Simple, fast argument parsing inspired by Vercel's `arg` and Python's Typer.
Uses native Zig helpers via libucharm where possible.

Usage:
    from ucharm import args

    opts = args.parse({
        '--name': str,           # required string
        '--count': (int, 1),     # int with default
        '--verbose': bool,       # boolean flag
        '-n': '--name',          # alias
        '-v': '--verbose',
    })

    print(opts['name'])       # 'World'
    print(opts['count'])      # 1
    print(opts['verbose'])    # True or False
    print(opts['_'])          # positional args list
"""

import sys

# Try to use native args module (MicroPython with native modules)
try:
    import args as _native_args

    _HAS_NATIVE_MODULE = True
except ImportError:
    _native_args = None
    _HAS_NATIVE_MODULE = False

# Use native shared library helpers for CPython
if not _HAS_NATIVE_MODULE:
    from ._native import _b, _load_library

    _lib = None

    def _get_lib():
        global _lib
        if _lib is None:
            _lib = _load_library()
        return _lib


def _is_long_flag(s):
    """Check if string is a long flag (--foo)."""
    if _HAS_NATIVE_MODULE:
        return _native_args.is_long_flag(s)
    return _get_lib().args_is_long_flag(_b(s))


def _is_short_flag(s):
    """Check if string is a short flag (-f) but not a negative number."""
    if _HAS_NATIVE_MODULE:
        return _native_args.is_short_flag(s)
    lib = _get_lib()
    return lib.args_is_short_flag(_b(s)) and not lib.args_is_negative_number(_b(s))


def _is_flag(s):
    """Check if string is any flag."""
    return _is_long_flag(s) or _is_short_flag(s)


def _get_flag_name(flag):
    """Extract clean name from flag (--name -> name, -n -> n)."""
    if _HAS_NATIVE_MODULE:
        return _native_args.get_flag_name(flag)
    return _get_lib().args_get_flag_name(_b(flag)).decode("utf-8")


def _is_negated_flag(name):
    """Check if flag name starts with 'no-'."""
    if _HAS_NATIVE_MODULE:
        return _native_args.is_negated_flag(name)
    return _get_lib().args_is_negated_flag(_b(name))


def _parse_int(s):
    """Parse integer from string."""
    if _HAS_NATIVE_MODULE:
        return _native_args.parse_int(s)
    return _get_lib().args_parse_int(_b(s))


def raw():
    """Get raw sys.argv as a list."""
    if _HAS_NATIVE_MODULE:
        return _native_args.raw()
    return sys.argv[:]


def count():
    """Return number of arguments."""
    if _HAS_NATIVE_MODULE:
        return _native_args.count()
    return len(sys.argv)


def get(index, default=None):
    """Get argument by index with optional default."""
    if _HAS_NATIVE_MODULE:
        return _native_args.get(index, default)
    argv = sys.argv
    if index < 0:
        index = len(argv) + index
    if 0 <= index < len(argv):
        return argv[index]
    return default


def has(flag):
    """Check if a flag exists (e.g., has('--verbose'))."""
    if _HAS_NATIVE_MODULE:
        return _native_args.has(flag)
    return flag in sys.argv


def value(flag, default=None):
    """Get the value after a flag (e.g., value('--name') for --name World)."""
    if _HAS_NATIVE_MODULE:
        return _native_args.value(flag, default)

    argv = sys.argv
    flag_len = len(flag)

    for i, arg in enumerate(argv):
        if arg == flag and i + 1 < len(argv):
            return argv[i + 1]
        if arg.startswith(flag) and len(arg) > flag_len and arg[flag_len] == "=":
            return arg[flag_len + 1 :]
    return default


def int_value(flag, default=0):
    """Get integer value after a flag."""
    if _HAS_NATIVE_MODULE:
        return _native_args.int_value(flag, default)

    val = value(flag)
    if val is None:
        return default
    try:
        return _parse_int(val)
    except:
        return default


def positional():
    """Get all positional arguments (non-flag arguments)."""
    if _HAS_NATIVE_MODULE:
        return _native_args.positional()

    argv = sys.argv
    result = []
    after_dashdash = False
    skip_next = False

    for i in range(1, len(argv)):
        if skip_next:
            skip_next = False
            continue

        arg = argv[i]

        if after_dashdash:
            result.append(arg)
            continue

        if arg == "--":
            after_dashdash = True
            continue

        if _is_long_flag(arg):
            if "=" not in arg and i + 1 < len(argv) and not _is_flag(argv[i + 1]):
                skip_next = True
            continue

        if _is_short_flag(arg):
            if i + 1 < len(argv) and not _is_flag(argv[i + 1]):
                skip_next = True
            continue

        result.append(arg)

    return result


def parse(spec):
    """
    Parse arguments according to a specification dict.

    spec format:
        {
            '--name': str,           # required string
            '--count': (int, 1),     # int with default of 1
            '--verbose': bool,       # boolean flag (default False)
            '-n': '--name',          # alias
        }

    Returns dict with clean names (no dashes):
        {'name': 'World', 'count': 5, 'verbose': True, '_': ['file1', 'file2']}
    """
    if _HAS_NATIVE_MODULE:
        return _native_args.parse(spec)

    argv = sys.argv
    result = {}
    positional_args = []

    # Build alias map
    aliases = {k: v for k, v in spec.items() if isinstance(v, str)}

    after_dashdash = False
    i = 1

    while i < len(argv):
        arg = argv[i]

        if after_dashdash:
            positional_args.append(arg)
            i += 1
            continue

        if arg == "--":
            after_dashdash = True
            i += 1
            continue

        if _is_flag(arg):
            flag_key = arg
            value_str = None

            if "=" in arg:
                eq_pos = arg.index("=")
                flag_key = arg[:eq_pos]
                value_str = arg[eq_pos + 1 :]

            if flag_key in aliases:
                flag_key = aliases[flag_key]

            if flag_key not in spec:
                # Check for --no-flag
                flag_name = _get_flag_name(flag_key)
                if _is_negated_flag(flag_name):
                    base = flag_name[3:]
                    base_key = "--" + base
                    if base_key in spec:
                        spec_val = spec[base_key]
                        if spec_val is bool or (
                            isinstance(spec_val, tuple) and spec_val[0] is bool
                        ):
                            result[base] = False
                            i += 1
                            continue
                i += 1
                continue

            type_obj = spec[flag_key]
            clean_name = _get_flag_name(flag_key)

            default_val = None
            if isinstance(type_obj, tuple):
                if len(type_obj) >= 2:
                    default_val = type_obj[1]
                type_obj = type_obj[0]

            if type_obj is bool:
                result[clean_name] = True
            else:
                if value_str is not None:
                    val = value_str
                elif i + 1 < len(argv):
                    i += 1
                    val = argv[i]
                else:
                    i += 1
                    continue

                if type_obj is int:
                    try:
                        result[clean_name] = _parse_int(val)
                    except:
                        pass
                else:
                    result[clean_name] = val
        else:
            positional_args.append(arg)

        i += 1

    # Apply defaults
    for key, val in spec.items():
        if isinstance(val, str):
            continue
        if not _is_flag(key):
            continue

        clean_name = _get_flag_name(key)
        if clean_name in result:
            continue

        if isinstance(val, tuple):
            if len(val) >= 2:
                result[clean_name] = val[1]
            elif len(val) == 1 and val[0] is bool:
                result[clean_name] = False
        elif val is bool:
            result[clean_name] = False

    result["_"] = positional_args
    return result
