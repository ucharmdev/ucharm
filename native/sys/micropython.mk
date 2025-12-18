# Sys module extension for MicroPython
# Adds getrecursionlimit, setrecursionlimit, getsizeof, intern, flags

SYS_MOD_DIR := $(USERMOD_DIR)

# Add the C source
SRC_USERMOD_C += $(SYS_MOD_DIR)/modsys.c
