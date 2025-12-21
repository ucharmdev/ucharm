const std = @import("std");
const pk = @import("pk");
const c = pk.c;
const runtime = @import("runtime.zig");

fn execSource(source: [:0]const u8, filename: [:0]const u8) !void {
    if (!c.py_exec(source, filename, c.EXEC_MODE, null)) {
        if (c.py_matchexc(c.tp_SystemExit)) {
            const exc_tv: c.py_TValue = c.py_retval().*;
            // Clear the pending exception before calling back into PocketPy APIs.
            // In debug builds, PocketPy aborts if any VM call is made while an exception is set.
            c.py_clearexc(null);
            c.py_r0().* = exc_tv;

            var exit_code: i32 = 0;

            if (!c.py_getattr(c.py_r0(), c.py_name("args"))) {
                c.py_printexc();
                return error.PocketPyExecFailed;
            }

            const args_val = c.py_retval();
            if (c.py_istuple(args_val) and c.py_tuple_len(args_val) > 0) {
                const arg0 = c.py_tuple_getitem(args_val, 0);
                if (c.py_isnone(arg0)) {
                    exit_code = 0;
                } else if (c.py_isint(arg0)) {
                    exit_code = @intCast(c.py_toint(arg0));
                } else {
                    if (!c.py_str(arg0)) {
                        c.py_printexc();
                        return error.PocketPyExecFailed;
                    }
                    const msg_sv = c.py_tosv(c.py_retval());
                    std.debug.print("{s}\n", .{msg_sv.data[0..@intCast(msg_sv.size)]});
                    exit_code = 1;
                }
            }

            const exit_u8: u8 = if (exit_code >= 0 and exit_code <= 255) @intCast(exit_code) else 1;
            std.process.exit(exit_u8);
        }
        c.py_printexc();
        return error.PocketPyExecFailed;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    c.py_initialize();
    defer c.py_finalize();

    runtime.registerAll();

    // Parse arguments: support -c "code" or script.py
    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "-c")) {
            // -c "code" mode
            if (args.len < 3) {
                std.debug.print("error: -c requires an argument\n", .{});
                return error.MissingArgument;
            }

            // Set sys.argv to remaining args after code
            var argv_z = try arena_alloc.alloc([*:0]u8, args.len - 2);
            argv_z[0] = try arena_alloc.dupeZ(u8, "-c");
            for (args[3..], 1..) |arg, i| {
                argv_z[i] = try arena_alloc.dupeZ(u8, arg);
            }
            c.py_sys_setargv(@intCast(argv_z.len), @ptrCast(argv_z.ptr));

            const code = args[2];
            const code_z = try allocator.dupeZ(u8, code);
            defer allocator.free(code_z);

            try execSource(code_z, "<string>");
        } else {
            // Script mode
            const script_path = args[1];

            var argv_z = try arena_alloc.alloc([*:0]u8, args.len - 1);
            for (args[1..], 0..) |arg, i| {
                argv_z[i] = try arena_alloc.dupeZ(u8, arg);
            }
            c.py_sys_setargv(@intCast(argv_z.len), @ptrCast(argv_z.ptr));

            const source = std.fs.cwd().readFileAlloc(allocator, script_path, 1024 * 1024) catch |err| {
                std.debug.print("error: cannot read '{s}': {}\n", .{ script_path, err });
                return err;
            };
            defer allocator.free(source);

            const source_z = try allocator.dupeZ(u8, source);
            defer allocator.free(source_z);
            const filename_z = try allocator.dupeZ(u8, script_path);
            defer allocator.free(filename_z);

            c.py_newstr(c.py_r0(), filename_z);
            c.py_setglobal(c.py_name("__file__"), c.py_r0());

            try execSource(source_z, filename_z);
        }
    } else {
        // No arguments - show usage
        std.debug.print("Usage: pocketpy-ucharm [-c code | script.py] [args...]\n", .{});
    }
}
