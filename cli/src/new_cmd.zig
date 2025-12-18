const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const io = @import("io.zig");
const project = @import("project.zig");

const logo =
    \\ 
    \\[36m┌┬┐┌─┐┬ ┬┌─┐┬─┐┌┬┐[0m
    \\[36m││││  ├─┤├─┤├┬┘│││[0m
    \\[36m┴ ┴└─┘┴ ┴┴ ┴┴└─┴ ┴[0m
    \\[2mBeautiful CLIs with MicroPython[0m
    \\
    \\
;

const help_text =
    \\[1mucharm new[0m - Create a new ucharm project
    \\
    \\[2mUSAGE:[0m
    \\    ucharm new <name> [options]
    \\
    \\[2mARGUMENTS:[0m
    \\    <name>           Project name (creates <name>/ directory)
    \\
    \\[2mOPTIONS:[0m
    \\    --stubs          Add type stubs for IDE autocomplete
    \\    --ai <type>      Add AI assistant instructions
    \\                     Types: agents, claude, copilot, all
    \\    --all            Add stubs and AI instructions (agents + claude)
    \\    --minimal        Just create the .py file (no directory)
    \\    -h, --help       Show this help
    \\
    \\[2mEXAMPLES:[0m
    \\    ucharm new myapp
    \\    ucharm new myapp --all
    \\    ucharm new myapp --stubs --ai claude
    \\    ucharm new myapp --minimal
    \\
    \\[2mFILES CREATED:[0m
    \\    myapp/
    \\      myapp.py                       Main application file
    \\      .ucharm/stubs/                 Type stubs (with --stubs)
    \\      pyrightconfig.json             Pyright config (with --stubs)
    \\      AGENTS.md                      AI instructions (with --ai)
    \\
;

pub fn run(allocator: Allocator, args: []const [:0]const u8) !void {
    var options = project.Options{
        .create_app = true,
    };
    var name: ?[]const u8 = null;
    var minimal = false;

    // Parse args
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            _ = io.stdout().write(help_text) catch {};
            return;
        } else if (std.mem.eql(u8, arg, "--stubs")) {
            options.add_stubs = true;
        } else if (std.mem.eql(u8, arg, "--ai")) {
            i += 1;
            if (i >= args.len) {
                io.eprint("\x1b[31mError:\x1b[0m --ai requires a type (agents, claude, copilot, all)\n", .{});
                std.process.exit(1);
            }
            options.ai_type = args[i];
        } else if (std.mem.eql(u8, arg, "--all")) {
            options.add_stubs = true;
            options.ai_type = "all";
        } else if (std.mem.eql(u8, arg, "--minimal")) {
            minimal = true;
        } else if (arg[0] != '-') {
            name = arg;
        }
    }

    // Check for project name
    if (name == null) {
        io.eprint("\x1b[31mError:\x1b[0m No project name specified\n", .{});
        io.eprint("Usage: ucharm new <name>\n", .{});
        std.process.exit(1);
    }

    options.app_name = name;

    // Print logo
    _ = io.stdout().write(logo) catch {};
    io.print("Creating new project: \x1b[1m{s}\x1b[0m\n\n", .{name.?});

    if (minimal) {
        // Just create the .py file in current directory
        _ = project.init(null, options) catch |err| {
            io.eprint("\x1b[31mError:\x1b[0m Failed to create project: {}\n", .{err});
            std.process.exit(1);
        };
    } else {
        // Create project directory
        const project_name = name.?;

        // Convert to directory name (lowercase, underscores)
        var dirname_buf: [256]u8 = undefined;
        var dirname_len: usize = 0;
        for (project_name) |c| {
            if (c == ' ' or c == '-') {
                dirname_buf[dirname_len] = '_';
            } else if (c >= 'A' and c <= 'Z') {
                dirname_buf[dirname_len] = c + 32;
            } else {
                dirname_buf[dirname_len] = c;
            }
            dirname_len += 1;
            if (dirname_len >= dirname_buf.len - 1) break;
        }
        const dirname = dirname_buf[0..dirname_len];

        // Create and open directory
        fs.cwd().makeDir(dirname) catch |err| {
            if (err == error.PathAlreadyExists) {
                io.eprint("\x1b[31mError:\x1b[0m Directory '{s}' already exists\n", .{dirname});
                std.process.exit(1);
            }
            io.eprint("\x1b[31mError:\x1b[0m Failed to create directory: {}\n", .{err});
            std.process.exit(1);
        };

        var dir = fs.cwd().openDir(dirname, .{}) catch |err| {
            io.eprint("\x1b[31mError:\x1b[0m Failed to open directory: {}\n", .{err});
            std.process.exit(1);
        };
        defer dir.close();

        io.print("\x1b[32m+\x1b[0m Created {s}/\n", .{dirname});

        // Initialize project in the new directory
        _ = project.init(dir, options) catch |err| {
            io.eprint("\x1b[31mError:\x1b[0m Failed to initialize project: {}\n", .{err});
            std.process.exit(1);
        };

        // Print next steps
        io.print("\n\x1b[32mDone!\x1b[0m Project created.\n\n", .{});
        io.print("Next steps:\n", .{});
        io.print("  \x1b[36mcd {s}\x1b[0m\n", .{dirname});
        io.print("  \x1b[36mucharm run {s}.py\x1b[0m\n\n", .{dirname});
        io.print("Build standalone binary:\n", .{});
        io.print("  \x1b[36mucharm build {s}.py -o {s} --mode universal\x1b[0m\n", .{ dirname, dirname });
    }

    _ = allocator;
}
