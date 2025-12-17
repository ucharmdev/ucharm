# Base64 native module for MicroPython
# This module provides fast base64 encoding/decoding using Zig

BASE64_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source
SRC_USERMOD_C += $(BASE64_MOD_DIR)/modbase64.c

# Link the Zig static library
LDFLAGS_USERMOD += $(BASE64_MOD_DIR)/zig-out/lib/libbase64.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(BASE64_MOD_DIR)/../bridge
