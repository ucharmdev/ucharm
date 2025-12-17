#!/bin/bash
# new_module.sh - Create a new Zig-based MicroPython module
#
# Usage: ./new_module.sh <module_name>
# Example: ./new_module.sh math

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRIDGE_DIR="$SCRIPT_DIR/bridge"

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <module_name>"
    echo "Example: $0 math"
    exit 1
fi

MODULE_NAME="$1"
MODULE_NAME_UPPER=$(echo "$MODULE_NAME" | tr '[:lower:]' '[:upper:]')
MODULE_DIR="$SCRIPT_DIR/$MODULE_NAME"

# Check if module already exists
if [ -d "$MODULE_DIR" ]; then
    echo "Error: Module '$MODULE_NAME' already exists at $MODULE_DIR"
    exit 1
fi

echo "Creating new module: $MODULE_NAME"
echo "Directory: $MODULE_DIR"
echo

# Create directory
mkdir -p "$MODULE_DIR"

# Copy and transform Zig file
echo "  Creating $MODULE_NAME.zig..."
sed "s/template/$MODULE_NAME/g" "$BRIDGE_DIR/template.zig" > "$MODULE_DIR/$MODULE_NAME.zig"

# Copy and transform C bridge
echo "  Creating mod$MODULE_NAME.c..."
sed "s/template/$MODULE_NAME/g" "$BRIDGE_DIR/template_mod.c" > "$MODULE_DIR/mod$MODULE_NAME.c"

# Copy and transform build.zig
echo "  Creating build.zig..."
sed "s/template/$MODULE_NAME/g" "$BRIDGE_DIR/template_build.zig" > "$MODULE_DIR/build.zig"

# Copy and transform micropython.mk
echo "  Creating micropython.mk..."
sed -e "s/template/$MODULE_NAME/g" \
    -e "s/TEMPLATE/$MODULE_NAME_UPPER/g" \
    "$BRIDGE_DIR/template_micropython.mk" > "$MODULE_DIR/micropython.mk"

echo
echo "Module '$MODULE_NAME' created successfully!"
echo
echo "Next steps:"
echo "  1. Edit $MODULE_DIR/$MODULE_NAME.zig"
echo "     - Add your Zig functions"
echo "     - Export them with 'export fn ${MODULE_NAME}_funcname(...)'"
echo
echo "  2. Edit $MODULE_DIR/mod$MODULE_NAME.c"
echo "     - Add extern declarations for Zig functions"
echo "     - Create MicroPython wrappers"
echo "     - Register in module table"
echo
echo "  3. Build and test:"
echo "     cd $MODULE_DIR"
echo "     zig build test    # Run Zig tests"
echo "     zig build         # Compile to .o file"
echo "     cd .."
echo "     ./build.sh        # Rebuild micropython-ucharm"
echo
echo "  4. Use in Python:"
echo "     import $MODULE_NAME"
echo "     $MODULE_NAME.your_function()"
