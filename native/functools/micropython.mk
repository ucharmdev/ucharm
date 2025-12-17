# MicroPython makefile for functools module

FUNCTOOLS_MOD_DIR := $(USERMOD_DIR)

# Add C source
SRC_USERMOD_C += $(FUNCTOOLS_MOD_DIR)/modfunctools.c

# Add Zig static library
LDFLAGS_USERMOD += $(FUNCTOOLS_MOD_DIR)/zig-out/lib/libfunctools.a

# Include bridge header
CFLAGS_USERMOD += -I$(FUNCTOOLS_MOD_DIR)/../bridge

# Build Zig library before compiling
$(FUNCTOOLS_MOD_DIR)/zig-out/lib/libfunctools.a:
	cd $(FUNCTOOLS_MOD_DIR) && zig build -Doptimize=ReleaseSmall
