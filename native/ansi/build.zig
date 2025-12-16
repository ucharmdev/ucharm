const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the ansi module
    const ansi_mod = b.createModule(.{
        .root_source_file = b.path("ansi.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Build as object file for linking with MicroPython
    const obj = b.addObject(.{
        .name = "ansi",
        .root_module = ansi_mod,
    });

    // Install the .o file to zig-out/
    const install_obj = b.addInstallFile(obj.getEmittedBin(), "ansi.o");
    b.getInstallStep().dependOn(&install_obj.step);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("ansi.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
