#!/usr/bin/env python3
"""
microcharm build tool

Builds a standalone executable by either:
1. Creating a self-contained shell wrapper (quick, ~700KB)
2. Compiling MicroPython with frozen bytecode (slower, true single binary)

Usage:
    # Quick build - shell wrapper + micropython
    python build.py myapp.py -o myapp

    # Single file Python (requires micropython at runtime)
    python build.py myapp.py -o myapp.py --mode single
"""

import argparse
import base64
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
MICROCHARM_DIR = SCRIPT_DIR.parent / "microcharm"


def find_micropython():
    """Find micropython binary."""
    locations = [
        shutil.which("micropython"),
        "/opt/homebrew/bin/micropython",
        "/usr/local/bin/micropython",
        "/usr/bin/micropython",
    ]
    for loc in locations:
        if loc and os.path.exists(loc):
            return loc
    return None


def get_microcharm_files():
    """Get all microcharm library files."""
    files = {}
    for py_file in MICROCHARM_DIR.glob("*.py"):
        files[f"microcharm/{py_file.name}"] = py_file.read_text()
    return files


def build_single_file(main_script, output_path):
    """Bundle into a single .py file that runs with micropython."""

    parts = [
        "#!/usr/bin/env micropython",
        "# Built with microcharm",
        "# Run with: micropython " + Path(output_path).name,
        "",
        "import sys",
        "import time",
        "",
        "# === Embedded microcharm library ===",
        "",
    ]

    # Order matters for dependencies
    module_order = ["terminal", "style", "components", "input", "table"]

    for module_name in module_order:
        py_file = MICROCHARM_DIR / f"{module_name}.py"
        if not py_file.exists():
            continue
        content = py_file.read_text()
        parts.append(f"# --- microcharm/{module_name}.py ---")

        for line in content.split("\n"):
            # Skip relative imports (already inlined)
            if line.strip().startswith("from ."):
                continue
            # Skip duplicate stdlib imports
            if line.strip() in ("import sys", "import time"):
                continue
            parts.append(line)
        parts.append("")

    # Process main script
    parts.append("# === Application ===")
    parts.append("")

    main_content = Path(main_script).read_text()
    in_multiline_import = False

    for line in main_content.split("\n"):
        stripped = line.strip()

        if in_multiline_import:
            if ")" in line:
                in_multiline_import = False
            continue

        if "from microcharm" in line or "import microcharm" in line:
            if "(" in line and ")" not in line:
                in_multiline_import = True
            continue

        if "sys.path" in line:
            continue

        if stripped in ("import sys", "import time"):
            continue

        parts.append(line)

    output = Path(output_path)
    output.write_text("\n".join(parts))
    output.chmod(0o755)

    size = output.stat().st_size
    print(f"Created: {output_path} ({size:,} bytes)")


def build_executable(main_script, output_path):
    """
    Build a self-contained executable.

    Creates a shell script that embeds the Python code and calls micropython.
    This is a pragmatic solution that works without recompiling micropython.
    """

    # First create the single-file bundle
    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
        temp_py = f.name

    build_single_file(main_script, temp_py)

    # Read the bundled Python code
    python_code = Path(temp_py).read_text()
    os.unlink(temp_py)

    # Base64 encode it
    encoded = base64.b64encode(python_code.encode()).decode()

    # Find micropython path
    mpy_path = find_micropython()
    if not mpy_path:
        print("Warning: micropython not found, using 'micropython' in PATH")
        mpy_path = "micropython"

    # Create the executable shell script
    # Uses a here-document approach for better compatibility
    shell_script = f'''#!/bin/bash
# Built with microcharm - https://github.com/yourname/microcharm
# This is a self-contained executable

MICROPYTHON="{mpy_path}"

# Check if micropython exists
if ! command -v "$MICROPYTHON" &> /dev/null; then
    if command -v micropython &> /dev/null; then
        MICROPYTHON="micropython"
    else
        echo "Error: micropython not found. Install with: brew install micropython" >&2
        exit 1
    fi
fi

# Embedded Python code (base64 encoded)
read -r -d '' ENCODED << 'ENDOFCODE'
{encoded}
ENDOFCODE

# Decode and execute
echo "$ENCODED" | base64 -d | "$MICROPYTHON" /dev/stdin "$@"
'''

    output = Path(output_path)
    output.write_text(shell_script)
    output.chmod(0o755)

    size = output.stat().st_size
    print(f"Created: {output_path} ({size:,} bytes)")
    print(f"Run with: ./{output.name}")


