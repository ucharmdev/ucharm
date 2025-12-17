# ucharm/env.py - Environment variable utilities
"""
Environment variable access and common checks.
All operations use native Zig via libucharm.
"""

from ._native import env as _env

# Re-export all env functions
get = _env.get
has = _env.has
get_or = _env.get_or
is_truthy = _env.is_truthy
is_falsy = _env.is_falsy
get_int = _env.get_int
is_ci = _env.is_ci
is_debug = _env.is_debug
no_color = _env.no_color
force_color = _env.force_color
get_term = _env.get_term
is_dumb_term = _env.is_dumb_term
home = _env.home
user = _env.user
shell = _env.shell
pwd = _env.pwd
path = _env.path
editor = _env.editor


def should_use_color():
    """
    Determine if color output should be used.

    Follows the NO_COLOR and FORCE_COLOR conventions:
    - If NO_COLOR is set, return False
    - If FORCE_COLOR is set, return True
    - If terminal is dumb, return False
    - Otherwise return True
    """
    if no_color():
        return False
    if force_color():
        return True
    if is_dumb_term():
        return False
    return True
