#!/bin/bash
# Build custom MicroPython with ucharm native modules
# Uses Zig for core logic, C bridge for MicroPython API
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MPY_DIR="${MPY_DIR:-$HOME/.ucharm/micropython}"
OUTPUT_DIR="$SCRIPT_DIR/dist"
NCPU=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

echo "=== μcharm Custom MicroPython Builder ==="
echo "MicroPython: $MPY_DIR"
echo ""

# Clone MicroPython if needed
if [ ! -d "$MPY_DIR" ]; then
    echo "Cloning MicroPython repository..."
    mkdir -p "$(dirname "$MPY_DIR")"
    git clone --depth 1 https://github.com/micropython/micropython.git "$MPY_DIR"
    echo ""
fi

# Initialize submodules if needed
if [ ! -f "$MPY_DIR/lib/mbedtls/include/mbedtls/ssl.h" ]; then
    echo "Initializing MicroPython submodules..."
    cd "$MPY_DIR"
    git submodule update --init --depth 1 lib/mbedtls lib/berkeley-db-1.xx lib/micropython-lib
    cd "$SCRIPT_DIR"
    echo ""
fi

# Build mpy-cross if needed
if [ ! -f "$MPY_DIR/mpy-cross/build/mpy-cross" ]; then
    echo "Building mpy-cross..."
    cd "$MPY_DIR/mpy-cross"
    make -j$NCPU
    cd "$SCRIPT_DIR"
    echo ""
fi

# Build shared library for CPython development
echo "Building shared library for CPython..."
cd "$SCRIPT_DIR/bridge"
zig build -Doptimize=ReleaseFast
mkdir -p "$OUTPUT_DIR"
if [ -f "zig-out/lib/libucharm.dylib" ]; then
    cp zig-out/lib/libucharm.dylib "$OUTPUT_DIR/"
    echo "  Built: $OUTPUT_DIR/libucharm.dylib"
elif [ -f "zig-out/lib/libucharm.so" ]; then
    cp zig-out/lib/libucharm.so "$OUTPUT_DIR/"
    echo "  Built: $OUTPUT_DIR/libucharm.so"
fi
cd "$SCRIPT_DIR"
echo ""

# Build Zig modules
echo "Building Zig modules..."
for module_dir in "$SCRIPT_DIR"/*/; do
    if [ -f "$module_dir/build.zig" ]; then
        module_name=$(basename "$module_dir")
        # Skip the bridge directory (already built above)
        if [ "$module_name" = "bridge" ]; then
            continue
        fi
        echo "  Building $module_name (Zig)..."
        cd "$module_dir"

        # Run tests if test step exists
        if zig build -l 2>&1 | grep -q "^  test "; then
            if ! zig build test; then
                echo "    ERROR: Tests failed for $module_name"
                exit 1
            fi
        fi

        # Build the object file with ReleaseSmall for minimal binary size
        # (Debug builds include full Zig stdlib, bloating from ~5KB to ~1.6MB!)
        zig build -Doptimize=ReleaseSmall

        if [ -f "zig-out/$module_name.o" ]; then
            echo "    Built: zig-out/$module_name.o ($(ls -lh zig-out/$module_name.o | awk '{print $5}'))"
        elif [ -f "zig-out/lib/lib$module_name.a" ]; then
            echo "    Built: zig-out/lib/lib$module_name.a ($(ls -lh zig-out/lib/lib$module_name.a | awk '{print $5}'))"
        else
            echo "    Built: zig-out/*"
        fi
        cd "$SCRIPT_DIR"
    fi
done
echo ""

# Build MicroPython Unix port with our modules
echo "Building MicroPython with native modules..."
cd "$MPY_DIR/ports/unix"

# Clean previous build to ensure fresh link
make clean > /dev/null 2>&1 || true

# Build with our user modules
# Disable built-in random and heapq modules so our native ones take precedence
# Enable additional CPython compatibility features:
#   - RE: match.groups(), match.start/end/span()
#   - COLLECTIONS: namedtuple._asdict()
CFLAGS_COMPAT="-DMICROPY_PY_RANDOM=0 \
    -DMICROPY_PY_HEAPQ=0 \
    -DMICROPY_PY_JSON=0 \
    -DMICROPY_PY_RE_MATCH_GROUPS=1 \
    -DMICROPY_PY_RE_MATCH_SPAN_START_END=1 \
    -DMICROPY_PY_COLLECTIONS_NAMEDTUPLE__ASDICT=1"
make -j$NCPU USER_C_MODULES="$SCRIPT_DIR" CFLAGS_EXTRA="$CFLAGS_COMPAT"

# Copy the built binary
mkdir -p "$OUTPUT_DIR"
cp build-standard/micropython "$OUTPUT_DIR/micropython-ucharm"
chmod +x "$OUTPUT_DIR/micropython-ucharm"

# Sign the binary on macOS (required for proper execution)
if [ "$(uname)" = "Darwin" ]; then
    echo "Signing binary for macOS..."
    codesign -s - "$OUTPUT_DIR/micropython-ucharm" 2>/dev/null || true
fi

echo ""
echo "=== Build Complete ==="
echo "Custom MicroPython: $OUTPUT_DIR/micropython-ucharm"
ls -lh "$OUTPUT_DIR/micropython-ucharm"

echo ""
echo "Modules included:"
"$OUTPUT_DIR/micropython-ucharm" -c "
modules = []
try:
    import term
    modules.append(('term', len([x for x in dir(term) if not x.startswith('_')])))
except: pass
try:
    import ansi
    modules.append(('ansi', len([x for x in dir(ansi) if not x.startswith('_')])))
except: pass
try:
    import args
    modules.append(('args', len([x for x in dir(args) if not x.startswith('_')])))
except: pass
for name, count in modules:
    print(f'  - {name}: {count} functions')
"

echo ""
echo "Test with:"
echo "  $OUTPUT_DIR/micropython-ucharm -c 'import term; print(term.size())'"
echo "  $OUTPUT_DIR/micropython-ucharm -c 'import ansi; print(ansi.fg(\"cyan\") + \"Hello!\" + ansi.reset())'"
echo "  $OUTPUT_DIR/micropython-ucharm -c 'import args; print(args.raw())'"
