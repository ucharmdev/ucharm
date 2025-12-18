# operator module for ucharm
# Provides Python's operator module functionality

OPERATOR_MOD_DIR := $(USERMOD_DIR)

SRC_USERMOD_C += $(OPERATOR_MOD_DIR)/modoperator.c

CFLAGS_USERMOD += -I$(OPERATOR_MOD_DIR)
