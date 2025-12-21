/// xml.etree.ElementTree - Minimal ElementTree builder
///
/// Implements:
/// - Element(tag)
/// - SubElement(parent, tag)
/// - tostring(element, encoding="unicode")
/// - fromstring(xml) -> Element (minimal XML parsing)
///
/// Useful for generating simple XML (no parsing yet).
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_element: c.py_Type = 0;

fn elementNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    // slots=-1 to allow attribute writes (`.text`, `.attrib`, etc.)
    _ = c.py_newobject(c.py_retval(), tp_element, -1, 0);
    return true;
}

fn elementInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "Element(tag) requires tag");
    const self = pk.argRef(argv, 0);
    const tag = pk.argRef(argv, 1);
    if (!c.py_isstr(tag)) return c.py_exception(c.tp_TypeError, "tag must be str");

    c.py_setdict(self, c.py_name("tag"), tag);
    c.py_newdict(c.py_r0());
    c.py_setdict(self, c.py_name("attrib"), c.py_r0());
    c.py_newnone(c.py_r0());
    c.py_setdict(self, c.py_name("text"), c.py_r0());
    c.py_newlist(c.py_r0());
    c.py_setdict(self, c.py_name("_children"), c.py_r0());

    c.py_newnone(c.py_retval());
    return true;
}

fn elementAppend(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "append(self, element)");
    const self = pk.argRef(argv, 0);
    const child = pk.argRef(argv, 1);
    const children_ptr = c.py_getdict(self, c.py_name("_children")) orelse return c.py_exception(c.tp_RuntimeError, "invalid Element");
    if (!c.py_islist(children_ptr)) return c.py_exception(c.tp_RuntimeError, "invalid Element");
    c.py_list_append(children_ptr, child);
    c.py_newnone(c.py_retval());
    return true;
}

fn elementIter(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "__iter__() takes no arguments");
    const self = pk.argRef(argv, 0);
    const children_ptr = c.py_getdict(self, c.py_name("_children")) orelse return c.py_exception(c.tp_RuntimeError, "invalid Element");
    if (!c.py_islist(children_ptr)) return c.py_exception(c.tp_RuntimeError, "invalid Element");
    return c.py_iter(children_ptr);
}

fn writeEscaped(w: anytype, s: []const u8) !void {
    for (s) |ch| {
        switch (ch) {
            '&' => try w.writeAll("&amp;"),
            '<' => try w.writeAll("&lt;"),
            '>' => try w.writeAll("&gt;"),
            '"' => try w.writeAll("&quot;"),
            '\'' => try w.writeAll("&apos;"),
            else => try w.writeByte(ch),
        }
    }
}

fn tostringElem(w: anytype, elem: c.py_Ref) !void {
    const tag_ptr = c.py_getdict(elem, c.py_name("tag")) orelse return error.Invalid;
    if (!c.py_isstr(tag_ptr)) return error.Invalid;
    const tag_c = c.py_tostr(tag_ptr);
    const tag = tag_c[0..std.mem.len(tag_c)];

    try w.writeByte('<');
    try w.writeAll(tag);

    const attrib_ptr = c.py_getdict(elem, c.py_name("attrib"));
    if (attrib_ptr != null and c.py_isdict(attrib_ptr.?)) {
        // Best-effort: iterate NameDict keys if possible; otherwise ignore.
        // (PocketPy dict iteration API isn't exposed directly in Zig wrappers.)
        // Users can still pre-render attributes into the tag if needed.
    }
    try w.writeByte('>');

    const text_ptr = c.py_getdict(elem, c.py_name("text"));
    if (text_ptr != null and c.py_isstr(text_ptr.?)) {
        const s = c.py_tostr(text_ptr.?);
        try writeEscaped(w, s[0..std.mem.len(s)]);
    }

    const children_ptr = c.py_getdict(elem, c.py_name("_children"));
    if (children_ptr != null and c.py_islist(children_ptr.?)) {
        const n = c.py_list_len(children_ptr.?);
        var i: c_int = 0;
        while (i < n) : (i += 1) {
            const child = c.py_list_getitem(children_ptr.?, i);
            try tostringElem(w, child);
        }
    }

    try w.writeAll("</");
    try w.writeAll(tag);
    try w.writeByte('>');
}

fn tostringFn(ctx: *pk.Context) bool {
    const elem = ctx.arg(0) orelse return ctx.typeError("expected Element");
    _ = ctx.argStr(1) orelse "unicode";

    var buf: [16384]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    tostringElem(w, elem.refConst()) catch return ctx.valueError("failed to serialize xml");
    const written = fbs.getWritten();
    const out = c.py_newstrn(c.py_retval(), @intCast(written.len));
    @memcpy(out[0..written.len], written);
    return true;
}

fn isWs(ch: u8) bool {
    return ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r';
}

fn skipWs(src: []const u8, pos: *usize) void {
    while (pos.* < src.len and isWs(src[pos.*])) : (pos.* += 1) {}
}

