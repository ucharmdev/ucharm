# Makefile fragment for the ansi module (Zig + C bridge)

ANSI_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge to the build
SRC_USERMOD_C += $(ANSI_MOD_DIR)/modansi.c

# Link the Zig-compiled object file
LDFLAGS_USERMOD += $(ANSI_MOD_DIR)/zig-out/ansi.o
