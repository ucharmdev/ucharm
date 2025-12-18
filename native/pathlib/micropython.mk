# Pathlib native module for MicroPython
# This module provides:
# - Native 'path' module with low-level path functions (Zig)
# - Pure Python 'pathlib' module with Path class (in pathlib.py)

PATHLIB_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source for the native 'path' module
SRC_USERMOD_C += $(PATHLIB_MOD_DIR)/modpathlib.c

# Link the Zig static library
LDFLAGS_USERMOD += $(PATHLIB_MOD_DIR)/zig-out/lib/libpathlib.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(PATHLIB_MOD_DIR)/../bridge
