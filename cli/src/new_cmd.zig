const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const io = @import("io.zig");
const style = io.style;
const project = @import("project.zig");

const logo =
    "\n" ++
    style.cyan ++ "┌┬┐┌─┐┬ ┬┌─┐┬─┐┌┬┐" ++ style.reset ++ "\n" ++
    style.cyan ++ "││││  ├─┤├─┤├┬┘│││" ++ style.reset ++ "\n" ++
    style.cyan ++ "┴ ┴└─┘┴ ┴┴ ┴┴└─┴ ┴" ++ style.reset ++ "\n" ++
    style.dim ++ "Beautiful CLIs with MicroPython" ++ style.reset ++ "\n" ++
    "\n";

const help_text =
    style.bold ++ "ucharm new" ++ style.reset ++ " - Create a new ucharm project\n" ++
    "\n" ++
    style.dim ++ "USAGE:" ++ style.reset ++ "\n" ++
    "    ucharm new <name> [options]\n" ++
    "\n" ++
    style.dim ++ "ARGUMENTS:" ++ style.reset ++ "\n" ++
    "    <name>           Project name (creates <name>/ directory)\n" ++
    "\n" ++
    style.dim ++ "OPTIONS:" ++ style.reset ++ "\n" ++
    "    --stubs          Add type stubs for IDE autocomplete\n" ++
    "    --ai <type>      Add AI assistant instructions\n" ++
    "                     Types: agents, claude, copilot, all\n" ++
    "    --all            Add stubs and AI instructions (agents + claude)\n" ++
    "    --minimal        Just create the .py file (no directory)\n" ++
    "    -h, --help       Show this help\n" ++
    "\n" ++
    style.dim ++ "EXAMPLES:" ++ style.reset ++ "\n" ++
    "    ucharm new myapp\n" ++
    "    ucharm new myapp --all\n" ++
    "    ucharm new myapp --stubs --ai claude\n" ++
    "    ucharm new myapp --minimal\n" ++
    "\n" ++
    style.dim ++ "FILES CREATED:" ++ style.reset ++ "\n" ++
    "    myapp/\n" ++
    "      myapp.py                       Main application file\n" ++
    "      .ucharm/stubs/                 Type stubs (with --stubs)\n" ++
    "      pyrightconfig.json             Pyright config (with --stubs)\n" ++
    "      AGENTS.md                      AI instructions (with --ai)\n";

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
                io.eprint(style.err_prefix ++ "--ai requires a type (agents, claude, copilot, all)\n", .{});
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
        io.eprint(style.err_prefix ++ "No project name specified\n", .{});
        io.eprint(style.dim ++ "Usage: " ++ style.reset ++ "ucharm new <name>\n", .{});
        std.process.exit(1);
    }

    options.app_name = name;

    // Print logo
    _ = io.stdout().write(logo) catch {};
    io.print("Creating new project: " ++ style.bold ++ "{s}" ++ style.reset ++ "\n\n", .{name.?});

    if (minimal) {
        // Just create the .py file in current directory
        _ = project.init(null, options) catch |err| {
            io.eprint(style.err_prefix ++ "Failed to create project: {}\n", .{err});
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
                io.eprint(style.err_prefix ++ "Directory '{s}' already exists\n", .{dirname});
                std.process.exit(1);
            }
            io.eprint(style.err_prefix ++ "Failed to create directory: {}\n", .{err});
            std.process.exit(1);
        };

        var dir = fs.cwd().openDir(dirname, .{}) catch |err| {
            io.eprint(style.err_prefix ++ "Failed to open directory: {}\n", .{err});
            std.process.exit(1);
        };
        defer dir.close();

        io.print(style.created_prefix ++ "Created {s}/\n", .{dirname});

        // Initialize project in the new directory
        _ = project.init(dir, options) catch |err| {
            io.eprint(style.err_prefix ++ "Failed to initialize project: {}\n", .{err});
            std.process.exit(1);
        };

        // Print next steps
        io.print("\n" ++ style.success ++ "Done!" ++ style.reset ++ " Project created.\n\n", .{});
        io.print(style.bold ++ "Next steps:\n" ++ style.reset, .{});
        io.print("  " ++ style.dim ++ "$" ++ style.reset ++ " " ++ style.brand ++ "cd {s}" ++ style.reset ++ "\n", .{dirname});
        io.print("  " ++ style.dim ++ "$" ++ style.reset ++ " " ++ style.brand ++ "ucharm run {s}.py" ++ style.reset ++ "\n\n", .{dirname});
        io.print(style.bold ++ "Build standalone binary:\n" ++ style.reset, .{});
        io.print("  " ++ style.dim ++ "$" ++ style.reset ++ " " ++ style.brand ++ "ucharm build {s}.py -o {s} --mode universal" ++ style.reset ++ "\n", .{ dirname, dirname });
    }

    _ = allocator;
}
