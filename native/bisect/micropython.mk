# bisect module for ucharm
# Provides Python's bisect module functionality

BISECT_MOD_DIR := $(USERMOD_DIR)

SRC_USERMOD_C += $(BISECT_MOD_DIR)/modbisect.c

CFLAGS_USERMOD += -I$(BISECT_MOD_DIR)
