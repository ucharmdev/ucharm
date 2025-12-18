# OS module extension for MicroPython
# Adds environ, os.path, name, linesep to built-in os module

OS_MOD_DIR := $(USERMOD_DIR)

# Add the C source
SRC_USERMOD_C += $(OS_MOD_DIR)/modos.c

# Use Zig path functions from pathlib
CFLAGS_USERMOD += -I$(OS_MOD_DIR)/../pathlib
