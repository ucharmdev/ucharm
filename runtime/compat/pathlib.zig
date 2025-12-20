const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_path: c.py_Type = 0;

fn newPyStrFromSlice(out_ref: c.py_OutRef, s: []const u8) void {
    const buf = c.py_newstrn(out_ref, @intCast(s.len));
    if (s.len > 0) {
        @memcpy(@as([*]u8, @ptrCast(buf))[0..s.len], s);
    }
}

fn normalizePath(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
    if (path.len == 0) return try alloc.dupe(u8, path);
    var trimmed = path;
    if (trimmed.len > 1) {
        while (trimmed.len > 1 and trimmed[trimmed.len - 1] == '/') {
            trimmed = trimmed[0 .. trimmed.len - 1];
        }
    }
    return try alloc.dupe(u8, trimmed);
}

fn joinSegments(alloc: std.mem.Allocator, parts: []const []const u8) ![]u8 {
    if (parts.len == 0) return try alloc.dupe(u8, "");
    var out = std.ArrayList(u8).empty;
    defer out.deinit(alloc);

    var first = true;
    for (parts) |part_raw| {
        const part = part_raw;
        if (first) {
            out.appendSlice(alloc, part) catch return error.OutOfMemory;
            first = false;
            continue;
        }
        var p = part;
        while (p.len > 0 and p[0] == '/') p = p[1..];
        if (out.items.len == 0) {
            out.appendSlice(alloc, p) catch return error.OutOfMemory;
            continue;
        }
        if (out.items[out.items.len - 1] != '/') out.append(alloc, '/') catch return error.OutOfMemory;
        out.appendSlice(alloc, p) catch return error.OutOfMemory;
    }
    return try out.toOwnedSlice(alloc);
}

fn splitName(path: []const u8) []const u8 {
    if (path.len == 0) return path;
    if (std.mem.eql(u8, path, "/")) return "";
    var end = path.len;
    while (end > 1 and path[end - 1] == '/') : (end -= 1) {}
    const p = path[0..end];
    const idx = std.mem.lastIndexOfScalar(u8, p, '/') orelse return p;
    return p[idx + 1 ..];
}

fn parentPath(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
    if (path.len == 0) return try alloc.dupe(u8, ".");
    if (std.mem.eql(u8, path, "/")) return try alloc.dupe(u8, "/");
    var end = path.len;
    while (end > 1 and path[end - 1] == '/') : (end -= 1) {}
    const p = path[0..end];
    const idx_opt = std.mem.lastIndexOfScalar(u8, p, '/');
    if (idx_opt == null) return try alloc.dupe(u8, ".");
    const idx = idx_opt.?;
    if (idx == 0) return try alloc.dupe(u8, "/");
    return try alloc.dupe(u8, p[0..idx]);
}

fn suffixFromName(name: []const u8) []const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, name, '.') orelse return "";
    if (dot == 0) return "";
    return name[dot..];
}

fn stemFromName(name: []const u8) []const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, name, '.') orelse return name;
    if (dot == 0) return name;
    return name[0..dot];
}

fn initPathObject(self: c.py_Ref, path_bytes: []const u8) bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const normalized = normalizePath(alloc, path_bytes) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    newPyStrFromSlice(c.py_r0(), normalized);
    c.py_setdict(self, c.py_name("path"), c.py_r0());

    const name = splitName(normalized);
    newPyStrFromSlice(c.py_r0(), name);
    c.py_setdict(self, c.py_name("name"), c.py_r0());

    const suffix = suffixFromName(name);
    newPyStrFromSlice(c.py_r0(), suffix);
    c.py_setdict(self, c.py_name("suffix"), c.py_r0());

    const stem = stemFromName(name);
    newPyStrFromSlice(c.py_r0(), stem);
    c.py_setdict(self, c.py_name("stem"), c.py_r0());

    const parent_str = parentPath(alloc, normalized) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    if (std.mem.eql(u8, parent_str, normalized)) {
        c.py_setdict(self, c.py_name("parent"), self);
    } else {
        _ = c.py_newobject(c.py_r1(), tp_path, -1, 0);
        c.py_setdict(self, c.py_name("parent"), c.py_r1());
        const parent_val = c.py_getdict(self, c.py_name("parent")) orelse return c.py_exception(c.tp_RuntimeError, "parent missing");
        const parent_obj = parent_val.?;
        if (!initPathObject(parent_obj, parent_str)) return false;
    }
    return true;
}

fn new(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    _ = c.py_newobject(c.py_retval(), tp_path, -1, 0);
    return true;
}

