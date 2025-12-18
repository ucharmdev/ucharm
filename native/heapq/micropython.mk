# heapq/micropython.mk - MicroPython integration for native heapq
#
# This module is pure C (no Zig dependency) since all heap operations
# are done directly with MicroPython's list objects.

HEAPQ_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge source file
SRC_USERMOD_C += $(HEAPQ_MOD_DIR)/modheapq.c
