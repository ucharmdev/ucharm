const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn newPyStrFromSlice(out_ref: c.py_OutRef, s: []const u8) void {
    c.py_newstrv(out_ref, .{ .data = s.ptr, .size = @intCast(s.len) });
}

fn isWs(ch: u8) bool {
    return ch == ' ' or ch == '\n' or ch == '\t' or ch == '\r' or ch == '\x0b' or ch == '\x0c';
}

fn wrapImpl(alloc: std.mem.Allocator, text: []const u8, width_in: i64) ![][]const u8 {
    var width: usize = 70;
    if (width_in > 0) width = @intCast(width_in) else width = 1;

    var lines = std.ArrayList([]const u8).empty;
    errdefer lines.deinit(alloc);

    var current = std.ArrayList(u8).empty;
    defer current.deinit(alloc);

    var i: usize = 0;
    var has_word = false;
    while (i < text.len) {
        while (i < text.len and isWs(text[i])) : (i += 1) {}
        if (i >= text.len) break;
        has_word = true;
        const start = i;
        while (i < text.len and !isWs(text[i])) : (i += 1) {}
        const word = text[start..i];

        if (current.items.len == 0) {
            current.appendSlice(alloc, word) catch return error.OutOfMemory;
        } else if (current.items.len + 1 + word.len <= width) {
            current.append(alloc, ' ') catch return error.OutOfMemory;
            current.appendSlice(alloc, word) catch return error.OutOfMemory;
        } else {
            const line = try alloc.dupe(u8, current.items);
            lines.append(alloc, line) catch return error.OutOfMemory;
            current.clearRetainingCapacity();
            current.appendSlice(alloc, word) catch return error.OutOfMemory;
        }

        if (word.len > width and current.items.len == word.len) {
            // Keep long words unbroken.
        }
    }

    if (!has_word) return try lines.toOwnedSlice(alloc);
    if (current.items.len > 0) {
        const line = try alloc.dupe(u8, current.items);
        lines.append(alloc, line) catch return error.OutOfMemory;
    }
    return try lines.toOwnedSlice(alloc);
}

fn wrapFn(ctx: *pk.Context) bool {
    const text = ctx.argStr(0) orelse return ctx.typeError("text must be a string");
    const width_arg = ctx.argInt(1) orelse 70;
    const width: usize = if (width_arg > 0) @intCast(width_arg) else 70;

    // Empty text returns empty list
    if (text.len == 0) {
        c.py_newlist(c.py_retval());
        return true;
    }

    // Simple implementation: if text fits in width, return single-element list
    // Collapse whitespace first
    var buf: [4096]u8 = undefined;
    var buf_len: usize = 0;
    var i: usize = 0;
    var need_space = false;

    while (i < text.len) {
        // Skip whitespace
        while (i < text.len and isWs(text[i])) : (i += 1) {}
        if (i >= text.len) break;

        // Find word
        const word_start = i;
        while (i < text.len and !isWs(text[i])) : (i += 1) {}
        const word = text[word_start..i];

        // Add space if needed
        if (need_space and buf_len + 1 + word.len <= buf.len) {
            buf[buf_len] = ' ';
            buf_len += 1;
        }
        need_space = true;

        // Add word
        if (buf_len + word.len <= buf.len) {
            @memcpy(buf[buf_len..][0..word.len], word);
            buf_len += word.len;
        }
    }

    // Now wrap the collapsed text
    c.py_newlist(c.py_retval());
    const out = c.py_retval();

    if (buf_len == 0) return true;

    var line_start: usize = 0;
    var line_end: usize = 0;
    i = 0;

    while (i < buf_len) {
        // Skip spaces at start of potential line
        while (i < buf_len and buf[i] == ' ') : (i += 1) {}
        if (i >= buf_len) break;

        line_start = i;
        line_end = i;

        // Collect words for this line
        while (i < buf_len) {
            while (i < buf_len and buf[i] != ' ') : (i += 1) {}
            const word_end = i;

            if (line_end == line_start) {
                // First word on line
                line_end = word_end;
            } else if (word_end - line_start <= width) {
                // Word fits
                line_end = word_end;
            } else {
                // Word doesn't fit, emit line
                break;
            }

            // Skip trailing space
            while (i < buf_len and buf[i] == ' ') : (i += 1) {}
        }

        // Emit line
        if (line_end > line_start) {
            // Copy to temp buffer with null terminator
            var temp: [4097]u8 = undefined;
            const line_len = line_end - line_start;
            @memcpy(temp[0..line_len], buf[line_start..line_end]);
            temp[line_len] = 0;
            c.py_newstr(c.py_r0(), &temp);
            c.py_list_append(out, c.py_r0());
        }
    }

    return true;
}

