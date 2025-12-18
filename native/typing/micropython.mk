# typing/micropython.mk - Makefile for MicroPython integration

TYPING_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source file
SRC_USERMOD_C += $(TYPING_MOD_DIR)/modtyping.c

# Link the Zig-compiled object file
LDFLAGS_USERMOD += $(TYPING_MOD_DIR)/zig-out/typing.o
