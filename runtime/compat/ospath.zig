const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn isSeparator(ch: u8) bool {
    return ch == '/' or ch == '\\';
}

fn isAbsPath(path: []const u8) bool {
    if (path.len == 0) return false;
    if (isSeparator(path[0])) return true;
    if (path.len > 1 and path[1] == ':') return true;
    return false;
}

fn makeString(view: []const u8) void {
    const sv = c.c11_sv{ .data = view.ptr, .size = @intCast(view.len) };
    c.py_newstrv(c.py_retval(), sv);
}

fn join(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2 and argc != 3) {
        return c.py_exception(c.tp_TypeError, "expected 2 or 3 arguments");
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var out = std.ArrayList(u8).empty;

    var i: c_int = 0;
    while (i < argc) : (i += 1) {
        const part_val = pk.argRef(argv, @intCast(i));
        if (c.py_isnone(part_val)) continue;
        const part_c = c.py_tostr(part_val);
        if (part_c == null) {
            return c.py_exception(c.tp_TypeError, "path must be a string");
        }
        const part = std.mem.span(part_c);
        if (isAbsPath(part)) {
            out.clearRetainingCapacity();
        }

        if (out.items.len > 0 and part.len > 0) {
            if (!isSeparator(out.items[out.items.len - 1]) and !isSeparator(part[0])) {
                out.append(arena_alloc, '/') catch {
                    return c.py_exception(c.tp_RuntimeError, "out of memory");
                };
            }
        }
        out.appendSlice(arena_alloc, part) catch {
            return c.py_exception(c.tp_RuntimeError, "out of memory");
        };
    }

    makeString(out.items);
    return true;
}

fn exists(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);
    const ok = (std.fs.cwd().statFile(path)) catch null;
    c.py_newbool(c.py_retval(), ok != null);
    return true;
}

fn isdir(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);
    var dir = std.fs.cwd().openDir(path, .{}) catch {
        c.py_newbool(c.py_retval(), false);
        return true;
    };
    dir.close();
    c.py_newbool(c.py_retval(), true);
    return true;
}

fn isfile(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);
    const st = std.fs.cwd().statFile(path) catch {
        c.py_newbool(c.py_retval(), false);
        return true;
    };
    c.py_newbool(c.py_retval(), st.kind == .file);
    return true;
}

fn basename(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);
    if (path.len == 0) {
        makeString("");
        return true;
    }
    if (isSeparator(path[path.len - 1])) {
        makeString("");
        return true;
    }
    var i = path.len;
    while (i > 0) : (i -= 1) {
        if (isSeparator(path[i - 1])) break;
    }
    const start = if (i == 0) 0 else i;
    makeString(path[start..]);
    return true;
}

fn dirname(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);
    if (path.len == 0) {
        makeString("");
        return true;
    }
    var end = path.len;
    while (end > 1 and isSeparator(path[end - 1])) : (end -= 1) {}
    var i = end;
    while (i > 0) : (i -= 1) {
        if (isSeparator(path[i - 1])) break;
    }
    if (i == 0) {
        makeString("");
        return true;
    }
    const sep_index = i - 1;
    if (sep_index == 0) {
        makeString(path[0..1]);
        return true;
    }
    makeString(path[0..sep_index]);
    return true;
}

fn split(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);
    var dir_part: []const u8 = path;
    var base_part: []const u8 = path;
    if (path.len == 0) {
        dir_part = "";
        base_part = "";
    } else if (isSeparator(path[path.len - 1])) {
        dir_part = path[0 .. path.len - 1];
        base_part = "";
    } else {
        var i = path.len;
        while (i > 0) : (i -= 1) {
            if (isSeparator(path[i - 1])) break;
        }
        if (i == 0) {
            dir_part = "";
            base_part = path;
        } else {
            const sep_index = i - 1;
            if (sep_index == 0) {
                dir_part = path[0..1];
            } else {
                dir_part = path[0..sep_index];
            }
            base_part = path[i..];
        }
    }

    _ = c.py_newtuple(c.py_retval(), 2);
    const tup = c.py_retval();
    const dir_sv = c.c11_sv{ .data = dir_part.ptr, .size = @intCast(dir_part.len) };
    c.py_newstrv(c.py_r0(), dir_sv);
    c.py_tuple_setitem(tup, 0, c.py_r0());
    const base_sv = c.c11_sv{ .data = base_part.ptr, .size = @intCast(base_part.len) };
    c.py_newstrv(c.py_r0(), base_sv);
    c.py_tuple_setitem(tup, 1, c.py_r0());
    return true;
}

