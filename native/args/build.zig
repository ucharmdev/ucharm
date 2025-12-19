const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the args module
    const args_mod = b.createModule(.{
        .root_source_file = b.path("args.zig"),
        .target = target,
        .optimize = optimize,
        // MicroPython's Unix port links as PIE on Linux; our Zig objects must be PIC.
        .pic = true,
    });

    // Build as object file for linking with MicroPython
    const obj = b.addObject(.{
        .name = "args",
        .root_module = args_mod,
    });

    // Custom step to copy the .o file to a known location
    const install_obj = b.addInstallFile(obj.getEmittedBin(), "args.o");
    b.getInstallStep().dependOn(&install_obj.step);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("args.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
