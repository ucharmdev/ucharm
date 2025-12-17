# ucharm/json.py - JSON parsing and stringification
"""
JSON parsing and manipulation utilities.
All operations use native Zig via libucharm.
"""

from ._native import json as _json

# Re-export all json functions
parse = _json.parse
is_valid = _json.is_valid
typeof = _json.typeof
get_string = _json.get_string
get_int = _json.get_int
get_float = _json.get_float
get_bool = _json.get_bool
is_null = _json.is_null
get = _json.get
has_key = _json.has_key
len = _json.len
get_index = _json.get_index
stringify = _json.stringify
pretty = _json.pretty
minify = _json.minify
path = _json.path


def loads(s):
    """
    Parse JSON string and return Python object.

    Unlike parse(), this returns actual Python values.
    """
    if not is_valid(s):
        raise ValueError("Invalid JSON")

    t = typeof(s)
    if t == "null":
        return None
    elif t == "bool":
        return get_bool(s)
    elif t == "number":
        # Try int first, fall back to float
        s_stripped = s.strip()
        if "." in s_stripped or "e" in s_stripped.lower():
            return get_float(s)
        return get_int(s)
    elif t == "string":
        return get_string(s)
    elif t == "array":
        result = []
        for i in range(len(s)):
            item = get_index(s, i)
            if item is not None:
                result.append(loads(item))
        return result
    elif t == "object":
        # For objects, we need to use Python's json as a fallback
        # since we don't have key iteration in the native module
        import json as py_json

        return py_json.loads(s)
    else:
        raise ValueError(f"Unknown JSON type: {t}")


def dumps(obj, indent=None):
    """
    Serialize Python object to JSON string.

    Args:
        obj: Python object to serialize
        indent: If set, pretty print with indentation
    """
    result = stringify(obj)
    if indent and result:
        return pretty(result)
    return result
