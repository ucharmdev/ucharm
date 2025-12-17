# Statistics native module for MicroPython
# This module provides statistical functions using Zig

STATISTICS_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source
SRC_USERMOD_C += $(STATISTICS_MOD_DIR)/modstatistics.c

# Link the Zig static library
LDFLAGS_USERMOD += $(STATISTICS_MOD_DIR)/zig-out/lib/libstatistics.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(STATISTICS_MOD_DIR)/../bridge