fn startsWith(src: []const u8, pos: usize, lit: []const u8) bool {
    return pos + lit.len <= src.len and std.mem.eql(u8, src[pos .. pos + lit.len], lit);
}

fn parseName(src: []const u8, pos: *usize) ![]const u8 {
    const start = pos.*;
    while (pos.* < src.len) : (pos.* += 1) {
        const ch = src[pos.*];
        if (isWs(ch) or ch == '/' or ch == '>' or ch == '=') break;
    }
    if (pos.* == start) return error.ParseError;
    return src[start..pos.*];
}

fn parseQuotedValue(allocator: std.mem.Allocator, src: []const u8, pos: *usize) ![]u8 {
    if (pos.* >= src.len) return error.ParseError;
    const quote = src[pos.*];
    if (quote != '"' and quote != '\'') return error.ParseError;
    pos.* += 1;
    const start = pos.*;
    while (pos.* < src.len and src[pos.*] != quote) : (pos.* += 1) {}
    if (pos.* >= src.len) return error.ParseError;
    const raw = src[start..pos.*];
    pos.* += 1;
    return unescapeAlloc(allocator, raw);
}

fn unescapeAlloc(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    var out = std.array_list.AlignedManaged(u8, null).init(allocator);
    errdefer out.deinit();

    var i: usize = 0;
    while (i < raw.len) : (i += 1) {
        const ch = raw[i];
        if (ch != '&') {
            try out.append(ch);
            continue;
        }
        const semi = std.mem.indexOfScalarPos(u8, raw, i, ';') orelse {
            try out.append('&');
            continue;
        };
        const ent = raw[i + 1 .. semi];
        if (std.mem.eql(u8, ent, "lt")) {
            try out.append('<');
        } else if (std.mem.eql(u8, ent, "gt")) {
            try out.append('>');
        } else if (std.mem.eql(u8, ent, "amp")) {
            try out.append('&');
        } else if (std.mem.eql(u8, ent, "quot")) {
            try out.append('"');
        } else if (std.mem.eql(u8, ent, "apos")) {
            try out.append('\'');
        } else if (ent.len >= 2 and ent[0] == '#') {
            const is_hex = ent.len >= 3 and (ent[1] == 'x' or ent[1] == 'X');
            const digits = if (is_hex) ent[2..] else ent[1..];
            const base: u8 = if (is_hex) 16 else 10;
            const cp = std.fmt.parseInt(u32, digits, base) catch 0;
            // Only emit ASCII (good enough for our CLI-focused uses).
            if (cp <= 0x7F) {
                try out.append(@intCast(cp));
            } else {
                try out.append('?');
            }
        } else {
            // Unknown entity; keep as-is.
            try out.appendSlice(raw[i .. semi + 1]);
        }
        i = semi;
    }
    return out.toOwnedSlice();
}

fn setText(elem: *c.py_TValue, text_bytes: []const u8) void {
    const s = c.py_newstrn(c.py_r0(), @intCast(text_bytes.len));
    if (text_bytes.len > 0) @memcpy(s[0..text_bytes.len], text_bytes);
    c.py_setdict(elem, c.py_name("text"), c.py_r0());
}

fn createElement(tag: []const u8) !c.py_TValue {
    const s = c.py_newstrn(c.py_r0(), @intCast(tag.len));
    if (tag.len > 0) @memcpy(s[0..tag.len], tag);
    var tv: c.py_TValue = c.py_r0().*;
    if (!c.py_call(c.py_tpobject(tp_element), 1, &tv)) return error.PyError;
    return c.py_retval().*;
}

