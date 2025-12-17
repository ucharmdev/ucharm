# Subprocess native module for MicroPython
# This module provides process spawning using Zig

SUBPROCESS_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source
SRC_USERMOD_C += $(SUBPROCESS_MOD_DIR)/modsubprocess.c

# Link the Zig static library
LDFLAGS_USERMOD += $(SUBPROCESS_MOD_DIR)/zig-out/lib/libsubprocess.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(SUBPROCESS_MOD_DIR)/../bridge