def build_universal(main_script, output_path):
    """
    Build a universal executable that embeds micropython itself.

    This creates a truly standalone binary by concatenating:
    1. A shell script header with known sizes
    2. The micropython binary
    3. The Python code

    Uses a cache directory for faster subsequent runs.
    """

    mpy_path = find_micropython()
    if not mpy_path:
        print("Error: micropython not found")
        sys.exit(1)

    # Create single-file bundle
    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
        temp_py = f.name

    build_single_file(main_script, temp_py)
    python_code = Path(temp_py).read_text()
    os.unlink(temp_py)

    # Read micropython binary
    mpy_binary = Path(mpy_path).read_bytes()
    mpy_size = len(mpy_binary)
    py_size = len(python_code.encode())

    # Calculate a hash for cache invalidation
    import hashlib

    content_hash = hashlib.md5((mpy_binary + python_code.encode())[:1000]).hexdigest()[
        :8
    ]

    # Use cache for faster startup after first run
    # Cache in ~/.cache/microcharm/<hash>/
    header_template = """#!/bin/bash
H={hash};C="$HOME/.cache/microcharm/$H"
if [ -x "$C/m" ] && [ -f "$C/a.py" ]; then exec "$C/m" "$C/a.py" "$@"; fi
mkdir -p "$C";S="$0"
dd bs=4096 skip=1 if="$S" 2>/dev/null|head -c {mpy_size} >"$C/m";chmod +x "$C/m"
tail -c {py_size} "$S">"$C/a.py";exec "$C/m" "$C/a.py" "$@"
"""

    # We need header to be exactly 4096 bytes so dd skip=1 works
    BLOCK_SIZE = 4096

    header_content = header_template.format(
        hash=content_hash, mpy_size=mpy_size, py_size=py_size
    )

    # Pad header to exactly BLOCK_SIZE
    padding_needed = BLOCK_SIZE - len(header_content)
    if padding_needed < 0:
        print(f"Error: header too large ({len(header_content)} > {BLOCK_SIZE})")
        sys.exit(1)

    # Pad with newlines and comments
    header = header_content + "\n" + "#" * (padding_needed - 2) + "\n"

    assert len(header) == BLOCK_SIZE, (
        f"Header size mismatch: {len(header)} != {BLOCK_SIZE}"
    )

    # Combine everything
    output = Path(output_path)
    with open(output, "wb") as f:
        f.write(header.encode())
        f.write(mpy_binary)
        f.write(python_code.encode())

    output.chmod(0o755)

    size = output.stat().st_size
    print(f"Created: {output_path} ({size:,} bytes)")
    print(f"This is a universal binary - no dependencies required!")


def main():
    parser = argparse.ArgumentParser(
        description="Build standalone microcharm executables",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s myapp.py -o myapp           # Shell wrapper (needs micropython)
  %(prog)s myapp.py -o myapp.py -m single  # Single .py file
  %(prog)s myapp.py -o myapp -m universal  # Embeds micropython (experimental)
        """,
    )
    parser.add_argument("script", help="Main Python script")
    parser.add_argument("-o", "--output", required=True, help="Output path")
    parser.add_argument(
        "-m",
        "--mode",
        choices=["executable", "single", "universal"],
        default="executable",
        help="Build mode (default: executable)",
    )

    args = parser.parse_args()

    if not os.path.exists(args.script):
        print(f"Error: {args.script} not found")
        sys.exit(1)

    print(f"Building {args.script}...")
    print(f"Mode: {args.mode}")
    print()

    if args.mode == "single":
        build_single_file(args.script, args.output)
    elif args.mode == "executable":
        build_executable(args.script, args.output)
    elif args.mode == "universal":
        build_universal(args.script, args.output)

    print()
    print("Done!")


if __name__ == "__main__":
    main()
