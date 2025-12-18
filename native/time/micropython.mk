# time/micropython.mk - MicroPython integration for time extension
#
# This module extends MicroPython's built-in time module with strftime, strptime,
# monotonic, and perf_counter.

TIME_MOD_DIR := $(USERMOD_DIR)

# Add the C source file
SRC_USERMOD_C += $(TIME_MOD_DIR)/modtime.c
