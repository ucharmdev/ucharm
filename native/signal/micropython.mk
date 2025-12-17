# Signal native module for MicroPython
# This module provides signal handling using Zig

SIGNAL_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source
SRC_USERMOD_C += $(SIGNAL_MOD_DIR)/modsignal.c

# Link the Zig static library
LDFLAGS_USERMOD += $(SIGNAL_MOD_DIR)/zig-out/lib/libsignal.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(SIGNAL_MOD_DIR)/../bridge
