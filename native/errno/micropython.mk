# micropython.mk for errno module extension

ERRNO_MOD_DIR := $(USERMOD_DIR)

# Add the source file
SRC_USERMOD += $(ERRNO_MOD_DIR)/moderrno.c
