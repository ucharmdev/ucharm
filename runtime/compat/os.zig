const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn getcwdFn(ctx: *pk.Context) bool {
    const cwd = std.fs.cwd().realpathAlloc(std.heap.page_allocator, ".") catch {
        return c.py_exception(c.tp_OSError, "getcwd failed");
    };
    defer std.heap.page_allocator.free(cwd);
    return ctx.returnStr(cwd);
}

fn mkdirFn(ctx: *pk.Context) bool {
    const path = ctx.argStr(0) orelse return ctx.typeError("path must be a string");
    std.fs.cwd().makeDir(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return c.py_exception(c.tp_OSError, "mkdir failed"),
    };
    return ctx.returnNone();
}

fn listdirFn(ctx: *pk.Context) bool {
    const path = ctx.argStr(0) orelse return ctx.typeError("path must be a string");
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
        return c.py_exception(c.tp_OSError, "listdir failed");
    };
    defer dir.close();

    c.py_newlist(c.py_retval());
    const out = c.py_retval();

    var it = dir.iterate();
    while (true) {
        const entry = it.next() catch {
            return c.py_exception(c.tp_OSError, "listdir failed");
        };
        if (entry == null) break;
        const name = entry.?.name;
        const sv_name = c.c11_sv{ .data = name.ptr, .size = @intCast(name.len) };
        c.py_newstrv(c.py_r0(), sv_name);
        c.py_list_append(out, c.py_r0());
    }
    return true;
}

fn removeFn(ctx: *pk.Context) bool {
    const path = ctx.argStr(0) orelse return ctx.typeError("path must be a string");
    std.fs.cwd().deleteFile(path) catch {
        return c.py_exception(c.tp_OSError, "remove failed");
    };
    return ctx.returnNone();
}

fn rmdirFn(ctx: *pk.Context) bool {
    const path = ctx.argStr(0) orelse return ctx.typeError("path must be a string");
    std.fs.cwd().deleteDir(path) catch {
        return c.py_exception(c.tp_OSError, "rmdir failed");
    };
    return ctx.returnNone();
}

fn getenvFn(ctx: *pk.Context) bool {
    const key = ctx.argStr(0) orelse return ctx.typeError("key must be a string");
    const value = std.process.getEnvVarOwned(std.heap.page_allocator, key) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            if (ctx.argCount() >= 2) {
                const default_arg = ctx.arg(1) orelse return ctx.returnNone();
                return ctx.returnValue(default_arg);
            } else {
                return ctx.returnNone();
            }
        },
        else => return c.py_exception(c.tp_OSError, "getenv failed"),
    };
    defer std.heap.page_allocator.free(value);
    return ctx.returnStr(value);
}

fn statFn(ctx: *pk.Context) bool {
    const path = ctx.argStr(0) orelse return ctx.typeError("path must be a string");
    const st = std.fs.cwd().statFile(path) catch {
        return c.py_exception(c.tp_OSError, "stat failed");
    };

    _ = c.py_newtuple(c.py_retval(), 7);
    const tup = c.py_retval();
    c.py_newint(c.py_r0(), @intCast(st.mode));
    c.py_tuple_setitem(tup, 0, c.py_r0());
    c.py_newint(c.py_r0(), 0);
    c.py_tuple_setitem(tup, 1, c.py_r0());
    c.py_newint(c.py_r0(), 0);
    c.py_tuple_setitem(tup, 2, c.py_r0());
    c.py_newint(c.py_r0(), 0);
    c.py_tuple_setitem(tup, 3, c.py_r0());
    c.py_newint(c.py_r0(), 0);
    c.py_tuple_setitem(tup, 4, c.py_r0());
    c.py_newint(c.py_r0(), 0);
    c.py_tuple_setitem(tup, 5, c.py_r0());
    c.py_newint(c.py_r0(), @intCast(st.size));
    c.py_tuple_setitem(tup, 6, c.py_r0());
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.extend("os") orelse pk.ModuleBuilder.new("os");

    _ = builder
        .funcWrapped("getcwd", 0, 0, getcwdFn)
        .funcWrapped("mkdir", 1, 1, mkdirFn)
        .funcWrapped("listdir", 1, 1, listdirFn)
        .funcWrapped("remove", 1, 1, removeFn)
        .funcWrapped("rmdir", 1, 1, rmdirFn)
        .funcWrapped("unlink", 1, 1, removeFn)
        .funcWrapped("getenv", 1, 2, getenvFn)
        .funcWrapped("stat", 1, 1, statFn)
        .constStr("sep", "/");

    const os_name = @import("builtin").target.os.tag;
    const os_name_str: [:0]const u8 = switch (os_name) {
        .windows => "nt",
        else => "posix",
    };
    _ = builder.constStr("name", os_name_str);

    const linesep: [:0]const u8 = if (os_name == .windows) "\r\n" else "\n";
    _ = builder.constStr("linesep", linesep);

    c.py_newdict(c.py_r0());
    const env_dict = c.py_r0();
    if (std.process.getEnvMap(std.heap.page_allocator)) |env_map| {
        var map = env_map;
        defer map.deinit();
        var it = map.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            const key_sv = c.c11_sv{ .data = key.ptr, .size = @intCast(key.len) };
            const value_sv = c.c11_sv{ .data = value.ptr, .size = @intCast(value.len) };
            c.py_newstrv(c.py_r1(), key_sv);
            c.py_newstrv(c.py_r2(), value_sv);
            _ = c.py_dict_setitem(env_dict, c.py_r1(), c.py_r2());
        }
    } else |_| {}
    c.py_setdict(builder.module, c.py_name("environ"), env_dict);

    const ospath = c.py_getmodule("os.path") orelse c.py_newmodule("os.path");
    c.py_setdict(builder.module, c.py_name("path"), ospath);
}
