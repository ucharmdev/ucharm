# MicroPython makefile for csv module

CSV_MOD_DIR := $(USERMOD_DIR)

# Add C source
SRC_USERMOD_C += $(CSV_MOD_DIR)/modcsv.c

# Add Zig static library
LDFLAGS_USERMOD += $(CSV_MOD_DIR)/zig-out/lib/libcsv.a

# Build Zig library before compiling
$(CSV_MOD_DIR)/zig-out/lib/libcsv.a:
	cd $(CSV_MOD_DIR) && zig build -Doptimize=ReleaseSmall