fn init(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var parts = std.ArrayList([]const u8).empty;
    defer parts.deinit(alloc);

    if (argc >= 2 and (c.py_istype(pk.argRef(argv, 1), c.tp_tuple) or c.py_istype(pk.argRef(argv, 1), c.tp_list))) {
        const seq = pk.argRef(argv, 1);
        if (c.py_istype(seq, c.tp_tuple)) {
            const n = c.py_tuple_len(seq);
            var i: c_int = 0;
            while (i < n) : (i += 1) {
                const item = c.py_tuple_getitem(seq, i);
                if (!c.py_checkstr(item)) return false;
                const s = c.py_tostr(item) orelse return c.py_exception(c.tp_TypeError, "path must be a string");
                parts.append(alloc, std.mem.span(s)) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            }
        } else {
            const n = c.py_list_len(seq);
            var i: c_int = 0;
            while (i < n) : (i += 1) {
                const item = c.py_list_getitem(seq, i);
                if (!c.py_checkstr(item)) return false;
                const s = c.py_tostr(item) orelse return c.py_exception(c.tp_TypeError, "path must be a string");
                parts.append(alloc, std.mem.span(s)) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            }
        }
    } else {
        var i: c_int = 1;
        while (i < argc) : (i += 1) {
            const item = pk.argRef(argv, @intCast(i));
            if (!c.py_checkstr(item)) return false;
            const s = c.py_tostr(item) orelse return c.py_exception(c.tp_TypeError, "path must be a string");
            parts.append(alloc, std.mem.span(s)) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        }
    }
    const joined = joinSegments(alloc, parts.items) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    if (!initPathObject(self, joined)) return false;
    c.py_newnone(c.py_retval());
    return true;
}

fn strFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__str__ takes no arguments");
    const self = pk.argRef(argv, 0);
    const path_val = c.py_getdict(self, c.py_name("path")) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path_c = c.py_tostr(path_val.?) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path = std.mem.span(path_c);
    if (path.len == 0) {
        c.py_newstr(c.py_retval(), ".");
        return true;
    }
    c.py_newstr(c.py_retval(), path_c);
    return true;
}

fn reprFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__repr__ takes no arguments");
    if (!strFn(1, argv)) return false;
    const path_c = c.py_tostr(c.py_retval()) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path = std.mem.span(path_c);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const s = std.fmt.allocPrint(arena.allocator(), "Path('{s}')", .{path}) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    newPyStrFromSlice(c.py_retval(), s);
    return true;
}

fn truedivFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "__truediv__ takes 1 argument");
    const self = pk.argRef(argv, 0);
    const other_c = c.py_tostr(pk.argRef(argv, 1)) orelse return c.py_exception(c.tp_TypeError, "path must be a string");
    const other = std.mem.span(other_c);
    const path_val = c.py_getdict(self, c.py_name("path")) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const base_c = c.py_tostr(path_val.?) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const base = std.mem.span(base_c);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const joined = joinSegments(alloc, &[_][]const u8{ base, other }) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    _ = c.py_newobject(c.py_retval(), tp_path, -1, 0);
    if (!initPathObject(c.py_retval(), joined)) return false;
    return true;
}

fn joinpathFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "joinpath() requires at least 1 argument");
    const self = pk.argRef(argv, 0);
    const path_val = c.py_getdict(self, c.py_name("path")) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const base_c = c.py_tostr(path_val.?) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const base = std.mem.span(base_c);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var parts = std.ArrayList([]const u8).empty;
    defer parts.deinit(alloc);
    parts.append(alloc, base) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    var i: c_int = 1;
    while (i < argc) : (i += 1) {
        const seg_c = c.py_tostr(pk.argRef(argv, @intCast(i))) orelse return c.py_exception(c.tp_TypeError, "path must be a string");
        parts.append(alloc, std.mem.span(seg_c)) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    }
    const joined = joinSegments(alloc, parts.items) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    _ = c.py_newobject(c.py_retval(), tp_path, -1, 0);
    if (!initPathObject(c.py_retval(), joined)) return false;
    return true;
}

fn with_nameFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "with_name() takes 1 argument");
    const self = pk.argRef(argv, 0);
    const new_name_c = c.py_tostr(pk.argRef(argv, 1)) orelse return c.py_exception(c.tp_TypeError, "name must be a string");
    const new_name = std.mem.span(new_name_c);
    const parent_val = c.py_getdict(self, c.py_name("parent")) orelse return c.py_exception(c.tp_RuntimeError, "parent missing");
    if (!c.py_str(parent_val.?)) return false;
    const parent_c = c.py_tostr(c.py_retval()) orelse return c.py_exception(c.tp_RuntimeError, "parent missing");
    const parent = std.mem.span(parent_c);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const joined = joinSegments(alloc, &[_][]const u8{ parent, new_name }) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    _ = c.py_newobject(c.py_retval(), tp_path, -1, 0);
    if (!initPathObject(c.py_retval(), joined)) return false;
    return true;
}

