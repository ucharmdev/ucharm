const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build as a static library for linking with MicroPython
    const lib = b.addLibrary(.{
        .name = "subprocess",
        .root_module = b.createModule(.{
            .root_source_file = b.path("subprocess.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    // Link libc for fork/exec
    lib.root_module.link_libc = true;

    b.installArtifact(lib);

    // Tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("subprocess.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.link_libc = true;

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
