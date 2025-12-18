# input/micropython.mk - Makefile for MicroPython integration

INPUT_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source file
SRC_USERMOD_C += $(INPUT_MOD_DIR)/modinput.c

# Link the Zig-compiled object file
LDFLAGS_USERMOD += $(INPUT_MOD_DIR)/zig-out/input.o