fn with_suffixFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "with_suffix() takes 1 argument");
    const self = pk.argRef(argv, 0);
    const suffix_c = c.py_tostr(pk.argRef(argv, 1)) orelse return c.py_exception(c.tp_TypeError, "suffix must be a string");
    const suffix = std.mem.span(suffix_c);
    const path_val = c.py_getdict(self, c.py_name("path")) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path_c = c.py_tostr(path_val.?) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path = std.mem.span(path_c);
    const name = splitName(path);
    const cur_suffix = suffixFromName(name);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var base_no_suffix: []const u8 = path;
    if (cur_suffix.len > 0) {
        base_no_suffix = path[0 .. path.len - cur_suffix.len];
    }
    const new_path = std.fmt.allocPrint(alloc, "{s}{s}", .{ base_no_suffix, suffix }) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    _ = c.py_newobject(c.py_retval(), tp_path, -1, 0);
    if (!initPathObject(c.py_retval(), new_path)) return false;
    return true;
}

fn is_absoluteFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "is_absolute() takes no arguments");
    const self = pk.argRef(argv, 0);
    const path_val = c.py_getdict(self, c.py_name("path")) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path_c = c.py_tostr(path_val.?) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path = std.mem.span(path_c);
    c.py_newbool(c.py_retval(), path.len > 0 and path[0] == '/');
    return true;
}

fn exists(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "exists() takes no arguments");
    const self = pk.argRef(argv, 0);
    const path_val = c.py_getdict(self, c.py_name("path")) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path_c = c.py_tostr(path_val.?) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path = std.mem.span(path_c);
    const ok = std.fs.cwd().statFile(path) catch null;
    c.py_newbool(c.py_retval(), ok != null);
    return true;
}

fn is_fileFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "is_file() takes no arguments");
    const self = pk.argRef(argv, 0);
    const path_val = c.py_getdict(self, c.py_name("path")) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path_c = c.py_tostr(path_val.?) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path = std.mem.span(path_c);
    const st = std.fs.cwd().statFile(path) catch {
        c.py_newbool(c.py_retval(), false);
        return true;
    };
    c.py_newbool(c.py_retval(), st.kind == .file);
    return true;
}

fn is_dirFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "is_dir() takes no arguments");
    const self = pk.argRef(argv, 0);
    const path_val = c.py_getdict(self, c.py_name("path")) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path_c = c.py_tostr(path_val.?) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path = std.mem.span(path_c);
    const st = std.fs.cwd().statFile(path) catch {
        c.py_newbool(c.py_retval(), false);
        return true;
    };
    c.py_newbool(c.py_retval(), st.kind == .directory);
    return true;
}

fn cwdFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 0 and argc != 1) return c.py_exception(c.tp_TypeError, "cwd() takes no arguments");
    _ = argv;
    const cwd = std.fs.cwd().realpathAlloc(std.heap.page_allocator, ".") catch return c.py_exception(c.tp_OSError, "cwd failed");
    defer std.heap.page_allocator.free(cwd);
    _ = c.py_newobject(c.py_retval(), tp_path, -1, 0);
    if (!initPathObject(c.py_retval(), cwd)) return false;
    return true;
}

fn resolveFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "resolve() takes no arguments");
    const self = pk.argRef(argv, 0);
    const path_val = c.py_getdict(self, c.py_name("path")) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path_c = c.py_tostr(path_val.?) orelse return c.py_exception(c.tp_RuntimeError, "path missing");
    const path = std.mem.span(path_c);
    const target = if (path.len == 0) "." else path;
    const resolved = std.fs.cwd().realpathAlloc(std.heap.page_allocator, target) catch return c.py_exception(c.tp_OSError, "resolve failed");
    defer std.heap.page_allocator.free(resolved);
    _ = c.py_newobject(c.py_retval(), tp_path, -1, 0);
    if (!initPathObject(c.py_retval(), resolved)) return false;
    return true;
}

pub fn register() void {
    const name: [:0]const u8 = "pathlib";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);
    tp_path = c.py_newtype("Path", c.tp_object, module, null);

    c.py_bind(c.py_tpobject(tp_path), "__new__(cls, *paths)", new);
    c.py_bind(c.py_tpobject(tp_path), "__init__(self, *paths)", init);
    c.py_bind(c.py_tpobject(tp_path), "__str__(self)", strFn);
    c.py_bind(c.py_tpobject(tp_path), "__repr__(self)", reprFn);
    c.py_bind(c.py_tpobject(tp_path), "__truediv__(self, other)", truedivFn);

    c.py_bindmethod(tp_path, "exists", exists);
    c.py_bindmethod(tp_path, "is_absolute", is_absoluteFn);
    c.py_bindmethod(tp_path, "joinpath", joinpathFn);
    c.py_bindmethod(tp_path, "with_name", with_nameFn);
    c.py_bindmethod(tp_path, "with_suffix", with_suffixFn);
    c.py_bindmethod(tp_path, "is_file", is_fileFn);
    c.py_bindmethod(tp_path, "is_dir", is_dirFn);
    c.py_bindmethod(tp_path, "resolve", resolveFn);

    c.py_bindmethod(tp_path, "cwd", cwdFn);
    c.py_setdict(module, c.py_name("Path"), c.py_tpobject(tp_path));
}
