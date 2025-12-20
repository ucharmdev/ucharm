const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn jsonStringEscape(out: *std.ArrayList(u8), gpa: std.mem.Allocator, s: []const u8) !void {
    try out.append(gpa, '"');
    for (s) |ch| {
        switch (ch) {
            '"' => try out.appendSlice(gpa, "\\\""),
            '\\' => try out.appendSlice(gpa, "\\\\"),
            '\n' => try out.appendSlice(gpa, "\\n"),
            '\r' => try out.appendSlice(gpa, "\\r"),
            '\t' => try out.appendSlice(gpa, "\\t"),
            else => {
                if (ch < 0x20) {
                    var buf: [6]u8 = undefined;
                    const hex = "0123456789abcdef";
                    buf[0] = '\\';
                    buf[1] = 'u';
                    buf[2] = '0';
                    buf[3] = '0';
                    buf[4] = hex[(ch >> 4) & 0xF];
                    buf[5] = hex[ch & 0xF];
                    try out.appendSlice(gpa, buf[0..]);
                } else {
                    try out.append(gpa, ch);
                }
            },
        }
    }
    try out.append(gpa, '"');
}

const Separators = struct {
    item: []const u8 = ", ",
    key: []const u8 = ": ",
};

fn parseSeparators(v: *pk.Value) ?Separators {
    if (!v.isTuple()) return null;
    const n = v.len() orelse return null;
    if (n != 2) return null;
    var a0 = v.getItem(0) orelse return null;
    var a1 = v.getItem(1) orelse return null;
    const item = a0.toStr() orelse return null;
    const key = a1.toStr() orelse return null;
    return .{ .item = item, .key = key };
}

fn writeIndent(out: *std.ArrayList(u8), gpa: std.mem.Allocator, depth: usize, indent: usize) !void {
    try out.append(gpa, '\n');
    var i: usize = 0;
    while (i < depth * indent) : (i += 1) try out.append(gpa, ' ');
}

fn writePyJson(
    out: *std.ArrayList(u8),
    gpa: std.mem.Allocator,
    v: c.py_Ref,
    depth: usize,
    indent: ?usize,
    sep: Separators,
    sort_keys: bool,
) !void {
    if (c.py_isnone(v) or c.py_isnil(v)) {
        try out.appendSlice(gpa, "null");
        return;
    }
    if (c.py_isbool(v)) {
        try out.appendSlice(gpa, if (c.py_tobool(v)) "true" else "false");
        return;
    }
    if (c.py_isint(v)) {
        var buf: [64]u8 = undefined;
        const s = try std.fmt.bufPrint(&buf, "{d}", .{c.py_toint(v)});
        try out.appendSlice(gpa, s);
        return;
    }
    if (c.py_isfloat(v)) {
        var buf: [128]u8 = undefined;
        const f = c.py_tofloat(v);
        if (std.math.isNan(f)) {
            try out.appendSlice(gpa, "NaN");
            return;
        }
        if (std.math.isInf(f)) {
            try out.appendSlice(gpa, if (f < 0) "-Infinity" else "Infinity");
            return;
        }
        const s = try std.fmt.bufPrint(&buf, "{d}", .{f});
        try out.appendSlice(gpa, s);
        return;
    }
    if (c.py_isstr(v)) {
        const sv = c.py_tosv(v);
        const bytes: []const u8 = @as([*]const u8, @ptrCast(sv.data))[0..@intCast(sv.size)];
        try jsonStringEscape(out, gpa, bytes);
        return;
    }
    if (c.py_islist(v) or c.py_istuple(v)) {
        const len: c_int = if (c.py_islist(v)) c.py_list_len(v) else c.py_tuple_len(v);
        try out.append(gpa, '[');
        if (len == 0) {
            try out.append(gpa, ']');
            return;
        }
        var i: c_int = 0;
        while (i < len) : (i += 1) {
            if (indent) |n| {
                if (i == 0) {
                    try writeIndent(out, gpa, depth + 1, n);
                } else {
                    try out.append(gpa, ',');
                    try writeIndent(out, gpa, depth + 1, n);
                }
            } else {
                if (i != 0) try out.appendSlice(gpa, sep.item);
            }
            const item = if (c.py_islist(v)) c.py_list_getitem(v, i) else c.py_tuple_getitem(v, i);
            try writePyJson(out, gpa, item, depth + 1, indent, sep, sort_keys);
        }
        if (indent) |n| try writeIndent(out, gpa, depth, n);
        try out.append(gpa, ']');
        return;
    }
    if (c.py_isdict(v)) {
        // Collect entries so we can optionally sort.
        const Entry = struct { k: c.py_TValue, v: c.py_TValue, ks: []const u8 };
        var entries: std.ArrayList(Entry) = .empty;
        defer entries.deinit(gpa);

        const CollectCtx = struct { list: *std.ArrayList(Entry), gpa: std.mem.Allocator };
        const collectFn = struct {
            fn f(k: c.py_Ref, val: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
                const collect_ctx: *CollectCtx = @ptrCast(@alignCast(ctx.?));
                if (!c.py_isstr(k)) return true;
                const sv = c.py_tosv(k);
                const bytes: []const u8 = @as([*]const u8, @ptrCast(sv.data))[0..@intCast(sv.size)];
                collect_ctx.list.append(collect_ctx.gpa, .{ .k = k.*, .v = val.*, .ks = bytes }) catch return false;
                return true;
            }
        }.f;

        var collect_ctx = CollectCtx{ .list = &entries, .gpa = gpa };
        _ = c.py_dict_apply(v, collectFn, &collect_ctx);

        if (sort_keys) {
            std.sort.block(Entry, entries.items, {}, struct {
                fn lessThan(_: void, a: Entry, b: Entry) bool {
                    return std.mem.lessThan(u8, a.ks, b.ks);
                }
            }.lessThan);
        }

        try out.append(gpa, '{');
        if (entries.items.len == 0) {
            try out.append(gpa, '}');
            return;
        }
        var idx: usize = 0;
        while (idx < entries.items.len) : (idx += 1) {
            if (indent) |n| {
                if (idx == 0) {
                    try writeIndent(out, gpa, depth + 1, n);
                } else {
                    try out.append(gpa, ',');
                    try writeIndent(out, gpa, depth + 1, n);
                }
            } else {
                if (idx != 0) try out.appendSlice(gpa, sep.item);
            }

            try jsonStringEscape(out, gpa, entries.items[idx].ks);
            try out.appendSlice(gpa, sep.key);

            var val_ref: c.py_TValue = entries.items[idx].v;
            try writePyJson(out, gpa, &val_ref, depth + 1, indent, sep, sort_keys);
        }
        if (indent) |n| try writeIndent(out, gpa, depth, n);
        try out.append(gpa, '}');
        return;
    }

    return error.UnsupportedType;
}

