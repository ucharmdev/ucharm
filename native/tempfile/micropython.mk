# Tempfile native module for MicroPython
# This module provides temporary file/directory operations using Zig

TEMPFILE_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source
SRC_USERMOD_C += $(TEMPFILE_MOD_DIR)/modtempfile.c

# Link the Zig static library
LDFLAGS_USERMOD += $(TEMPFILE_MOD_DIR)/zig-out/lib/libtempfile.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(TEMPFILE_MOD_DIR)/../bridge
