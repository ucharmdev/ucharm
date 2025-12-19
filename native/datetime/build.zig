const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "datetime",
        .root_module = b.createModule(.{
            .root_source_file = b.path("datetime.zig"),
            .target = target,
            .optimize = optimize,
            // MicroPython's Unix port links as PIE on Linux; our Zig objects must be PIC.
            .pic = true,
        }),
        .linkage = .static,
    });

    b.installArtifact(lib);
}
