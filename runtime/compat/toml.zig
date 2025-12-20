/// toml.zig - Minimal TOML parser/serializer for CLI config
///
/// Implements:
/// - loads(str) -> dict
/// - dumps(dict) -> str
///
/// Supported TOML subset:
/// - `key = value` (keys may be dotted)
/// - `[table]` headers (dotted)
/// - strings (basic quoted), ints, floats, bools, arrays
/// - `#` comments
///
/// Not supported yet: inline tables, dates, multiline strings, array-of-tables.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

fn stripComment(line: []const u8) []const u8 {
    var in_string: ?u8 = null;
    var i: usize = 0;
    while (i < line.len) : (i += 1) {
        const ch = line[i];
        if (in_string) |q| {
            if (ch == '\\') {
                i += 1;
                continue;
            }
            if (ch == q) in_string = null;
            continue;
        }
        if (ch == '"' or ch == '\'') {
            in_string = ch;
            continue;
        }
        if (ch == '#') return line[0..i];
    }
    return line;
}

fn cstr(buf: []u8, s: []const u8) ?[:0]const u8 {
    if (s.len + 1 > buf.len) return null;
    @memcpy(buf[0..s.len], s);
    buf[s.len] = 0;
    return buf[0..s.len :0];
}

fn ensureDictChild(parent: c.py_Ref, key: []const u8) ?c.py_TValue {
    var key_buf: [256]u8 = undefined;
    const kz = cstr(&key_buf, key) orelse return null;
    const existing = c.py_dict_getitem_by_str(parent, kz.ptr);
    if (existing < 0) return null;
    if (existing == 1 and c.py_isdict(c.py_retval())) return c.py_retval().*;
    c.py_newdict(c.py_r0());
    _ = c.py_dict_setitem_by_str(parent, kz.ptr, c.py_r0());
    return c.py_r0().*;
}

fn parseString(_: *pk.Context, s: []const u8) ?pk.Value {
    if (s.len < 2) return null;
    const q = s[0];
    if (q != '"' and q != '\'') return null;
    if (s[s.len - 1] != q) return null;
    const inner = s[1 .. s.len - 1];

    // Small unescape (only for basic strings with backslash escapes).
    var out_buf: [4096]u8 = undefined;
    var out_len: usize = 0;
    var i: usize = 0;
    while (i < inner.len) : (i += 1) {
        const ch = inner[i];
        if (q == '"' and ch == '\\' and i + 1 < inner.len) {
            i += 1;
            const esc = inner[i];
            const mapped: u8 = switch (esc) {
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                '"' => '"',
                '\\' => '\\',
                else => esc,
            };
            if (out_len >= out_buf.len) return null;
            out_buf[out_len] = mapped;
            out_len += 1;
            continue;
        }
        if (out_len >= out_buf.len) return null;
        out_buf[out_len] = ch;
        out_len += 1;
    }

    const out = c.py_newstrn(c.py_retval(), @intCast(out_len));
    @memcpy(out[0..out_len], out_buf[0..out_len]);
    return pk.Value.from(c.py_retval());
}

fn parseArray(ctx: *pk.Context, s: []const u8) ?pk.Value {
    if (s.len < 2 or s[0] != '[' or s[s.len - 1] != ']') return null;
    const inner = trim(s[1 .. s.len - 1]);
    c.py_newlist(c.py_retval());
    const list = c.py_retval();
    if (inner.len == 0) return pk.Value.from(list);

    var i: usize = 0;
    var start: usize = 0;
    var depth: usize = 0;
    var in_string: ?u8 = null;
    while (i <= inner.len) : (i += 1) {
        const ch: u8 = if (i < inner.len) inner[i] else ',';
        if (in_string) |q| {
            if (ch == '\\') {
                i += 1;
                continue;
            }
            if (ch == q) in_string = null;
        } else {
            if (ch == '"' or ch == '\'') in_string = ch;
            if (ch == '[') depth += 1;
            if (ch == ']') depth -= 1;
            if (ch == ',' and depth == 0) {
                const item_raw = trim(inner[start..i]);
                if (item_raw.len > 0) {
                    const item_val = parseValue(ctx, item_raw) orelse return null;
                    c.py_list_append(list, item_val.refConst());
                }
                start = i + 1;
            }
        }
    }
    return pk.Value.from(list);
}

