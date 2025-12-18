# re/micropython.mk - MicroPython integration for re extension
#
# This module extends MicroPython's built-in re module with findall and split.

RE_MOD_DIR := $(USERMOD_DIR)

# Add the C source file
SRC_USERMOD_C += $(RE_MOD_DIR)/modre.c
