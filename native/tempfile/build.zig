const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build as a static library for linking with MicroPython
    const lib = b.addLibrary(.{
        .name = "tempfile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tempfile.zig"),
            .target = target,
            .optimize = optimize,
            .pic = true,
        }),
        .linkage = .static,
    });

    b.installArtifact(lib);
}
