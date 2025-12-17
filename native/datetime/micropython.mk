# Makefile fragment for the datetime module

DATETIME_MOD_DIR := $(USERMOD_DIR)

# Add our source files to the build
SRC_USERMOD_C += $(DATETIME_MOD_DIR)/moddatetime.c

# Link the Zig static library
LDFLAGS_USERMOD += $(DATETIME_MOD_DIR)/zig-out/lib/libdatetime.a

# Add include path for mpy_bridge.h
CFLAGS_USERMOD += -I$(DATETIME_MOD_DIR)/../bridge
