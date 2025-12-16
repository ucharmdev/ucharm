# microcharm/path.py - Path manipulation utilities
"""
Path manipulation utilities.
All operations use native Zig via libmicrocharm.
"""

from ._native import path as _path

# Re-export all path functions
basename = _path.basename
dirname = _path.dirname
extname = _path.extname
stem = _path.stem
join = _path.join
is_absolute = _path.is_absolute
is_relative = _path.is_relative
has_extension = _path.has_extension
has_ext = _path.has_ext
normalize = _path.normalize
component_count = _path.component_count
component = _path.component
relative = _path.relative


def split(p):
    """Split path into (dirname, basename) tuple."""
    return dirname(p), basename(p)


def splitext(p):
    """Split path into (stem, extension) tuple."""
    base = basename(p)
    ext = extname(p)
    if ext:
        return base[: -len(ext)], ext
    return base, ""
