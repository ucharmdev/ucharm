# template/micropython.mk - Template Makefile for MicroPython integration
#
# Copy this file to your module directory as micropython.mk.
# Replace "template" with your module name.
#
# Example: For a "math" module:
#   1. Copy this to native/math/micropython.mk
#   2. Replace "TEMPLATE" with "MATH" (uppercase)
#   3. Replace "template" with "math" (lowercase)
#   4. Replace "modtemplate.c" with "modmath.c"

# CHANGE: Replace TEMPLATE with your MODULE_NAME (uppercase)
TEMPLATE_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source file
# CHANGE: Replace "modtemplate.c" with your "modmodulename.c"
SRC_USERMOD_C += $(TEMPLATE_MOD_DIR)/modtemplate.c

# Link the Zig-compiled object file
# CHANGE: Replace "template.o" with your "modulename.o"
LDFLAGS_USERMOD += $(TEMPLATE_MOD_DIR)/zig-out/template.o
