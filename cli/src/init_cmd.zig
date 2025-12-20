const std = @import("std");
const Allocator = std.mem.Allocator;
const io = @import("io.zig");
const style = io.style;
const project = @import("project.zig");

const help_text =
    style.bold ++ "ucharm init" ++ style.reset ++ " - Initialize ucharm in current directory\n" ++
    "\n" ++
    style.dim ++ "USAGE:" ++ style.reset ++ "\n" ++
    "    ucharm init [options]\n" ++
    "\n" ++
    style.dim ++ "OPTIONS:" ++ style.reset ++ "\n" ++
    "    --stubs          Add type stubs for IDE autocomplete\n" ++
    "    --ai <type>      Add AI assistant instructions\n" ++
    "                     Types: agents, claude, copilot, all\n" ++
    "    --all            Add both stubs and AI instructions (agents + claude)\n" ++
    "    -h, --help       Show this help\n" ++
    "\n" ++
    style.dim ++ "EXAMPLES:" ++ style.reset ++ "\n" ++
    "    ucharm init --stubs\n" ++
    "    ucharm init --ai agents\n" ++
    "    ucharm init --all\n" ++
    "\n" ++
    style.dim ++ "FILES CREATED:" ++ style.reset ++ "\n" ++
    "    .ucharm/stubs/                   Type stubs for runtime modules\n" ++
    "    pyrightconfig.json               Pyright configuration\n" ++
    "    AGENTS.md                        Universal (Cursor, Windsurf, Zed)\n" ++
    "    CLAUDE.md                        Claude Code\n" ++
    "    .github/copilot-instructions.md  GitHub Copilot\n";

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
                io.eprint(style.err_prefix ++ "--ai requires a type (agents, claude, copilot, all)\n", .{});
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
        io.print(style.warning ++ "No options specified." ++ style.reset ++ " Use --stubs, --ai, or --all\n\n", .{});
        _ = io.stdout().write(help_text) catch {};
        return;
    }

    // Initialize in current directory
    const files_created = project.init(null, options) catch |err| {
        io.eprint(style.err_prefix ++ "Failed to initialize: {}\n", .{err});
        std.process.exit(1);
    };

    io.print("\n" ++ style.success ++ "Done!" ++ style.reset ++ " Initialized ucharm in current directory.\n", .{});

    if (options.add_stubs and files_created > 0) {
        io.print("\n" ++ style.dim ++ "IDE autocomplete should now work for ucharm modules." ++ style.reset ++ "\n", .{});
    }

    _ = allocator;
}