fn dumpsFn(ctx: *pk.Context) bool {
    var obj = ctx.arg(0) orelse return ctx.typeError("expected object");

    var indent: ?usize = null;
    var separators: Separators = .{};
    var sort_keys: bool = false;

    if (ctx.arg(1)) |v| {
        var vv = v;
        if (!vv.isNone()) {
            const i = vv.toInt() orelse return ctx.typeError("indent must be int or None");
            if (i < 0) return ctx.valueError("indent must be >= 0");
            indent = @intCast(i);
        }
    }
    if (ctx.arg(2)) |v| {
        var vv = v;
        if (!vv.isNone()) {
            separators = parseSeparators(&vv) orelse return ctx.typeError("separators must be a 2-tuple of strings");
        }
    }
    if (ctx.arg(3)) |v| {
        var vv = v;
        if (!vv.isNone()) {
            sort_keys = vv.toBool() orelse return ctx.typeError("sort_keys must be bool");
        }
    }

    // CPython switches the default item separator to "," when indent is set.
    // Keep explicit separators if the user provided them.
    if (indent != null and std.mem.eql(u8, separators.item, ", ") and std.mem.eql(u8, separators.key, ": ")) {
        separators = .{ .item = ",", .key = ": " };
    }

    const gpa = std.heap.page_allocator;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);

    writePyJson(&out, gpa, obj.ref(), 0, indent, separators, sort_keys) catch |e| switch (e) {
        error.UnsupportedType => return ctx.typeError("Object of unsupported type"),
        else => return ctx.runtimeError("json.dumps failed"),
    };

    const s = out.items;
    const dst = c.py_newstrn(c.py_retval(), @intCast(s.len));
    @memcpy(dst[0..s.len], s);
    return true;
}

fn jsonToPy(out: c.py_OutRef, v: std.json.Value) bool {
    switch (v) {
        .null => {
            c.py_newnone(out);
            return true;
        },
        .bool => |b| {
            c.py_newbool(out, b);
            return true;
        },
        .integer => |i| {
            c.py_newint(out, i);
            return true;
        },
        .float => |f| {
            c.py_newfloat(out, f);
            return true;
        },
        .number_string => |s| {
            const maybe_i: ?i64 = std.fmt.parseInt(i64, s, 10) catch null;
            if (maybe_i) |i| {
                c.py_newint(out, i);
                return true;
            }
            const maybe_f: ?f64 = std.fmt.parseFloat(f64, s) catch null;
            if (maybe_f) |f| {
                c.py_newfloat(out, f);
                return true;
            }
            _ = c.py_exception(c.tp_ValueError, "Invalid JSON");
            return false;
        },
        .string => |s| {
            const dst = c.py_newstrn(out, @intCast(s.len));
            @memcpy(dst[0..s.len], s);
            return true;
        },
        .array => |arr| {
            c.py_newlist(out);
            for (arr.items) |item| {
                var tmp: c.py_TValue = undefined;
                if (!jsonToPy(&tmp, item)) return false;
                c.py_list_append(out, &tmp);
            }
            return true;
        },
        .object => |obj| {
            c.py_newdict(out);
            var it = obj.iterator();
            while (it.next()) |entry| {
                var key_tv: c.py_TValue = undefined;
                const key_bytes = entry.key_ptr.*;
                const key_dst = c.py_newstrn(&key_tv, @intCast(key_bytes.len));
                @memcpy(key_dst[0..key_bytes.len], key_bytes);
                var val_tv: c.py_TValue = undefined;
                if (!jsonToPy(&val_tv, entry.value_ptr.*)) return false;
                _ = c.py_dict_setitem(out, &key_tv, &val_tv);
            }
            return true;
        },
    }
}

fn loadsFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("expected string");

    var parsed = std.json.parseFromSlice(
        std.json.Value,
        std.heap.page_allocator,
        s,
        .{},
    ) catch return ctx.valueError("Invalid JSON");
    defer parsed.deinit();

    if (!jsonToPy(c.py_retval(), parsed.value)) return false;
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.importAndExtend("json") orelse {
        c.py_clearexc(null);
        return;
    };

    c.py_setdict(builder.module, c.py_name("JSONDecodeError"), c.py_tpobject(c.tp_ValueError));

    _ = builder.funcWrapped("loads", 1, 1, loadsFn);
    _ = builder.funcSigWrapped("dumps(obj, indent=None, separators=None, sort_keys=False)", 1, 4, dumpsFn);
}
