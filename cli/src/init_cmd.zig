const std = @import("std");
const Allocator = std.mem.Allocator;
const io = @import("io.zig");
const project = @import("project.zig");

const help_text =
    \\[1mucharm init[0m - Initialize ucharm in current directory
    \\
    \\[2mUSAGE:[0m
    \\    ucharm init [options]
    \\
    \\[2mOPTIONS:[0m
    \\    --stubs          Add type stubs for IDE autocomplete
    \\    --ai <type>      Add AI assistant instructions
    \\                     Types: agents, claude, copilot, all
    \\    --all            Add both stubs and AI instructions (agents + claude)
    \\    -h, --help       Show this help
    \\
    \\[2mEXAMPLES:[0m
    \\    ucharm init --stubs
    \\    ucharm init --ai agents
    \\    ucharm init --all
    \\
    \\[2mFILES CREATED:[0m
    \\    .ucharm/stubs/                   Type stubs for 24 native modules
    \\    pyrightconfig.json               Pyright configuration
    \\    AGENTS.md                        Universal (Cursor, Windsurf, Zed)
    \\    CLAUDE.md                        Claude Code
    \\    .github/copilot-instructions.md  GitHub Copilot
    \\
;

pub fn run(allocator: Allocator, args: []const [:0]const u8) !void {
    var options = project.Options{};

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
        }
    }

    // If no options, show help
    if (!options.add_stubs and options.ai_type == null) {
        io.print("\x1b[33mNo options specified.\x1b[0m Use --stubs, --ai, or --all\n\n", .{});
        _ = io.stdout().write(help_text) catch {};
        return;
    }

    // Initialize in current directory
    const files_created = project.init(null, options) catch |err| {
        io.eprint("\x1b[31mError:\x1b[0m Failed to initialize: {}\n", .{err});
        std.process.exit(1);
    };

    io.print("\n\x1b[32mDone!\x1b[0m Initialized ucharm in current directory.\n", .{});

    if (options.add_stubs and files_created > 0) {
        io.print("\n\x1b[2mIDE autocomplete should now work for ucharm modules.\x1b[0m\n", .{});
    }

    _ = allocator;
}
