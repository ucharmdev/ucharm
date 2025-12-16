# Makefile fragment for the args module (Zig + C bridge)

ARGS_MOD_DIR := $(USERMOD_DIR)

# Add the C bridge to the build
SRC_USERMOD_C += $(ARGS_MOD_DIR)/modargs.c

# Link the Zig-compiled object file via LDFLAGS
LDFLAGS_USERMOD += $(ARGS_MOD_DIR)/zig-out/args.o
