const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build as a static library for linking with MicroPython
    const lib = b.addLibrary(.{
        .name = "functools",
        .root_module = b.createModule(.{
            .root_source_file = b.path("functools.zig"),
            .target = target,
            .optimize = optimize,
            // MicroPython's Unix port links as PIE on Linux; our Zig objects must be PIC.
            .pic = true,
        }),
        .linkage = .static,
    });

    b.installArtifact(lib);

    // Tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("functools.zig"),
            .target = target,
            .optimize = optimize,
            // MicroPython's Unix port links as PIE on Linux; our Zig objects must be PIC.
            .pic = true,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