fn fillFn(ctx: *pk.Context) bool {
    const text = ctx.argStr(0) orelse return ctx.typeError("text must be a string");
    const width = ctx.argInt(1) orelse 70;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const lines = wrapImpl(alloc, text, width) catch return ctx.runtimeError("out of memory");
    if (lines.len == 0) {
        return ctx.returnStr("");
    }

    var out = std.ArrayList(u8).empty;
    defer out.deinit(alloc);
    for (lines, 0..) |line, idx| {
        if (idx != 0) out.append(alloc, '\n') catch return ctx.runtimeError("out of memory");
        out.appendSlice(alloc, line) catch return ctx.runtimeError("out of memory");
    }
    return ctx.returnStr(out.items);
}

fn dedentFn(ctx: *pk.Context) bool {
    const text = ctx.argStr(0) orelse return ctx.typeError("text must be a string");

    var min_indent: ?usize = null;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        if (line.len == 0) continue;
        var j: usize = 0;
        while (j < line.len and (line[j] == ' ' or line[j] == '\t')) : (j += 1) {}
        if (j == line.len) continue;
        if (min_indent == null or j < min_indent.?) min_indent = j;
    }
    const indent = min_indent orelse 0;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var out = std.ArrayList(u8).empty;
    defer out.deinit(alloc);
    var it2 = std.mem.splitScalar(u8, text, '\n');
    var first = true;
    while (it2.next()) |line| {
        if (!first) out.append(alloc, '\n') catch return ctx.runtimeError("out of memory");
        first = false;
        var start: usize = 0;
        var j: usize = 0;
        while (j < indent and j < line.len and (line[j] == ' ' or line[j] == '\t')) : (j += 1) {}
        start = j;
        out.appendSlice(alloc, line[start..]) catch return ctx.runtimeError("out of memory");
    }
    return ctx.returnStr(out.items);
}

fn indentFn(ctx: *pk.Context) bool {
    const text = ctx.argStr(0) orelse return ctx.typeError("text must be a string");
    const prefix = ctx.argStr(1) orelse return ctx.typeError("prefix must be a string");

    if (text.len == 0) {
        return ctx.returnStr("");
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var out = std.ArrayList(u8).empty;
    defer out.deinit(alloc);
    var it = std.mem.splitScalar(u8, text, '\n');
    var first = true;
    while (it.next()) |line| {
        if (!first) out.append(alloc, '\n') catch return ctx.runtimeError("out of memory");
        first = false;
        out.appendSlice(alloc, prefix) catch return ctx.runtimeError("out of memory");
        out.appendSlice(alloc, line) catch return ctx.runtimeError("out of memory");
    }
    return ctx.returnStr(out.items);
}

fn shortenFn(ctx: *pk.Context) bool {
    const text = ctx.argStr(0) orelse return ctx.typeError("text must be a string");
    const width_i = ctx.argInt(1) orelse return ctx.typeError("width must be an int");

    if (width_i <= 0) {
        return ctx.returnStr("");
    }
    const width: usize = @intCast(width_i);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Collapse whitespace to single spaces and trim.
    var collapsed = std.ArrayList(u8).empty;
    defer collapsed.deinit(alloc);
    var i: usize = 0;
    var seen_word = false;
    while (i < text.len) {
        while (i < text.len and isWs(text[i])) : (i += 1) {}
        if (i >= text.len) break;
        const start = i;
        while (i < text.len and !isWs(text[i])) : (i += 1) {}
        const word = text[start..i];
        if (seen_word) collapsed.append(alloc, ' ') catch return ctx.runtimeError("out of memory");
        collapsed.appendSlice(alloc, word) catch return ctx.runtimeError("out of memory");
        seen_word = true;
    }
    const s = collapsed.items;
    if (s.len <= width) {
        return ctx.returnStr(s);
    }
    const placeholder = "...";
    if (width <= placeholder.len) {
        return ctx.returnStr(placeholder[0..width]);
    }
    const max_body = width - placeholder.len;

    var out = std.ArrayList(u8).empty;
    defer out.deinit(alloc);
    i = 0;
    var out_len: usize = 0;
    while (i < s.len) {
        while (i < s.len and s[i] == ' ') : (i += 1) {}
        if (i >= s.len) break;
        const start = i;
        while (i < s.len and s[i] != ' ') : (i += 1) {}
        const word = s[start..i];
        const needed = if (out_len == 0) word.len else 1 + word.len;
        if (out_len + needed > max_body) break;
        if (out_len != 0) out.append(alloc, ' ') catch return ctx.runtimeError("out of memory");
        out.appendSlice(alloc, word) catch return ctx.runtimeError("out of memory");
        out_len = out.items.len;
    }
    out.appendSlice(alloc, placeholder) catch return ctx.runtimeError("out of memory");
    return ctx.returnStr(out.items);
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("textwrap");
    _ = builder
        .funcSigWrapped("wrap(text, width=70)", 1, 2, wrapFn)
        .funcSigWrapped("fill(text, width=70)", 1, 2, fillFn)
        .funcWrapped("dedent", 1, 1, dedentFn)
        .funcWrapped("indent", 2, 2, indentFn)
        .funcWrapped("shorten", 2, 2, shortenFn);
}
