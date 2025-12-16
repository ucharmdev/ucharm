# microcharm/args.py - CLI argument parsing
"""
Simple, fast argument parsing inspired by Vercel's `arg` and Python's Typer.

Usage:
    from microcharm import args

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

Features:
- Type coercion: str, int, bool
- Defaults via tuple: (type, default)
- Aliases: '-n': '--name'
- Boolean flags: --verbose sets True, --no-verbose sets False
- Positional args collected in '_'
- =value syntax: --name=World
"""

import sys

# Try to use native args module (much faster)
try:
    import args as _args

    _HAS_NATIVE = True
except ImportError:
    _args = None
    _HAS_NATIVE = False


def raw():
    """Get raw sys.argv as a list."""
    if _HAS_NATIVE:
        return _args.raw()
    return sys.argv[:]


def count():
    """Return number of arguments."""
    if _HAS_NATIVE:
        return _args.count()
    return len(sys.argv)


def get(index, default=None):
    """Get argument by index with optional default."""
    if _HAS_NATIVE:
        return _args.get(index, default)

    argv = sys.argv
    # Handle negative indices
    if index < 0:
        index = len(argv) + index

    if 0 <= index < len(argv):
        return argv[index]
    return default


def has(flag):
    """Check if a flag exists (e.g., has('--verbose'))."""
    if _HAS_NATIVE:
        return _args.has(flag)
    return flag in sys.argv


def value(flag, default=None):
    """Get the value after a flag (e.g., value('--name') for --name World)."""
    if _HAS_NATIVE:
        return _args.value(flag, default)

    argv = sys.argv
    flag_len = len(flag)

    for i, arg in enumerate(argv):
        # Check for exact match with next arg as value
        if arg == flag and i + 1 < len(argv):
            return argv[i + 1]

        # Handle --flag=value syntax
        if arg.startswith(flag) and len(arg) > flag_len and arg[flag_len] == "=":
            return arg[flag_len + 1 :]

    return default


def int_value(flag, default=0):
    """Get integer value after a flag."""
    if _HAS_NATIVE:
        return _args.int_value(flag, default)

    val = value(flag)
    if val is None:
        return default

    try:
        return int(val)
    except ValueError:
        return default


def positional():
    """Get all positional arguments (non-flag arguments)."""
    if _HAS_NATIVE:
        return _args.positional()

    argv = sys.argv
    result = []
    after_dashdash = False
    skip_next = False

    # Start from index 1 to skip script name
    for i in range(1, len(argv)):
        if skip_next:
            skip_next = False
            continue

        arg = argv[i]

        # After --, everything is positional
        if after_dashdash:
            result.append(arg)
            continue

        # Check for --
        if arg == "--":
            after_dashdash = True
            continue

        # Skip flags and their values
        if arg.startswith("--"):
            # Check if it has = in it
            if "=" not in arg:
                # Might have a value after it - skip next if it's not a flag
                if i + 1 < len(argv):
                    next_arg = argv[i + 1]
                    if not next_arg.startswith("-"):
                        skip_next = True
            continue

        if (
            arg.startswith("-")
            and len(arg) > 1
            and not arg[1:].replace(".", "").replace("-", "", 1).isdigit()
        ):
            # Short flag might have value after
            if i + 1 < len(argv):
                next_arg = argv[i + 1]
                if not next_arg.startswith("-"):
                    skip_next = True
            continue

        # It's a positional argument
        result.append(arg)

    return result


def _is_flag(s):
    """Check if string is a flag (--foo or -f)."""
    if s.startswith("--"):
        return len(s) > 2
    if s.startswith("-") and len(s) > 1:
        # Distinguish -f from -1 (negative number)
        return not s[1:].replace(".", "").replace("-", "", 1).isdigit()
    return False


def _get_flag_name(flag):
    """Extract clean name from flag (--name -> name, -n -> n)."""
    if flag.startswith("--"):
        return flag[2:]
    if flag.startswith("-"):
        return flag[1:]
    return flag


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
    if _HAS_NATIVE:
        return _args.parse(spec)

    # Pure Python implementation
    argv = sys.argv
    result = {}
    positional_args = []

    # Build alias map (short -> long)
    aliases = {}
    for key, val in spec.items():
        if isinstance(val, str):
            aliases[key] = val

    # Parse arguments
    after_dashdash = False
    i = 1  # Skip script name

    while i < len(argv):
        arg = argv[i]

        # After --, everything is positional
        if after_dashdash:
            positional_args.append(arg)
            i += 1
            continue

        # Check for --
        if arg == "--":
            after_dashdash = True
            i += 1
            continue

        # Handle flags
        if _is_flag(arg):
            flag_key = arg
            value_str = None

            # Handle --flag=value syntax
            if "=" in arg:
                eq_pos = arg.index("=")
                flag_key = arg[:eq_pos]
                value_str = arg[eq_pos + 1 :]

            # Resolve alias
            if flag_key in aliases:
                flag_key = aliases[flag_key]

            # Look up in spec
            if flag_key not in spec:
                # Check for --no-flag (boolean negation)
                flag_name = _get_flag_name(flag_key)
                if flag_name.startswith("no-"):
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
                # Unknown flag - skip
                i += 1
                continue

            type_obj = spec[flag_key]
            clean_name = _get_flag_name(flag_key)

            # Handle tuple (type, default) format
            default_val = None
            if isinstance(type_obj, tuple):
                if len(type_obj) >= 2:
                    default_val = type_obj[1]
                type_obj = type_obj[0]

            # Check type and get value
            if type_obj is bool:
                # Boolean flag - presence means true
                result[clean_name] = True
            else:
                # Get value
                if value_str is not None:
                    val = value_str
                elif i + 1 < len(argv):
                    i += 1
                    val = argv[i]
                else:
                    i += 1
                    continue  # No value available

                # Convert type
                if type_obj is int:
                    try:
                        result[clean_name] = int(val)
                    except ValueError:
                        pass
                elif type_obj is str:
                    result[clean_name] = val
                else:
                    result[clean_name] = val
        else:
            # Positional argument
            positional_args.append(arg)

        i += 1

    # Apply defaults from spec
    for key, val in spec.items():
        # Skip aliases
        if isinstance(val, str):
            continue

        if not _is_flag(key):
            continue

        clean_name = _get_flag_name(key)

        # Check if already set
        if clean_name in result:
            continue

        # Apply default
        if isinstance(val, tuple):
            if len(val) >= 2:
                result[clean_name] = val[1]
            elif len(val) == 1 and val[0] is bool:
                result[clean_name] = False
        elif val is bool:
            result[clean_name] = False

    # Add positional args as '_'
    result["_"] = positional_args

    return result
