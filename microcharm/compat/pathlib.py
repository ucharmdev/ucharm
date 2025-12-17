# microcharm/compat/pathlib.py
"""
Pure Python implementation of pathlib for MicroPython.

Provides the Path class with most common operations.
Uses os.path functions internally.

Note: This is a simplified implementation. Some advanced features
like symlink resolution may not work on all platforms.
"""

import os

# Try to import our native path module for better performance
try:
    import path as _native_path

    _HAS_NATIVE = True
except ImportError:
    _HAS_NATIVE = False


class PurePath:
    """
    Base class for Path that doesn't do any I/O.

    Handles path manipulation, joining, splitting, etc.
    """

    # Path separator for this platform
    _sep = "/"

    def __init__(self, *args):
        """
        Create a path from one or more path segments.

        Path('foo', 'bar', 'baz') -> Path('foo/bar/baz')
        Path('/foo/bar') -> Path('/foo/bar')
        """
        if len(args) == 0:
            self._path = "."
        elif len(args) == 1:
            arg = args[0]
            if isinstance(arg, PurePath):
                self._path = arg._path
            else:
                self._path = str(arg)
        else:
            # Join multiple segments
            parts = []
            for arg in args:
                if isinstance(arg, PurePath):
                    parts.append(arg._path)
                else:
                    parts.append(str(arg))
            self._path = self._sep.join(parts)

        # Normalize the path
        self._path = self._normalize(self._path)

    def _normalize(self, path):
        """Normalize a path string."""
        if not path:
            return "."

        # Use native module if available
        if _HAS_NATIVE:
            return _native_path.normalize(path)

        # Manual normalization
        # Remove trailing slashes (except for root)
        while len(path) > 1 and path.endswith("/"):
            path = path[:-1]

        # Handle // at start
        if path.startswith("//") and not path.startswith("///"):
            path = path[1:]

        return path

    def __str__(self):
        return self._path

    def __repr__(self):
        return "Path('" + self._path + "')"

    def __eq__(self, other):
        if isinstance(other, PurePath):
            return self._path == other._path
        return self._path == str(other)

    def __hash__(self):
        return hash(self._path)

    def __truediv__(self, other):
        """Path / 'subdir' -> Path('path/subdir')"""
        return Path(self._path, str(other))

    def __rtruediv__(self, other):
        """'parent' / Path -> Path('parent/path')"""
        return Path(str(other), self._path)

    @property
    def parts(self):
        """
        Return tuple of path components.

        Path('/foo/bar/baz').parts -> ('/', 'foo', 'bar', 'baz')
        """
        if not self._path or self._path == ".":
            return ()

        parts = []
        path = self._path

        # Handle absolute path
        if path.startswith("/"):
            parts.append("/")
            path = path[1:]

        # Split remaining path
        if path:
            parts.extend(path.split("/"))

        return tuple(parts)

    @property
    def parent(self):
        """
        Return the parent directory.

        Path('/foo/bar').parent -> Path('/foo')
        """
        if _HAS_NATIVE:
            return Path(_native_path.dirname(self._path))

        # Find last separator
        idx = self._path.rfind("/")
        if idx <= 0:
            if self._path.startswith("/"):
                return Path("/")
            return Path(".")
        return Path(self._path[:idx])

    @property
    def parents(self):
        """
        Return immutable sequence of parent directories.

        Path('/foo/bar/baz').parents -> (Path('/foo/bar'), Path('/foo'), Path('/'))
        """
        parents = []
        p = self.parent
        while p._path != "." and p._path != "/":
            parents.append(p)
            p = p.parent
        if p._path == "/":
            parents.append(p)
        return tuple(parents)

    @property
    def name(self):
        """
        Return the final component.

        Path('/foo/bar.txt').name -> 'bar.txt'
        Path('.').name -> ''
        Path('..').name -> '..'
        """
        if _HAS_NATIVE:
            return _native_path.basename(self._path)

        # Special case: '.' has empty name
        if self._path == ".":
            return ""

        idx = self._path.rfind("/")
        if idx < 0:
            return self._path
        return self._path[idx + 1 :]

    @property
    def stem(self):
        """
        Return the name without suffix.

        Path('/foo/bar.txt').stem -> 'bar'
        Path('.').stem -> ''
        Path('..').stem -> '..'
        """
        if _HAS_NATIVE:
            return _native_path.stem(self._path)

        name = self.name
        # Special case: '..' stem is '..'
        if name == "..":
            return ".."
        idx = name.rfind(".")
        if idx <= 0:  # No dot or starts with dot
            return name
        return name[:idx]

    @property
    def suffix(self):
        """
        Return the file extension.

        Path('/foo/bar.txt').suffix -> '.txt'
        Path('..').suffix -> ''
        """
        if _HAS_NATIVE:
            ext = _native_path.extname(self._path)
            return ext if ext else ""

        name = self.name
        # Special case: '..' has no suffix
        if name == "..":
            return ""
        idx = name.rfind(".")
        if idx <= 0:
            return ""
        return name[idx:]

    @property
    def suffixes(self):
        """
        Return list of all extensions.

        Path('/foo/bar.tar.gz').suffixes -> ['.tar', '.gz']
        """
        name = self.name
        if name.startswith("."):
            name = name[1:]

        parts = name.split(".")
        if len(parts) <= 1:
            return []
        return ["." + p for p in parts[1:]]

    def is_absolute(self):
        """Check if path is absolute."""
        if _HAS_NATIVE:
            return _native_path.is_absolute(self._path)
        return self._path.startswith("/")

    def is_relative(self):
        """Check if path is relative."""
        return not self.is_absolute()

    def joinpath(self, *others):
        """Join path with others."""
        return Path(self, *others)

    def with_name(self, name):
        """
        Return path with name changed.

        Path('/foo/bar.txt').with_name('baz.py') -> Path('/foo/baz.py')
        Path('file.txt').with_name('other.md') -> Path('other.md')
        """
        parent = self.parent
        # If parent is '.', just return the new name
        if parent._path == ".":
            return Path(name)
        return parent / name

    def with_stem(self, stem):
        """
        Return path with stem changed.

        Path('/foo/bar.txt').with_stem('baz') -> Path('/foo/baz.txt')
        """
        return self.with_name(stem + self.suffix)

    def with_suffix(self, suffix):
        """
        Return path with suffix changed.

        Path('/foo/bar.txt').with_suffix('.md') -> Path('/foo/bar.md')
        Path('file.txt').with_suffix('.py') -> Path('file.py')
        """
        return self.with_name(self.stem + suffix)

    def relative_to(self, other):
        """
        Return path relative to other.

        Path('/foo/bar/baz').relative_to('/foo') -> Path('bar/baz')
        """
        other_path = str(other)
        if not self._path.startswith(other_path):
            raise ValueError(str(self) + " is not relative to " + other_path)

        rel = self._path[len(other_path) :]
        if rel.startswith("/"):
            rel = rel[1:]
        return Path(rel) if rel else Path(".")

    def match(self, pattern):
        """
        Check if path matches a glob pattern.

        Path('/foo/bar.txt').match('*.txt') -> True
        """
        # Simple implementation - just check name against pattern
        import fnmatch as fm

        return fm.fnmatch(self.name, pattern)

    def as_posix(self):
        """Return path with forward slashes."""
        return self._path.replace("\\", "/")


