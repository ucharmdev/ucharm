// random_build.zig - Template build.zig for Zig modules
//
// Copy this file to your module directory as build.zig.
// Replace "random" with your module name.
//
// Example: For a "math" module:
//   1. Copy this to native/math/build.zig
//   2. Replace "random" with "math"

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the module
    // CHANGE: Replace "random.zig" with your module name
    const mod = b.createModule(.{
        .root_source_file = b.path("random.zig"),
        .target = target,
        .optimize = optimize,
        // MicroPython's Unix port links as PIE on Linux; our Zig objects must be PIC.
        .pic = true,
    });

    // Add bridge module dependency
    mod.addImport("bridge", b.createModule(.{
        .root_source_file = b.path("../bridge/bridge.zig"),
        .target = target,
        .optimize = optimize,
    }));

    // Build as object file for linking with MicroPython
    const obj = b.addObject(.{
        // CHANGE: Replace "random" with your module name
        .name = "random",
        .root_module = mod,
    });

    // Install the .o file to zig-out/
    // CHANGE: Replace "random.o" with your module name
    const install_obj = b.addInstallFile(obj.getEmittedBin(), "random.o");
    b.getInstallStep().dependOn(&install_obj.step);

    // Unit tests
    const test_mod = b.createModule(.{
        // CHANGE: Replace "random.zig" with your module name
        .root_source_file = b.path("random.zig"),
        .target = target,
        .optimize = optimize,
        // MicroPython's Unix port links as PIE on Linux; our Zig objects must be PIC.
        .pic = true,
    });

    test_mod.addImport("bridge", b.createModule(.{
        .root_source_file = b.path("../bridge/bridge.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const unit_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
