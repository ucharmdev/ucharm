// charm/build.zig - Build configuration for charm module

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the module
    const mod = b.createModule(.{
        .root_source_file = b.path("charm.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Build as object file for linking with MicroPython
    const obj = b.addObject(.{
        .name = "charm",
        .root_module = mod,
    });

    // Install the .o file to zig-out/
    const install_obj = b.addInstallFile(obj.getEmittedBin(), "charm.o");
    b.getInstallStep().dependOn(&install_obj.step);

    // Unit tests
    const test_mod = b.createModule(.{
        .root_source_file = b.path("charm.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
