const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create io module that all commands will use
    const io_mod = b.createModule(.{
        .root_source_file = b.path("src/io.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create command modules with io dependency
    const build_cmd_mod = b.createModule(.{
        .root_source_file = b.path("src/build_cmd.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "io.zig", .module = io_mod },
        },
    });

    const new_cmd_mod = b.createModule(.{
        .root_source_file = b.path("src/new_cmd.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "io.zig", .module = io_mod },
        },
    });

    const run_cmd_mod = b.createModule(.{
        .root_source_file = b.path("src/run_cmd.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "io.zig", .module = io_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "mcharm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "build_cmd.zig", .module = build_cmd_mod },
                .{ .name = "new_cmd.zig", .module = new_cmd_mod },
                .{ .name = "run_cmd.zig", .module = run_cmd_mod },
            },
        }),
    });

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run mcharm");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
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
