# charm/micropython.mk - Makefile for MicroPython integration

CHARM_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source file
SRC_USERMOD_C += $(CHARM_MOD_DIR)/modcharm.c

# Link the Zig-compiled object file
LDFLAGS_USERMOD += $(CHARM_MOD_DIR)/zig-out/charm.o
