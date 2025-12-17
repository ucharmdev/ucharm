# Shutil native module for MicroPython
# This module provides high-level file operations using Zig

SHUTIL_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source
SRC_USERMOD_C += $(SHUTIL_MOD_DIR)/modshutil.c

# Link the Zig static library
LDFLAGS_USERMOD += $(SHUTIL_MOD_DIR)/zig-out/lib/libshutil.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(SHUTIL_MOD_DIR)/../bridge