fn parseValue(ctx: *pk.Context, raw: []const u8) ?pk.Value {
    const s = trim(raw);
    if (s.len == 0) return null;

    if (parseString(ctx, s)) |v| return v;
    if (parseArray(ctx, s)) |v| return v;

    if (std.mem.eql(u8, s, "true")) {
        c.py_newbool(c.py_retval(), true);
        return pk.Value.from(c.py_retval());
    }
    if (std.mem.eql(u8, s, "false")) {
        c.py_newbool(c.py_retval(), false);
        return pk.Value.from(c.py_retval());
    }

    // number
    if (std.mem.indexOfAny(u8, s, ".eE") != null) {
        const f = std.fmt.parseFloat(f64, s) catch return null;
        c.py_newfloat(c.py_retval(), f);
        return pk.Value.from(c.py_retval());
    } else {
        const i = std.fmt.parseInt(i64, s, 10) catch return null;
        c.py_newint(c.py_retval(), i);
        return pk.Value.from(c.py_retval());
    }
}

fn loadsFn(ctx: *pk.Context) bool {
    const input = ctx.argStr(0) orelse return ctx.typeError("expected str");

    c.py_newdict(c.py_retval());
    const root_tv: c.py_TValue = c.py_retval().*;
    var current_tv: c.py_TValue = root_tv;
    var current: c.py_Ref = &current_tv;

    var it = std.mem.splitScalar(u8, input, '\n');
    while (it.next()) |raw_line| {
        var line = trim(stripComment(raw_line));
        if (line.len == 0) continue;

        if (line[0] == '[' and line[line.len - 1] == ']') {
            const hdr = trim(line[1 .. line.len - 1]);
            current_tv = root_tv;
            current = &current_tv;
            var seg_it = std.mem.splitScalar(u8, hdr, '.');
            while (seg_it.next()) |seg_raw| {
                const seg = trim(seg_raw);
                const next = ensureDictChild(current, seg) orelse return ctx.valueError("invalid table name");
                current_tv = next;
                current = &current_tv;
            }
            continue;
        }

        const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse return ctx.valueError("invalid line");
        const key_raw = trim(line[0..eq_pos]);
        const val_raw = trim(line[eq_pos + 1 ..]);
        const val = parseValue(ctx, val_raw) orelse return ctx.valueError("invalid value");

        // key may be dotted; create intermediate tables in `current`.
        var target_tv: c.py_TValue = current_tv;
        var target: c.py_Ref = &target_tv;
        var segs: [32][]const u8 = undefined;
        var seg_count: usize = 0;
        var key_it = std.mem.splitScalar(u8, key_raw, '.');
        while (key_it.next()) |seg_raw| {
            if (seg_count >= segs.len) return ctx.valueError("key too deep");
            segs[seg_count] = trim(seg_raw);
            seg_count += 1;
        }
        if (seg_count == 0) return ctx.valueError("invalid key");
        var i: usize = 0;
        while (i + 1 < seg_count) : (i += 1) {
            const next = ensureDictChild(target, segs[i]) orelse return ctx.valueError("invalid key");
            target_tv = next;
            target = &target_tv;
        }
        const final_key = segs[seg_count - 1];
        var key_buf: [256]u8 = undefined;
        const kz = cstr(&key_buf, final_key) orelse return ctx.valueError("key too long");
        _ = c.py_dict_setitem_by_str(target, kz.ptr, val.refConst());
    }

    c.py_retval().* = root_tv;
    return true;
}

fn dumpScalar(writer: anytype, v: c.py_Ref) bool {
    if (c.py_isbool(v)) {
        writer.writeAll(if (c.py_tobool(v)) "true" else "false") catch return false;
        return true;
    }
    if (c.py_isint(v)) {
        writer.print("{}", .{c.py_toint(v)}) catch return false;
        return true;
    }
    if (c.py_isfloat(v)) {
        writer.print("{d}", .{c.py_tofloat(v)}) catch return false;
        return true;
    }
    if (c.py_isstr(v)) {
        const s = c.py_tostr(v);
        writer.writeByte('"') catch return false;
        writer.writeAll(s[0..std.mem.len(s)]) catch return false;
        writer.writeByte('"') catch return false;
        return true;
    }
    if (c.py_islist(v)) {
        writer.writeByte('[') catch return false;
        const n = c.py_list_len(v);
        var i: c_int = 0;
        while (i < n) : (i += 1) {
            if (i != 0) writer.writeAll(", ") catch return false;
            const item = c.py_list_getitem(v, i);
            if (!dumpScalar(writer, item)) return false;
        }
        writer.writeByte(']') catch return false;
        return true;
    }
    // fallback: str(v)
    if (!c.py_str(v)) return false;
    const s = c.py_tostr(c.py_retval());
    writer.writeByte('"') catch return false;
    writer.writeAll(s[0..std.mem.len(s)]) catch return false;
    writer.writeByte('"') catch return false;
    return true;
}

