# Glob native module for MicroPython
# This module provides fast glob/fnmatch operations using Zig

GLOB_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source
SRC_USERMOD_C += $(GLOB_MOD_DIR)/modglob.c

# Link the Zig static library
LDFLAGS_USERMOD += $(GLOB_MOD_DIR)/zig-out/lib/libglob.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(GLOB_MOD_DIR)/../bridge