class Path(PurePath):
    """
    Path class with I/O operations.

    Provides methods like exists(), read_text(), mkdir(), etc.
    """

    def __new__(cls, *args):
        """Create a new Path instance."""
        return object.__new__(cls)

    def exists(self):
        """Check if path exists."""
        try:
            os.stat(self._path)
            return True
        except OSError:
            return False

    def is_file(self):
        """Check if path is a file."""
        try:
            mode = os.stat(self._path)[0]
            return (mode & 0o170000) == 0o100000  # S_IFREG
        except OSError:
            return False

    def is_dir(self):
        """Check if path is a directory."""
        try:
            mode = os.stat(self._path)[0]
            return (mode & 0o170000) == 0o040000  # S_IFDIR
        except OSError:
            return False

    def is_symlink(self):
        """Check if path is a symlink."""
        try:
            mode = os.lstat(self._path)[0]
            return (mode & 0o170000) == 0o120000  # S_IFLNK
        except (OSError, AttributeError):
            return False

    def stat(self):
        """Return os.stat() result for path."""
        return os.stat(self._path)

    def lstat(self):
        """Like stat() but don't follow symlinks."""
        return os.lstat(self._path)

    def resolve(self):
        """
        Return absolute path, resolving symlinks.
        """
        # Simple implementation - just make absolute
        if self.is_absolute():
            return Path(self._path)

        cwd = os.getcwd()
        return Path(cwd + "/" + self._path)

    def absolute(self):
        """Return absolute path without resolving symlinks."""
        return self.resolve()

    @classmethod
    def cwd(cls):
        """Return current working directory."""
        return cls(os.getcwd())

    @classmethod
    def home(cls):
        """Return user's home directory."""
        home = os.getenv("HOME")
        if home:
            return cls(home)
        raise RuntimeError("Could not determine home directory")

    def iterdir(self):
        """
        Iterate over directory contents.

        Yields Path objects for each entry.
        """
        for name in os.listdir(self._path):
            yield Path(self._path + "/" + name)

    def glob(self, pattern):
        """
        Glob for files matching pattern.

        Path('.').glob('*.py') yields all .py files in directory
        Path('.').glob('**/*.py') yields all .py files recursively
        """
        import fnmatch as fm

        # Handle recursive glob
        if pattern.startswith("**/"):
            # Recursive - walk tree
            rest = pattern[3:]
            for entry in self._walk():
                if fm.fnmatch(entry.name, rest):
                    yield entry
        else:
            # Non-recursive - just this directory
            for entry in self.iterdir():
                if fm.fnmatch(entry.name, pattern):
                    yield entry

    def rglob(self, pattern):
        """
        Recursive glob.

        Equivalent to glob('**/' + pattern)
        """
        return self.glob("**/" + pattern)

    def _walk(self):
        """Walk directory tree yielding all files."""
        try:
            for entry in self.iterdir():
                yield entry
                if entry.is_dir():
                    for sub in entry._walk():
                        yield sub
        except OSError:
            pass

    def mkdir(self, mode=0o777, parents=False, exist_ok=False):
        """
        Create directory.

        parents: Create parent directories if needed
        exist_ok: Don't raise if directory exists
        """
        try:
            if parents:
                # Create parent directories
                self._makedirs(mode)
            else:
                os.mkdir(self._path)
        except OSError as e:
            if exist_ok and self.is_dir():
                return
            raise

    def _makedirs(self, mode):
        """Create directory and parents."""
        parts = self._path.split("/")
        current = ""

        for i, part in enumerate(parts):
            if not part:
                if i == 0:
                    current = "/"
                continue

            current = (
                current + "/" + part
                if current and current != "/"
                else (current + part if current else part)
            )

            try:
                os.mkdir(current)
            except OSError:
                # Directory might already exist
                if not Path(current).is_dir():
                    raise

    def rmdir(self):
        """Remove empty directory."""
        os.rmdir(self._path)

    def unlink(self, missing_ok=False):
        """Remove file."""
        try:
            os.remove(self._path)
        except OSError:
            if not missing_ok:
                raise

    def rename(self, target):
        """Rename file or directory."""
        os.rename(self._path, str(target))
        return Path(target)

    def replace(self, target):
        """Rename, replacing target if it exists."""
        # On POSIX, rename() already replaces
        return self.rename(target)

    def touch(self, mode=0o666, exist_ok=True):
        """Create file or update modification time."""
        if self.exists():
            if not exist_ok:
                raise FileExistsError(str(self))
            # Update mtime - open and close
            with open(self._path, "a"):
                pass
        else:
            # Create empty file
            with open(self._path, "w"):
                pass

    def read_text(self, encoding="utf-8"):
        """Read file contents as string."""
        with open(self._path, "r") as f:
            return f.read()

    def read_bytes(self):
        """Read file contents as bytes."""
        with open(self._path, "rb") as f:
            return f.read()

    def write_text(self, data, encoding="utf-8"):
        """Write string to file."""
        with open(self._path, "w") as f:
            f.write(data)
        return len(data)

    def write_bytes(self, data):
        """Write bytes to file."""
        with open(self._path, "wb") as f:
            f.write(data)
        return len(data)

    def open(self, mode="r", buffering=-1, encoding=None, errors=None, newline=None):
        """Open file and return file object."""
        # MicroPython's open() is simpler
        if "b" in mode:
            return open(self._path, mode)
        return open(self._path, mode)

    def samefile(self, other):
        """Check if two paths point to the same file."""
        try:
            s1 = self.stat()
            s2 = Path(other).stat()
            # Compare device and inode
            return s1[0] == s2[0] and s1[1] == s2[1]
        except (OSError, AttributeError):
            return False

    def __fspath__(self):
        """Return path as string for os.fspath()."""
        return self._path


# Aliases
PurePosixPath = PurePath
PureWindowsPath = PurePath
PosixPath = Path
WindowsPath = Path