const Collect = struct {
    keys: std.ArrayList(c.py_TValue) = .empty,
    vals: std.ArrayList(c.py_TValue) = .empty,
    dicts: std.ArrayList(c.py_TValue) = .empty,
    dict_keys: std.ArrayList(c.py_TValue) = .empty,
};

fn collectFn(key: c.py_Ref, val: c.py_Ref, ctx_ptr: ?*anyopaque) callconv(.c) bool {
    const ctx: *Collect = @ptrCast(@alignCast(ctx_ptr));
    if (!c.py_isstr(key)) return true;
    c.py_r0().* = key.*;
    if (c.py_isdict(val)) {
        ctx.dict_keys.append(std.heap.c_allocator, c.py_r0().*) catch return false;
        ctx.dicts.append(std.heap.c_allocator, val.*) catch return false;
    } else {
        ctx.keys.append(std.heap.c_allocator, c.py_r0().*) catch return false;
        ctx.vals.append(std.heap.c_allocator, val.*) catch return false;
    }
    return true;
}

fn dumpsDict(writer: anytype, dict: c.py_Ref, prefix: []const u8) bool {
    var collect: Collect = .{};
    defer {
        collect.keys.deinit(std.heap.c_allocator);
        collect.vals.deinit(std.heap.c_allocator);
        collect.dicts.deinit(std.heap.c_allocator);
        collect.dict_keys.deinit(std.heap.c_allocator);
    }
    if (!c.py_dict_apply(dict, collectFn, &collect)) return false;

    // scalars
    for (collect.keys.items, collect.vals.items) |k, v| {
        const sv = c.py_tosv(@constCast(&k));
        const key_bytes: []const u8 = @as([*]const u8, @ptrCast(sv.data))[0..@intCast(sv.size)];
        writer.writeAll(key_bytes) catch return false;
        writer.writeAll(" = ") catch return false;
        if (!dumpScalar(writer, @constCast(&v))) return false;
        writer.writeByte('\n') catch return false;
    }

    // nested dicts
    for (collect.dict_keys.items, collect.dicts.items) |k, v| {
        const sv = c.py_tosv(@constCast(&k));
        const key_bytes: []const u8 = @as([*]const u8, @ptrCast(sv.data))[0..@intCast(sv.size)];
        writer.writeByte('\n') catch return false;
        writer.writeByte('[') catch return false;
        if (prefix.len > 0) {
            writer.writeAll(prefix) catch return false;
            writer.writeByte('.') catch return false;
        }
        writer.writeAll(key_bytes) catch return false;
        writer.writeAll("]\n") catch return false;

        var new_prefix_buf: [256]u8 = undefined;
        const dot: usize = if (prefix.len > 0) 1 else 0;
        if (prefix.len + dot + key_bytes.len > new_prefix_buf.len) return false;
        var p_len: usize = 0;
        if (prefix.len > 0) {
            @memcpy(new_prefix_buf[0..prefix.len], prefix);
            p_len += prefix.len;
            new_prefix_buf[p_len] = '.';
            p_len += 1;
        }
        @memcpy(new_prefix_buf[p_len .. p_len + key_bytes.len], key_bytes);
        p_len += key_bytes.len;
        if (!dumpsDict(writer, @constCast(&v), new_prefix_buf[0..p_len])) return false;
    }
    return true;
}

fn dumpsFn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("expected dict");
    if (!arg.isDict()) return ctx.typeError("expected dict");

    var buf: [16384]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    if (!dumpsDict(writer, arg.refConst(), "")) return ctx.valueError("failed to serialize toml");

    const written = fbs.getWritten();
    const out = c.py_newstrn(c.py_retval(), @intCast(written.len));
    @memcpy(out[0..written.len], written);
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("toml");
    _ = builder
        .funcWrapped("loads", 1, 1, loadsFn)
        .funcWrapped("dumps", 1, 1, dumpsFn);
}
