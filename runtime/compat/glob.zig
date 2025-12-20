const std = @import("std");
const pk = @import("pk");
const c = pk.c;
const fnmatch = @import("mod_fnmatch");

fn globFn(ctx: *pk.Context) bool {
    const pat = ctx.argStr(0) orelse return ctx.typeError("pattern must be a string");
    const recursive = ctx.argBool(3) orelse false;

    c.py_newlist(c.py_retval());
    const out = c.py_retval();

    const sep: u8 = std.fs.path.sep;
    if (recursive and std.mem.indexOf(u8, pat, "**") != null) {
        const idx = std.mem.indexOf(u8, pat, "**").?;
        var base = pat[0..idx];
        while (base.len > 0 and base[base.len - 1] == sep) {
            base = base[0 .. base.len - 1];
        }
        var tail = pat[idx + 2 ..];
        while (tail.len > 0 and tail[0] == sep) {
            tail = tail[1..];
        }
        const name_pat = if (std.mem.lastIndexOfScalar(u8, tail, sep)) |p| tail[p + 1 ..] else tail;

        var dir = std.fs.cwd().openDir(if (base.len == 0) "." else base, .{ .iterate = true }) catch {
            return ctx.runtimeError("failed to open directory");
        };
        defer dir.close();

        var walker = dir.walk(std.heap.page_allocator) catch {
            return ctx.runtimeError("failed to walk directory");
        };
        defer walker.deinit();

        while (true) {
            const entry = walker.next() catch {
                return ctx.runtimeError("failed to walk directory");
            };
            if (entry == null) break;
            if (entry.?.kind != .file) continue;
            const rel = entry.?.path;
            const base_name = if (std.mem.lastIndexOfScalar(u8, rel, sep)) |p| rel[p + 1 ..] else rel;
            if (!fnmatch.match(name_pat, base_name)) continue;

            var buf: [512]u8 = undefined;
            const full = if (base.len == 0)
                std.fmt.bufPrint(&buf, "{s}", .{rel})
            else
                std.fmt.bufPrint(&buf, "{s}{c}{s}", .{ base, sep, rel });
            if (full) |slice| {
                const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
                c.py_newstrv(c.py_r0(), sv);
                c.py_list_append(out, c.py_r0());
            } else |_| {}
        }
        return true;
    }

    var dir_path: []const u8 = ".";
    var pattern = pat;
    if (std.mem.lastIndexOfScalar(u8, pat, sep)) |pos| {
        dir_path = pat[0..pos];
        pattern = pat[pos + 1 ..];
        if (dir_path.len == 0) dir_path = "/";
    }

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch {
        return ctx.runtimeError("failed to open directory");
    };
    defer dir.close();

    var it = dir.iterate();
    while (true) {
        const entry = it.next() catch {
            return ctx.runtimeError("failed to read directory");
        };
        if (entry == null) break;
        const name = entry.?.name;
        if (fnmatch.match(pattern, name)) {
            var buf: [512]u8 = undefined;
            const full = std.fmt.bufPrint(&buf, "{s}{c}{s}", .{ dir_path, sep, name }) catch {
                continue;
            };
            const sv = c.c11_sv{ .data = full.ptr, .size = @intCast(full.len) };
            c.py_newstrv(c.py_r0(), sv);
            c.py_list_append(out, c.py_r0());
        }
    }
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("glob");
    _ = builder.funcWrapped("glob", 1, 4, globFn);
}
