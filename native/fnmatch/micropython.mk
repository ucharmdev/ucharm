# fnmatch/micropython.mk - Makefile for MicroPython integration

FNMATCH_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source file
SRC_USERMOD_C += $(FNMATCH_MOD_DIR)/modfnmatch.c

# Link the Zig-compiled object file
LDFLAGS_USERMOD += $(FNMATCH_MOD_DIR)/zig-out/fnmatch.o
