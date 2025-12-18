// test_cmd.zig - Run compatibility tests for ucharm modules
//
// Usage:
//   ucharm test --compat           Run all CPython compatibility tests
//   ucharm test --compat --report  Generate compatibility report
//   ucharm test --compat -v        Verbose output with failure details
//   ucharm test <file.py>          Run a specific test file with micropython-ucharm

const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

// I/O helpers
fn stdout() std.fs.File {
    return std.fs.File{ .handle = std.posix.STDOUT_FILENO };
}

fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [8192]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = stdout().write(msg) catch {};
}

fn puts(s: []const u8) void {
    _ = stdout().write(s) catch {};
}

pub fn run(allocator: Allocator, args: []const []const u8) !void {
    var generate_report = false;
    var run_compat = false;
    var verbose = false;
    var test_file: ?[]const u8 = null;
    var module_filter: ?[]const u8 = null;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--compat")) {
            run_compat = true;
        } else if (std.mem.eql(u8, arg, "--report") or std.mem.eql(u8, arg, "-r")) {
            generate_report = true;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--module") or std.mem.eql(u8, arg, "-m")) {
            i += 1;
            if (i < args.len) {
                module_filter = args[i];
            }
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage();
            return;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            test_file = arg;
        }
    }

    if (run_compat) {
        try runCompatTests(allocator, generate_report, verbose, module_filter);
    } else if (test_file) |file| {
        try runSingleTest(allocator, file);
    } else {
        printUsage();
    }
}

fn runCompatTests(allocator: Allocator, generate_report: bool, verbose: bool, module_filter: ?[]const u8) !void {
    // Find the compat_runner.py script
    const runner_path = try findCompatRunner(allocator);
    defer allocator.free(runner_path);

    // Build arguments for the Python runner
    var argv_list: std.ArrayList([]const u8) = .empty;
    defer argv_list.deinit(allocator);

    try argv_list.append(allocator, "python3");
    try argv_list.append(allocator, runner_path);

    if (verbose) {
        try argv_list.append(allocator, "--verbose");
    }

    if (generate_report) {
        try argv_list.append(allocator, "--report");
    }

    if (module_filter) |m| {
        try argv_list.append(allocator, "--module");
        try argv_list.append(allocator, m);
    }

    // Run the Python compat runner
    var child = std.process.Child.init(argv_list.items, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();
    const term = child.wait() catch return error.ProcessFailed;

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.process.exit(code);
            }
        },
        else => std.process.exit(1),
    }
}

fn findCompatRunner(allocator: Allocator) ![]const u8 {
    // Get the directory where ucharm is located
    const self_exe = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(self_exe);

    const dir = std.fs.path.dirname(self_exe) orelse ".";

    // Try relative to ucharm binary (for development)
    // From cli/zig-out/bin/ucharm -> project root -> tests/compat_runner.py
    const dev_path = try std.fs.path.join(allocator, &.{ dir, "..", "..", "..", "tests", "compat_runner.py" });

    if (fs.cwd().access(dev_path, .{})) |_| {
        return dev_path;
    } else |_| {
        allocator.free(dev_path);
    }

    // Try current directory
    const cwd_path = try allocator.dupe(u8, "tests/compat_runner.py");
    if (fs.cwd().access(cwd_path, .{})) |_| {
        return cwd_path;
    } else |_| {
        allocator.free(cwd_path);
    }

    // Error - not found
    puts("\x1b[31mError:\x1b[0m Could not find tests/compat_runner.py\n");
    puts("Make sure you're running from the ucharm repository root.\n");
    std.process.exit(1);
}

fn runSingleTest(allocator: Allocator, test_file: []const u8) !void {
    const micropython_path = try getMicropythonPath(allocator);
    defer allocator.free(micropython_path);

    print("Running {s} with micropython-ucharm...\n\n", .{test_file});

    const argv = [_][]const u8{ micropython_path, test_file };

    var child = std.process.Child.init(&argv, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();
    const term = child.wait() catch return error.ProcessFailed;

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.process.exit(code);
            }
        },
        else => std.process.exit(1),
    }
}

fn getMicropythonPath(allocator: Allocator) ![]const u8 {
    // Get the directory where ucharm is located
    const self_exe = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(self_exe);

    const dir = std.fs.path.dirname(self_exe) orelse ".";

    // Try relative to ucharm binary first (for development)
    // From cli/zig-out/bin/ucharm -> cli/zig-out/bin -> cli/zig-out -> cli -> project root -> native/dist
    const dev_path = try std.fs.path.join(allocator, &.{ dir, "..", "..", "..", "native", "dist", "micropython-ucharm" });

    if (fs.cwd().access(dev_path, .{})) |_| {
        return dev_path;
    } else |_| {
        allocator.free(dev_path);
    }

    // Try in same directory as ucharm
    const local_path = try std.fs.path.join(allocator, &.{ dir, "micropython-ucharm" });

    if (fs.cwd().access(local_path, .{})) |_| {
        return local_path;
    } else |_| {
        allocator.free(local_path);
    }

    // Fallback to PATH
    return try allocator.dupe(u8, "micropython-ucharm");
}

fn printUsage() void {
    puts("\n  \x1b[36m\x1b[1m" ++ "μcharm test" ++ "\x1b[0m - CPython Compatibility Testing\n");
    puts("\n\x1b[1mUsage:\x1b[0m ucharm test [options] [file]\n");
    puts("\n\x1b[1mOptions:\x1b[0m\n");
    puts("  --compat        Run full CPython compatibility test suite\n");
    puts("  --report, -r    Generate compat_report.md\n");
    puts("  --verbose, -v   Show failure details\n");
    puts("  --module, -m    Test only specified module\n");
    puts("  -h, --help      Show this help\n");
    puts("\n\x1b[1mExamples:\x1b[0m\n");
    puts("  \x1b[2m$\x1b[0m ucharm test --compat              \x1b[2m# Full compatibility suite\x1b[0m\n");
    puts("  \x1b[2m$\x1b[0m ucharm test --compat --report     \x1b[2m# Generate markdown report\x1b[0m\n");
    puts("  \x1b[2m$\x1b[0m ucharm test --compat -m functools \x1b[2m# Test single module\x1b[0m\n");
    puts("  \x1b[2m$\x1b[0m ucharm test mytest.py             \x1b[2m# Run with micropython-ucharm\x1b[0m\n");
    puts("\n\x1b[1mAbout:\x1b[0m\n");
    puts("  Tests μcharm's compatibility with CPython standard library.\n");
    puts("  Runs each test file with both CPython and micropython-ucharm,\n");
    puts("  comparing results to calculate compatibility percentages.\n\n");
}
