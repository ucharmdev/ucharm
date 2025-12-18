# copy/micropython.mk - Makefile for MicroPython integration

COPY_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source file
SRC_USERMOD_C += $(COPY_MOD_DIR)/modcopy.c

# Link the Zig-compiled object file
LDFLAGS_USERMOD += $(COPY_MOD_DIR)/zig-out/copy.o