fn splitext(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);
    var sep_index: usize = 0;
    var i = path.len;
    while (i > 0) : (i -= 1) {
        if (isSeparator(path[i - 1])) {
            sep_index = i;
            break;
        }
    }
    var dot_index: ?usize = null;
    i = path.len;
    while (i > sep_index) : (i -= 1) {
        if (path[i - 1] == '.') {
            dot_index = i - 1;
            break;
        }
    }
    var root: []const u8 = path;
    var ext: []const u8 = "";
    if (dot_index) |idx| {
        if (idx > sep_index) {
            root = path[0..idx];
            ext = path[idx..];
        }
    }

    _ = c.py_newtuple(c.py_retval(), 2);
    const tup = c.py_retval();
    const root_sv = c.c11_sv{ .data = root.ptr, .size = @intCast(root.len) };
    c.py_newstrv(c.py_r0(), root_sv);
    c.py_tuple_setitem(tup, 0, c.py_r0());
    const ext_sv = c.c11_sv{ .data = ext.ptr, .size = @intCast(ext.len) };
    c.py_newstrv(c.py_r0(), ext_sv);
    c.py_tuple_setitem(tup, 1, c.py_r0());
    return true;
}

fn isabs(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);
    c.py_newbool(c.py_retval(), isAbsPath(path));
    return true;
}

fn abspath(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);
    const resolved = std.fs.cwd().realpathAlloc(std.heap.page_allocator, path) catch {
        return c.py_exception(c.tp_OSError, "abspath failed");
    };
    defer std.heap.page_allocator.free(resolved);
    makeString(resolved);
    return true;
}

fn normpath(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }
    const path_c = c.py_tostr(pk.argRef(argv, 0));
    if (path_c == null) {
        return c.py_exception(c.tp_TypeError, "path must be a string");
    }
    const path = std.mem.span(path_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var parts = std.ArrayList([]const u8).empty;
    var it = std.mem.splitAny(u8, path, "/\\");
    while (it.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) continue;
        if (std.mem.eql(u8, segment, "..")) {
            if (parts.items.len > 0) {
                _ = parts.pop();
            } else {
                parts.append(arena_alloc, segment) catch {
                    return c.py_exception(c.tp_RuntimeError, "out of memory");
                };
            }
            continue;
        }
        parts.append(arena_alloc, segment) catch {
            return c.py_exception(c.tp_RuntimeError, "out of memory");
        };
    }

    var out = std.ArrayList(u8).empty;
    if (isAbsPath(path)) {
        out.append(arena_alloc, '/') catch {
            return c.py_exception(c.tp_RuntimeError, "out of memory");
        };
    }
    for (parts.items, 0..) |segment, idx| {
        if (idx > 0) {
            out.append(arena_alloc, '/') catch {
                return c.py_exception(c.tp_RuntimeError, "out of memory");
            };
        }
        out.appendSlice(arena_alloc, segment) catch {
            return c.py_exception(c.tp_RuntimeError, "out of memory");
        };
    }
    if (out.items.len == 0) {
        out.appendSlice(arena_alloc, ".") catch {
            return c.py_exception(c.tp_RuntimeError, "out of memory");
        };
    }

    makeString(out.items);
    return true;
}

pub fn register() void {
    const os_name: [:0]const u8 = "os";
    const os_mod = c.py_getmodule(os_name) orelse c.py_newmodule(os_name);

    const path_name: [:0]const u8 = "os.path";
    const path_mod = c.py_getmodule(path_name) orelse c.py_newmodule(path_name);
    c.py_setdict(os_mod, c.py_name("path"), path_mod);

    c.py_bind(path_mod, "join(a, b, c=None)", join);
    c.py_bind(path_mod, "exists(path)", exists);
    c.py_bind(path_mod, "isdir(path)", isdir);
    c.py_bind(path_mod, "isfile(path)", isfile);
    c.py_bind(path_mod, "basename(path)", basename);
    c.py_bind(path_mod, "dirname(path)", dirname);
    c.py_bind(path_mod, "split(path)", split);
    c.py_bind(path_mod, "splitext(path)", splitext);
    c.py_bind(path_mod, "isabs(path)", isabs);
    c.py_bind(path_mod, "abspath(path)", abspath);
    c.py_bind(path_mod, "normpath(path)", normpath);
}
