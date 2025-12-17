const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================================
    // Shared Library (for CPython/development)
    // ========================================================================

    // Create the shared library module
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("shared_lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies on other modules
    lib_mod.addImport("ansi", b.createModule(.{
        .root_source_file = b.path("../ansi/ansi.zig"),
        .target = target,
        .optimize = optimize,
    }));

    lib_mod.addImport("args", b.createModule(.{
        .root_source_file = b.path("../args/args.zig"),
        .target = target,
        .optimize = optimize,
    }));

    lib_mod.addImport("ui", b.createModule(.{
        .root_source_file = b.path("../ui/ui.zig"),
        .target = target,
        .optimize = optimize,
    }));

    lib_mod.addImport("env", b.createModule(.{
        .root_source_file = b.path("../env/env.zig"),
        .target = target,
        .optimize = optimize,
    }));

    lib_mod.addImport("path", b.createModule(.{
        .root_source_file = b.path("../path/path.zig"),
        .target = target,
        .optimize = optimize,
    }));

    lib_mod.addImport("json", b.createModule(.{
        .root_source_file = b.path("../json/json.zig"),
        .target = target,
        .optimize = optimize,
    }));

    // Build as shared library
    const shared_lib = b.addLibrary(.{
        .name = "microcharm",
        .root_module = lib_mod,
        .linkage = .dynamic,
    });

    // Install the shared library
    b.installArtifact(shared_lib);

    // ========================================================================
    // Unit Tests
    // ========================================================================

    const bridge_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("bridge.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_bridge_tests = b.addRunArtifact(bridge_tests);

    const test_step = b.step("test", "Run bridge unit tests");
    test_step.dependOn(&run_bridge_tests.step);
}
