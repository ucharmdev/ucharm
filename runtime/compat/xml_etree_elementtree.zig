/// xml.etree.ElementTree - Minimal ElementTree builder
///
/// Implements:
/// - Element(tag)
/// - SubElement(parent, tag)
/// - tostring(element, encoding="unicode")
/// - fromstring(xml) -> NotImplementedError (for now)
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

fn fromstringFn(_: *pk.Context) bool {
    return c.py_exception(c.tp_NotImplementedError, "xml.etree.ElementTree.fromstring is not implemented yet");
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
        .method("append", elementAppend)
        .build();

    _ = builder
        .funcWrapped("SubElement", 2, 2, subelementFn)
        .funcWrapped("tostring", 1, 2, tostringFn)
        .funcWrapped("fromstring", 1, 1, fromstringFn);
}
