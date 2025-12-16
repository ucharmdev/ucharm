#!/bin/bash
# Build custom MicroPython with microcharm native modules
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MPY_DIR="${MPY_DIR:-$HOME/.microcharm/micropython}"
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

# Build MicroPython Unix port with our modules
echo "Building MicroPython with native modules..."
cd "$MPY_DIR/ports/unix"

# Build with our user modules
make -j$NCPU USER_C_MODULES="$SCRIPT_DIR"

# Copy the built binary
mkdir -p "$OUTPUT_DIR"
cp build-standard/micropython "$OUTPUT_DIR/micropython-mcharm"
chmod +x "$OUTPUT_DIR/micropython-mcharm"

echo ""
echo "=== Build Complete ==="
echo "Custom MicroPython: $OUTPUT_DIR/micropython-mcharm"
ls -lh "$OUTPUT_DIR/micropython-mcharm"

echo ""
echo "Modules included:"
"$OUTPUT_DIR/micropython-mcharm" -c "import term, ansi; print('  - term:', len([x for x in dir(term) if not x.startswith('_')]), 'functions'); print('  - ansi:', len([x for x in dir(ansi) if not x.startswith('_')]), 'functions')"

echo ""
echo "Test with:"
echo "  $OUTPUT_DIR/micropython-mcharm -c 'import term; print(term.size())'"
echo "  $OUTPUT_DIR/micropython-mcharm -c 'import ansi; print(ansi.fg(\"cyan\") + \"Hello!\" + ansi.reset())'"
