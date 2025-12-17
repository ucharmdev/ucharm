# MicroPython makefile for logging module

LOGGING_MOD_DIR := $(USERMOD_DIR)

# Add C source
SRC_USERMOD_C += $(LOGGING_MOD_DIR)/modlogging.c

# Add Zig static library
LDFLAGS_USERMOD += $(LOGGING_MOD_DIR)/zig-out/lib/liblogging.a

# Include bridge header
CFLAGS_USERMOD += -I$(LOGGING_MOD_DIR)/../bridge

# Build Zig library before compiling
$(LOGGING_MOD_DIR)/zig-out/lib/liblogging.a:
	cd $(LOGGING_MOD_DIR) && zig build -Doptimize=ReleaseSmall
