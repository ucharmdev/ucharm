# random/micropython.mk - Template Makefile for MicroPython integration
#
# Copy this file to your module directory as micropython.mk.
# Replace "random" with your module name.
#
# Example: For a "math" module:
#   1. Copy this to native/math/micropython.mk
#   2. Replace "RANDOM" with "MATH" (uppercase)
#   3. Replace "random" with "math" (lowercase)
#   4. Replace "modrandom.c" with "modmath.c"

# CHANGE: Replace RANDOM with your MODULE_NAME (uppercase)
RANDOM_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source file
# CHANGE: Replace "modrandom.c" with your "modmodulename.c"
SRC_USERMOD_C += $(RANDOM_MOD_DIR)/modrandom.c

# Link the Zig-compiled object file
# CHANGE: Replace "random.o" with your "modulename.o"
LDFLAGS_USERMOD += $(RANDOM_MOD_DIR)/zig-out/random.o
