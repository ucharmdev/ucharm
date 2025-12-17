# ucharm/compat/__init__.py
"""
Compatibility layer for MicroPython.

This module provides import hooks that redirect standard library imports
to our pure Python implementations. This allows packages written for
CPython to work transparently on MicroPython.

Usage:
    # At the start of your app, enable the compat layer:
    import ucharm.compat
    ucharm.compat.install()

    # Now stdlib imports will use our implementations:
    from pathlib import Path  # Uses ucharm.compat.pathlib
    from functools import partial  # Uses ucharm.compat.functools
"""

import sys

# Registry of stdlib modules we provide replacements for
# Maps stdlib name -> our module name
_REDIRECTS = {
    "functools": "ucharm.compat.functools",
    "pathlib": "ucharm.compat.pathlib",
    "datetime": "ucharm.compat.datetime",
    "textwrap": "ucharm.compat.textwrap",
    "fnmatch": "ucharm.compat.fnmatch",
    "glob": "ucharm.compat.glob",
    "shutil": "ucharm.compat.shutil",
    "tempfile": "ucharm.compat.tempfile",
    "csv": "ucharm.compat.csv",
    "configparser": "ucharm.compat.configparser",
    "contextlib": "ucharm.compat.contextlib",
    "copy": "ucharm.compat.copy",
    "itertools": "ucharm.compat.itertools",
    "operator": "ucharm.compat.operator",
    "typing": "ucharm.compat.typing",
    "dataclasses": "ucharm.compat.dataclasses",
    "enum": "ucharm.compat.enum",
    "base64": "ucharm.compat.base64",
    "statistics": "ucharm.compat.statistics",
    "string": "ucharm.compat.string",
    "urllib": "ucharm.compat.urllib",
    "urllib.parse": "ucharm.compat.urllib_parse",
}

# Track which modules we've already loaded
_loaded_modules = {}

# Track if hooks are installed
_installed = False


# Modules that have native Zig implementations
# When these native modules are available, we use them directly
_NATIVE_MODULES = {
    "base64",
    "glob",
    "fnmatch",
    "tempfile",
    "shutil",
    "datetime",
}


class MicroCharmFinder:
    """
    Import hook that redirects stdlib imports to our implementations.

    This implements PEP 302 finder protocol for MicroPython compatibility.
    When Python tries to import a module we have a replacement for,
    we intercept and return our loader.
    """

    def find_module(self, fullname, path=None):
        """
        Called by Python's import machinery to find a module.

        Returns self (as loader) if we handle this module, None otherwise.
        """
        # Check if this is a module we redirect
        if fullname in _REDIRECTS:
            # First check if there's a native module available
            if fullname in _NATIVE_MODULES and self._native_exists(fullname):
                return None  # Let the native module handle it
            # Only redirect if the real module doesn't exist
            # (allows CPython to use its own stdlib)
            if not self._stdlib_exists(fullname):
                return self
        return None

    def load_module(self, fullname):
        """
        Called to actually load the module after find_module returns self.
        """
        # Return cached version if already loaded
        if fullname in sys.modules:
            return sys.modules[fullname]

        if fullname in _loaded_modules:
            return _loaded_modules[fullname]

        # Get our replacement module name
        compat_name = _REDIRECTS.get(fullname)
        if not compat_name:
            raise ImportError("No compat module for: " + fullname)

        # Import our implementation
        try:
            # Handle dotted names like urllib.parse
            parts = compat_name.split(".")
            mod = __import__(compat_name)
            for part in parts[1:]:
                mod = getattr(mod, part)
        except ImportError as e:
            raise ImportError(
                "ucharm.compat." + fullname + " not implemented yet: " + str(e)
            )

        # Register under the stdlib name so future imports find it
        sys.modules[fullname] = mod
        _loaded_modules[fullname] = mod

        return mod

    def _stdlib_exists(self, name):
        """Check if the real stdlib module exists (for CPython)."""
        # If already in sys.modules as a real module, don't override
        if name in sys.modules:
            mod = sys.modules[name]
            # Check if it's one of ours or the real thing
            mod_file = getattr(mod, "__file__", "") or ""
            if "ucharm/compat" not in mod_file:
                return True

        # Try to detect if we're on CPython with real stdlib
        # MicroPython typically doesn't have these
        try:
            # This is a heuristic - check for a CPython-only feature
            if hasattr(sys, "implementation"):
                impl = sys.implementation.name
                if impl == "cpython":
                    # On CPython, let real stdlib handle it
                    return True
        except:
            pass

        return False

    def _native_exists(self, name):
        """Check if a native Zig module is available."""
        # Native modules are built into micropython-ucharm
        # They're registered as built-in modules before Python runs
        try:
            # Temporarily remove this finder to avoid recursion
            if self in sys.meta_path:
                sys.meta_path.remove(self)
            try:
                mod = __import__(name)
                # Check if it's a native module (no __file__ attribute)
                # Native C modules typically don't have __file__
                if not hasattr(mod, "__file__") or mod.__file__ is None:
                    return True
                # Also check if it's in sys.modules but not from compat
                mod_file = getattr(mod, "__file__", "") or ""
                if "ucharm/compat" not in mod_file:
                    return True
            finally:
                # Re-add the finder
                if self not in sys.meta_path:
                    sys.meta_path.insert(0, self)
        except ImportError:
            pass
        return False


# Singleton finder instance
_finder = MicroCharmFinder()


def install():
    """
    Install the import hooks.

    Call this early in your application to enable stdlib compatibility.
    Safe to call multiple times - only installs once.

    Note: Import hooks only work on CPython. On MicroPython, you need
    to import directly from ucharm.compat.* or compat.* modules.
    """
    global _installed

    if _installed:
        return

    # Check if sys.meta_path exists (CPython has it, MicroPython doesn't)
    if not hasattr(sys, "meta_path"):
        # MicroPython - import hooks not supported
        # Users should import directly: from compat.functools import partial
        _installed = True
        return

    # Insert our finder at the beginning of sys.meta_path
    # so we get first chance at imports
    if _finder not in sys.meta_path:
        sys.meta_path.insert(0, _finder)

    _installed = True


def uninstall():
    """
    Remove the import hooks.

    Mainly useful for testing.
    """
    global _installed

    if not hasattr(sys, "meta_path"):
        _installed = False
        return

    if _finder in sys.meta_path:
        sys.meta_path.remove(_finder)

    _installed = False


def is_installed():
    """Check if import hooks are currently active."""
    return _installed


def available_modules():
    """Return list of stdlib modules we provide replacements for."""
    return list(_REDIRECTS.keys())


def add_redirect(stdlib_name, compat_module):
    """
    Register a custom redirect.

    Allows users to add their own stdlib replacements:
        compat.add_redirect('mypackage', 'my_compat.mypackage')
    """
    _REDIRECTS[stdlib_name] = compat_module


# Auto-install when this module is imported
# This makes it easy: just `import ucharm.compat` at the top of your app
install()
