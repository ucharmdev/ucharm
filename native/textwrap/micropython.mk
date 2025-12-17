# Textwrap native module for MicroPython
# This module provides text wrapping functions using Zig

TEXTWRAP_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source
SRC_USERMOD_C += $(TEXTWRAP_MOD_DIR)/modtextwrap.c

# Link the Zig static library
LDFLAGS_USERMOD += $(TEXTWRAP_MOD_DIR)/zig-out/lib/libtextwrap.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(TEXTWRAP_MOD_DIR)/../bridge
