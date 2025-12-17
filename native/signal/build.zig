const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build as a static library for linking with MicroPython
    const lib = b.addLibrary(.{
        .name = "signal",
        .root_module = b.createModule(.{
            .root_source_file = b.path("signal.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    // Link libc for signal functions
    lib.root_module.link_libc = true;

    b.installArtifact(lib);
}
