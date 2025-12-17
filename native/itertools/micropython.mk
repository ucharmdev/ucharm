# MicroPython makefile for itertools module

ITERTOOLS_MOD_DIR := $(USERMOD_DIR)

# Add C source
SRC_USERMOD_C += $(ITERTOOLS_MOD_DIR)/moditertools.c

# Add Zig static library
LDFLAGS_USERMOD += $(ITERTOOLS_MOD_DIR)/zig-out/lib/libitertools.a

# Include bridge header
CFLAGS_USERMOD += -I$(ITERTOOLS_MOD_DIR)/../bridge

# Build Zig library before compiling
$(ITERTOOLS_MOD_DIR)/zig-out/lib/libitertools.a:
	cd $(ITERTOOLS_MOD_DIR) && zig build -Doptimize=ReleaseSmall