fn parseElement(allocator: std.mem.Allocator, src: []const u8, pos: *usize) !c.py_TValue {
    if (pos.* >= src.len or src[pos.*] != '<') return error.ParseError;
    pos.* += 1;

    // Tag name
    const tag = try parseName(src, pos);
    var elem_tv = try createElement(tag);

    // Attributes
    skipWs(src, pos);
    while (pos.* < src.len and src[pos.*] != '>' and src[pos.*] != '/') {
        const attr_name = try parseName(src, pos);
        skipWs(src, pos);
        if (pos.* >= src.len or src[pos.*] != '=') return error.ParseError;
        pos.* += 1;
        skipWs(src, pos);
        const value = try parseQuotedValue(allocator, src, pos);
        defer allocator.free(value);

        const attrib_ptr = c.py_getdict(&elem_tv, c.py_name("attrib")) orelse return error.PyError;
        const k = c.py_newstrn(c.py_r0(), @intCast(attr_name.len));
        if (attr_name.len > 0) @memcpy(k[0..attr_name.len], attr_name);
        const v = c.py_newstrn(c.py_r1(), @intCast(value.len));
        if (value.len > 0) @memcpy(v[0..value.len], value);
        _ = c.py_dict_setitem(attrib_ptr, c.py_r0(), c.py_r1());

        skipWs(src, pos);
    }

    // Self-closing tag
    if (startsWith(src, pos.*, "/>")) {
        pos.* += 2;
        return elem_tv;
    }
    if (pos.* >= src.len or src[pos.*] != '>') return error.ParseError;
    pos.* += 1;

    var text_buf = std.array_list.AlignedManaged(u8, null).init(allocator);
    defer text_buf.deinit();
    var text_set = false;

    while (pos.* < src.len) {
        if (startsWith(src, pos.*, "</")) {
            pos.* += 2;
            const end_tag = try parseName(src, pos);
            skipWs(src, pos);
            if (pos.* >= src.len or src[pos.*] != '>') return error.ParseError;
            pos.* += 1;
            if (!std.mem.eql(u8, end_tag, tag)) return error.ParseError;
            break;
        }

        if (startsWith(src, pos.*, "<!--")) {
            const end = std.mem.indexOfPos(u8, src, pos.* + 4, "-->") orelse return error.ParseError;
            pos.* = end + 3;
            continue;
        }
        if (startsWith(src, pos.*, "<?")) {
            const end = std.mem.indexOfPos(u8, src, pos.* + 2, "?>") orelse return error.ParseError;
            pos.* = end + 2;
            continue;
        }
        if (startsWith(src, pos.*, "<![CDATA[")) {
            const end = std.mem.indexOfPos(u8, src, pos.* + 9, "]]>") orelse return error.ParseError;
            try text_buf.appendSlice(src[pos.* + 9 .. end]);
            pos.* = end + 3;
            continue;
        }

        if (src[pos.*] == '<') {
            if (!text_set and text_buf.items.len > 0) {
                const un = try unescapeAlloc(allocator, text_buf.items);
                defer allocator.free(un);
                setText(&elem_tv, un);
                text_set = true;
                text_buf.clearRetainingCapacity();
            }
            var child_tv = try parseElement(allocator, src, pos);
            const children_ptr = c.py_getdict(&elem_tv, c.py_name("_children")) orelse return error.PyError;
            _ = c.py_list_append(children_ptr, &child_tv);
            continue;
        }

        // Text node content
        const start = pos.*;
        while (pos.* < src.len and src[pos.*] != '<') : (pos.* += 1) {}
        try text_buf.appendSlice(src[start..pos.*]);
    }

    if (!text_set and text_buf.items.len > 0) {
        const un = try unescapeAlloc(allocator, text_buf.items);
        defer allocator.free(un);
        setText(&elem_tv, un);
    }

    return elem_tv;
}

fn fromstringFn(ctx: *pk.Context) bool {
    var v = ctx.arg(0) orelse return ctx.typeError("expected str or bytes");

    var xml_bytes: []const u8 = undefined;
    if (v.isStr()) {
        const z = v.toStr() orelse return ctx.typeError("expected str");
        xml_bytes = z;
    } else if (v.isType(c.tp_bytes)) {
        var n: c_int = 0;
        const ptr = c.py_tobytes(v.refConst(), &n);
        xml_bytes = @as([*]const u8, @ptrCast(ptr))[0..@intCast(n)];
    } else {
        return ctx.typeError("expected str or bytes");
    }

    var pos: usize = 0;
    skipWs(xml_bytes, &pos);
    if (startsWith(xml_bytes, pos, "<?xml")) {
        const end = std.mem.indexOfPos(u8, xml_bytes, pos, "?>") orelse return ctx.valueError("invalid xml");
        pos = end + 2;
        skipWs(xml_bytes, &pos);
    }
    const root_tv = parseElement(std.heap.page_allocator, xml_bytes, &pos) catch return ctx.valueError("invalid xml");
    c.py_retval().* = root_tv;
    return true;
}

fn subelementFn(ctx: *pk.Context) bool {
    const parent = ctx.arg(0) orelse return ctx.typeError("expected parent");
    const tag = ctx.arg(1) orelse return ctx.typeError("expected tag");
    if (!c.py_isstr(tag.refConst())) return ctx.typeError("tag must be str");

    var tag_tv: c.py_TValue = tag.refConst().*;
    if (!c.py_call(c.py_tpobject(tp_element), 1, &tag_tv)) return false;
    const child_tv: c.py_TValue = c.py_retval().*;

    // parent.append(child)
    if (!c.py_getattr(parent.refConst(), c.py_name("append"))) return false;
    var append_fn: c.py_TValue = c.py_retval().*;
    var args: [1]c.py_TValue = .{child_tv};
    if (!c.py_call(&append_fn, 1, @ptrCast(&args))) return false;

    c.py_retval().* = child_tv;
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("xml.etree.ElementTree");

    var element_builder = pk.TypeBuilder.new("Element", c.tp_object, builder.module, null);
    tp_element = element_builder
        .magic("__new__", elementNew)
        .magic("__init__", elementInit)
        .magic("__iter__", elementIter)
        .method("append", elementAppend)
        .build();

    _ = builder
        .funcWrapped("SubElement", 2, 2, subelementFn)
        .funcWrapped("tostring", 1, 2, tostringFn)
        .funcWrapped("fromstring", 1, 1, fromstringFn);
}
