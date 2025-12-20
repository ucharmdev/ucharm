const std = @import("std");
const pk = @import("pk");
const c = pk.c;

const re_groups_key: [:0]const u8 = "groups";
const re_spans_key: [:0]const u8 = "spans";

var tp_match: c.py_Type = 0;
var tp_pattern: c.py_Type = 0;

const GroupSpan = struct {
    start: usize,
    end: usize,
    matched: bool,
};

const CharClass = struct {
    table: [256]bool,
    negated: bool,
};

const Atom = union(enum) {
    literal: u8,
    any,
    class: CharClass,
    group: []Token,
};

const Quant = struct {
    min: usize,
    max: ?usize,
};

const Token = struct {
    atom: Atom,
    quant: Quant,
    group_index: ?usize,
};

const Pattern = struct {
    tokens: []Token,
    anchor_start: bool,
    anchor_end: bool,
    group_count: usize,
};

const ParseError = error{ InvalidPattern, UnsupportedPattern, OutOfMemory };

const Parser = struct {
    pattern: []const u8,
    idx: usize,
    end: usize,
    group_count: usize,
    alloc: std.mem.Allocator,

    fn parse(self: *Parser) ParseError!Pattern {
        var anchor_start = false;
        if (self.idx < self.end and self.pattern[self.idx] == '^') {
            anchor_start = true;
            self.idx += 1;
        }

        var anchor_end = false;
        if (self.end > self.idx and self.pattern[self.end - 1] == '$') {
            anchor_end = true;
            self.end -= 1;
        }

        const tokens = try self.parseSequence(null);
        return .{
            .tokens = tokens,
            .anchor_start = anchor_start,
            .anchor_end = anchor_end,
            .group_count = self.group_count,
        };
    }

    fn parseSequence(self: *Parser, terminator: ?u8) ParseError![]Token {
        var tokens = std.ArrayList(Token).empty;
        while (self.idx < self.end) {
            const ch = self.pattern[self.idx];
            if (terminator != null and ch == terminator.?) {
                break;
            }
            if (ch == '|') {
                return ParseError.UnsupportedPattern;
            }
            var token = try self.parseAtom();
            try self.applyQuantifier(&token);
            tokens.append(self.alloc, token) catch return ParseError.OutOfMemory;
        }
        return tokens.toOwnedSlice(self.alloc) catch ParseError.OutOfMemory;
    }

    fn parseAtom(self: *Parser) ParseError!Token {
        const ch = self.pattern[self.idx];
        self.idx += 1;
        var atom: Atom = undefined;
        var group_index: ?usize = null;

        switch (ch) {
            '(' => {
                const group_id = self.group_count + 1;
                self.group_count = group_id;
                const inner = try self.parseSequence(')');
                if (self.idx >= self.end or self.pattern[self.idx] != ')') {
                    return ParseError.InvalidPattern;
                }
                self.idx += 1;
                atom = .{ .group = inner };
                group_index = group_id;
            },
            '[' => {
                const class = try self.parseCharClass();
                atom = .{ .class = class };
            },
            '.' => {
                atom = .any;
            },
            '\\' => {
                if (self.idx >= self.end) return ParseError.InvalidPattern;
                const esc = self.pattern[self.idx];
                self.idx += 1;
                atom = switch (esc) {
                    'd' => .{ .class = digitClass() },
                    'w' => .{ .class = wordClass() },
                    's' => .{ .class = spaceClass() },
                    else => .{ .literal = esc },
                };
            },
            else => {
                atom = .{ .literal = ch };
            },
        }

        return .{
            .atom = atom,
            .quant = .{ .min = 1, .max = 1 },
            .group_index = group_index,
        };
    }

    fn parseCharClass(self: *Parser) ParseError!CharClass {
        var table: [256]bool = [_]bool{false} ** 256;
        var negated = false;
        if (self.idx < self.end and self.pattern[self.idx] == '^') {
            negated = true;
            self.idx += 1;
        }

        var prev: ?u8 = null;
        while (self.idx < self.end) {
            const ch = self.pattern[self.idx];
            if (ch == ']') {
                self.idx += 1;
                break;
            }
            if (ch == '\\') {
                self.idx += 1;
                if (self.idx >= self.end) return ParseError.InvalidPattern;
                const esc = self.pattern[self.idx];
                self.idx += 1;
                switch (esc) {
                    'd' => addClass(&table, digitClass()),
                    'w' => addClass(&table, wordClass()),
                    's' => addClass(&table, spaceClass()),
                    else => table[esc] = true,
                }
                prev = null;
                continue;
            }

            if (ch == '-' and prev != null and self.idx + 1 < self.end and self.pattern[self.idx + 1] != ']') {
                self.idx += 1;
                const end_ch = self.pattern[self.idx];
                self.idx += 1;
                var ch_val: u8 = prev.?;
                while (ch_val <= end_ch) : (ch_val += 1) {
                    table[ch_val] = true;
                    if (ch_val == 255) break;
                }
                prev = null;
                continue;
            }

            table[ch] = true;
            prev = ch;
            self.idx += 1;
        }

        return .{ .table = table, .negated = negated };
    }

    fn applyQuantifier(self: *Parser, token: *Token) ParseError!void {
        if (self.idx >= self.end) return;
        const ch = self.pattern[self.idx];
        switch (ch) {
            '*', '+', '?' => {
                self.idx += 1;
                token.quant = switch (ch) {
                    '*' => .{ .min = 0, .max = null },
                    '+' => .{ .min = 1, .max = null },
                    '?' => .{ .min = 0, .max = 1 },
                    else => token.quant,
                };
            },
            '{' => {
                const start = self.idx + 1;
                var j = start;
                while (j < self.end and std.ascii.isDigit(self.pattern[j])) : (j += 1) {}
                if (j == start or j >= self.end or self.pattern[j] != '}') {
                    return ParseError.InvalidPattern;
                }
                const num_slice = self.pattern[start..j];
                const n = std.fmt.parseUnsigned(usize, num_slice, 10) catch return ParseError.InvalidPattern;
                self.idx = j + 1;
                token.quant = .{ .min = n, .max = n };
            },
            else => {},
        }
    }
};

fn digitClass() CharClass {
    var table: [256]bool = [_]bool{false} ** 256;
    var ch_val: u8 = '0';
    while (ch_val <= '9') : (ch_val += 1) {
        table[ch_val] = true;
    }
    return .{ .table = table, .negated = false };
}

fn wordClass() CharClass {
    var table: [256]bool = [_]bool{false} ** 256;
    var ch_val: u8 = '0';
    while (ch_val <= '9') : (ch_val += 1) table[ch_val] = true;
    ch_val = 'A';
    while (ch_val <= 'Z') : (ch_val += 1) table[ch_val] = true;
    ch_val = 'a';
    while (ch_val <= 'z') : (ch_val += 1) table[ch_val] = true;
    table['_'] = true;
    return .{ .table = table, .negated = false };
}

fn spaceClass() CharClass {
    var table: [256]bool = [_]bool{false} ** 256;
    table[' '] = true;
    table['\t'] = true;
    table['\n'] = true;
    table['\r'] = true;
    table['\x0b'] = true;
    table['\x0c'] = true;
    return .{ .table = table, .negated = false };
}

fn addClass(table: *[256]bool, class: CharClass) void {
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        if (class.table[i]) table[i] = true;
    }
}

fn parsePattern(alloc: std.mem.Allocator, pattern: []const u8) ParseError!Pattern {
    var parser = Parser{ .pattern = pattern, .idx = 0, .end = pattern.len, .group_count = 0, .alloc = alloc };
    return parser.parse();
}

fn matchAtomOnce(alloc: std.mem.Allocator, token: Token, text: []const u8, pos: usize, groups: []GroupSpan) ParseError!?usize {
    switch (token.atom) {
        .literal => |ch| {
            if (pos >= text.len or text[pos] != ch) return null;
            return pos + 1;
        },
        .any => {
            if (pos >= text.len) return null;
            return pos + 1;
        },
        .class => |class| {
            if (pos >= text.len) return null;
            const matched = class.table[text[pos]];
            if ((matched and !class.negated) or (!matched and class.negated)) {
                return pos + 1;
            }
            return null;
        },
        .group => |inner| {
            if (token.group_index == null) return ParseError.InvalidPattern;
            const start = pos;
            if (try matchFrom(alloc, inner, 0, text, pos, groups)) |end_pos| {
                const idx = token.group_index.?;
                groups[idx] = .{ .start = start, .end = end_pos, .matched = true };
                return end_pos;
            }
            return null;
        },
    }
}

fn maxRepeatSingle(token: Token, text: []const u8, pos: usize) usize {
    var count: usize = 0;
    var cursor = pos;
    while (cursor < text.len) : (cursor += 1) {
        const ok = switch (token.atom) {
            .literal => |ch| text[cursor] == ch,
            .any => true,
            .class => |class| blk: {
                const matched = class.table[text[cursor]];
                break :blk (matched and !class.negated) or (!matched and class.negated);
            },
            .group => false,
        };
        if (!ok) break;
        count += 1;
    }
    return count;
}

fn cloneGroups(alloc: std.mem.Allocator, groups: []GroupSpan) ParseError![]GroupSpan {
    const out = alloc.alloc(GroupSpan, groups.len) catch return ParseError.OutOfMemory;
    std.mem.copyForwards(GroupSpan, out, groups);
    return out;
}

fn matchRepeat(alloc: std.mem.Allocator, token: Token, count: usize, text: []const u8, pos: *usize, groups: []GroupSpan) ParseError!bool {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const next_pos = try matchAtomOnce(alloc, token, text, pos.*, groups);
        if (next_pos == null) return false;
        pos.* = next_pos.?;
    }
    return true;
}

fn matchFrom(alloc: std.mem.Allocator, tokens: []Token, idx: usize, text: []const u8, pos: usize, groups: []GroupSpan) ParseError!?usize {
    if (idx >= tokens.len) return pos;
    const token = tokens[idx];

    if (token.atom == .group and (token.quant.min != 1 or token.quant.max != 1)) {
        return ParseError.UnsupportedPattern;
    }

    const max_possible = if (token.quant.max) |limit| limit else maxRepeatSingle(token, text, pos);
    const max_count = if (max_possible < token.quant.min) token.quant.min else max_possible;

    var count: isize = @intCast(max_count);
    while (count >= @as(isize, @intCast(token.quant.min))) : (count -= 1) {
        const count_u: usize = @intCast(count);
        const groups_copy = try cloneGroups(alloc, groups);
        var new_pos = pos;
        if (!try matchRepeat(alloc, token, count_u, text, &new_pos, groups_copy)) continue;
        if (try matchFrom(alloc, tokens, idx + 1, text, new_pos, groups_copy)) |end_pos| {
            std.mem.copyForwards(GroupSpan, groups, groups_copy);
            return end_pos;
        }
    }
    return null;
}

fn buildMatchObject(text: []const u8, start: usize, end: usize, groups: []GroupSpan) void {
    _ = c.py_newobject(c.py_retval(), tp_match, -1, 0);
    const match_obj = c.py_retval();

    c.py_newlist(c.py_r0());
    const group_list = c.py_r0();
    c.py_newlist(c.py_r1());
    const span_list = c.py_r1();

    const full = text[start..end];
    const full_sv = c.c11_sv{ .data = full.ptr, .size = @intCast(full.len) };
    c.py_newstrv(c.py_r2(), full_sv);
    c.py_list_append(group_list, c.py_r2());

    _ = c.py_newtuple(c.py_r2(), 2);
    c.py_newint(c.py_r3(), @intCast(start));
    c.py_tuple_setitem(c.py_r2(), 0, c.py_r3());
    c.py_newint(c.py_r3(), @intCast(end));
    c.py_tuple_setitem(c.py_r2(), 1, c.py_r3());
    c.py_list_append(span_list, c.py_r2());

    var i: usize = 1;
    while (i < groups.len) : (i += 1) {
        if (groups[i].matched) {
            const slice = text[groups[i].start..groups[i].end];
            const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
            c.py_newstrv(c.py_r2(), sv);
        } else {
            c.py_newnone(c.py_r2());
        }
        c.py_list_append(group_list, c.py_r2());

        _ = c.py_newtuple(c.py_r2(), 2);
        c.py_newint(c.py_r3(), @intCast(groups[i].start));
        c.py_tuple_setitem(c.py_r2(), 0, c.py_r3());
        c.py_newint(c.py_r3(), @intCast(groups[i].end));
        c.py_tuple_setitem(c.py_r2(), 1, c.py_r3());
        c.py_list_append(span_list, c.py_r2());
    }

    c.py_setdict(match_obj, c.py_name(re_groups_key), group_list);
    c.py_setdict(match_obj, c.py_name(re_spans_key), span_list);
}

fn execMatch(pattern: Pattern, text: []const u8, search: bool) ParseError!?c.py_Ref {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var start_pos: usize = 0;
    if (pattern.anchor_start or !search) {
        start_pos = 0;
    }

    var pos = start_pos;
    while (pos <= text.len) : (pos += 1) {
        if (pattern.anchor_start and pos != 0) break;
        var groups = alloc.alloc(GroupSpan, pattern.group_count + 1) catch return ParseError.OutOfMemory;
        var i: usize = 0;
        while (i < groups.len) : (i += 1) {
            groups[i] = .{ .start = 0, .end = 0, .matched = false };
        }

        if (try matchFrom(alloc, pattern.tokens, 0, text, pos, groups)) |end_pos| {
            if (pattern.anchor_end and end_pos != text.len) {
                continue;
            }
            groups[0] = .{ .start = pos, .end = end_pos, .matched = true };
            buildMatchObject(text, pos, end_pos, groups);
            return c.py_retval();
        }
        if (!search) break;
    }
    return null;
}

fn getPatternString(obj: c.py_Ref) ?[]const u8 {
    const item = c.py_getdict(obj, c.py_name("pattern"));
    if (item == null) return null;
    const str_c = c.py_tostr(item.?);
    if (str_c == null) return null;
    return std.mem.span(str_c);
}

fn matchFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "expected 2 arguments");
    const pat_c = c.py_tostr(pk.argRef(argv, 0));
    if (pat_c == null) return c.py_exception(c.tp_TypeError, "pattern must be a string");
    const text_c = c.py_tostr(pk.argRef(argv, 1));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");

    const pattern = std.mem.span(pat_c);
    const text = std.mem.span(text_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const pat = parsePattern(arena.allocator(), pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    const res = execMatch(pat, text, false) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };
    if (res == null) c.py_newnone(c.py_retval());
    return true;
}

fn searchFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "expected 2 arguments");
    const pat_c = c.py_tostr(pk.argRef(argv, 0));
    if (pat_c == null) return c.py_exception(c.tp_TypeError, "pattern must be a string");
    const text_c = c.py_tostr(pk.argRef(argv, 1));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");

    const pattern = std.mem.span(pat_c);
    const text = std.mem.span(text_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const pat = parsePattern(arena.allocator(), pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    const res = execMatch(pat, text, true) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };
    if (res == null) c.py_newnone(c.py_retval());
    return true;
}

fn findallFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "expected 2 arguments");
    const pat_c = c.py_tostr(pk.argRef(argv, 0));
    if (pat_c == null) return c.py_exception(c.tp_TypeError, "pattern must be a string");
    const text_c = c.py_tostr(pk.argRef(argv, 1));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");

    const pattern = std.mem.span(pat_c);
    const text = std.mem.span(text_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const pat = parsePattern(arena.allocator(), pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    c.py_newlist(c.py_r4());
    const out = c.py_r4();

    var pos: usize = 0;
    while (pos <= text.len) {
        const res = execMatch(pat, text[pos..], true) catch {
            return c.py_exception(c.tp_ValueError, "invalid pattern");
        };
        if (res == null) break;
        const match_obj = res.?;
        const spans = c.py_getdict(match_obj, c.py_name(re_spans_key)) orelse break;
        const group_count = pat.group_count;
        if (group_count == 0) {
            const span0 = c.py_list_getitem(spans, 0);
            const start_val = c.py_tuple_getitem(span0, 0);
            const end_val = c.py_tuple_getitem(span0, 1);
            const start_off = @as(usize, @intCast(c.py_toint(start_val)));
            const end_off = @as(usize, @intCast(c.py_toint(end_val)));
            const slice = text[pos + start_off .. pos + end_off];
            const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
            c.py_newstrv(c.py_r1(), sv);
            c.py_list_append(out, c.py_r1());
        } else if (group_count == 1) {
            const span1 = c.py_list_getitem(spans, 1);
            const start_val = c.py_tuple_getitem(span1, 0);
            const end_val = c.py_tuple_getitem(span1, 1);
            const start_off = @as(usize, @intCast(c.py_toint(start_val)));
            const end_off = @as(usize, @intCast(c.py_toint(end_val)));
            const slice = text[pos + start_off .. pos + end_off];
            const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
            c.py_newstrv(c.py_r1(), sv);
            c.py_list_append(out, c.py_r1());
        } else {
            _ = c.py_newtuple(c.py_r1(), @intCast(group_count));
            var i: usize = 1;
            while (i <= group_count) : (i += 1) {
                const span = c.py_list_getitem(spans, @intCast(i));
                const start_val = c.py_tuple_getitem(span, 0);
                const end_val = c.py_tuple_getitem(span, 1);
                const start_off = @as(usize, @intCast(c.py_toint(start_val)));
                const end_off = @as(usize, @intCast(c.py_toint(end_val)));
                const slice = text[pos + start_off .. pos + end_off];
                const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
                c.py_newstrv(c.py_r2(), sv);
                c.py_tuple_setitem(c.py_r1(), @intCast(i - 1), c.py_r2());
            }
            c.py_list_append(out, c.py_r1());
        }

        const span0 = c.py_list_getitem(spans, 0);
        const start_val = c.py_tuple_getitem(span0, 0);
        const end_val = c.py_tuple_getitem(span0, 1);
        const start_off = @as(usize, @intCast(c.py_toint(start_val)));
        const end_off = @as(usize, @intCast(c.py_toint(end_val)));
        const advance = if (end_off > start_off) end_off else start_off + 1;
        pos = pos + advance;
    }
    pk.setRetval(out);
    return true;
}

fn replaceWithGroups(alloc: std.mem.Allocator, repl: []const u8, text: []const u8, groups: []GroupSpan) ParseError![]u8 {
    var out = std.ArrayList(u8).empty;
    var i: usize = 0;
    while (i < repl.len) : (i += 1) {
        if (repl[i] == '\\' and i + 1 < repl.len) {
            const next = repl[i + 1];
            if (next >= '0' and next <= '9') {
                const idx = next - '0';
                if (idx < groups.len and groups[idx].matched) {
                    const slice = text[groups[idx].start..groups[idx].end];
                    out.appendSlice(alloc, slice) catch return ParseError.OutOfMemory;
                }
                i += 1;
                continue;
            }
        }
        out.append(alloc, repl[i]) catch return ParseError.OutOfMemory;
    }
    return out.toOwnedSlice(alloc) catch ParseError.OutOfMemory;
}

fn subFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 3 or argc > 4) return c.py_exception(c.tp_TypeError, "expected 3 or 4 arguments");
    const pat_c = c.py_tostr(pk.argRef(argv, 0));
    if (pat_c == null) return c.py_exception(c.tp_TypeError, "pattern must be a string");
    const repl_c = c.py_tostr(pk.argRef(argv, 1));
    if (repl_c == null) return c.py_exception(c.tp_TypeError, "replacement must be a string");
    const text_c = c.py_tostr(pk.argRef(argv, 2));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");

    var count_limit: usize = std.math.maxInt(usize);
    if (argc == 4) {
        const count_val = c.py_toint(pk.argRef(argv, 3));
        if (count_val >= 0) count_limit = @intCast(count_val);
    }

    const pattern = std.mem.span(pat_c);
    const repl = std.mem.span(repl_c);
    const text = std.mem.span(text_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const pat = parsePattern(alloc, pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    var out = std.ArrayList(u8).empty;
    var pos: usize = 0;
    var replaced: usize = 0;
    while (pos <= text.len and replaced < count_limit) {
        const res = execMatch(pat, text[pos..], true) catch {
            return c.py_exception(c.tp_ValueError, "invalid pattern");
        };
        if (res == null) break;
        const match_obj = res.?;
        const spans = c.py_getdict(match_obj, c.py_name(re_spans_key)) orelse break;
        const span0 = c.py_list_getitem(spans, 0);
        const start_val = c.py_tuple_getitem(span0, 0);
        const end_val = c.py_tuple_getitem(span0, 1);
        const start_off = @as(usize, @intCast(c.py_toint(start_val)));
        const end_off = @as(usize, @intCast(c.py_toint(end_val)));

        const abs_start = pos + start_off;
        const abs_end = pos + end_off;

        out.appendSlice(alloc, text[pos..abs_start]) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

        var groups = alloc.alloc(GroupSpan, pat.group_count + 1) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        var i: usize = 0;
        while (i < groups.len) : (i += 1) {
            groups[i] = .{ .start = 0, .end = 0, .matched = false };
        }
        const spans_list = c.py_getdict(match_obj, c.py_name(re_spans_key)) orelse break;
        i = 0;
        while (i < groups.len) : (i += 1) {
            const span = c.py_list_getitem(spans_list, @intCast(i));
            const s = @as(usize, @intCast(c.py_toint(c.py_tuple_getitem(span, 0))));
            const e = @as(usize, @intCast(c.py_toint(c.py_tuple_getitem(span, 1))));
            groups[i] = .{ .start = pos + s, .end = pos + e, .matched = true };
        }

        const repl_out = replaceWithGroups(alloc, repl, text, groups) catch {
            return c.py_exception(c.tp_RuntimeError, "out of memory");
        };
        out.appendSlice(alloc, repl_out) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

        replaced += 1;
        pos = if (abs_end > abs_start) abs_end else abs_start + 1;
    }

    if (pos < text.len) {
        out.appendSlice(alloc, text[pos..]) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    }

    const out_slice = out.toOwnedSlice(alloc) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    const sv = c.c11_sv{ .data = out_slice.ptr, .size = @intCast(out_slice.len) };
    c.py_newstrv(c.py_retval(), sv);
    return true;
}

fn splitFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2 or argc > 3) return c.py_exception(c.tp_TypeError, "expected 2 or 3 arguments");
    const pat_c = c.py_tostr(pk.argRef(argv, 0));
    if (pat_c == null) return c.py_exception(c.tp_TypeError, "pattern must be a string");
    const text_c = c.py_tostr(pk.argRef(argv, 1));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");

    var maxsplit: usize = std.math.maxInt(usize);
    if (argc == 3) {
        const val = c.py_toint(pk.argRef(argv, 2));
        if (val >= 0) maxsplit = @intCast(val);
    }

    const pattern = std.mem.span(pat_c);
    const text = std.mem.span(text_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const pat = parsePattern(alloc, pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    c.py_newlist(c.py_r4());
    const out = c.py_r4();

    var pos: usize = 0;
    var splits: usize = 0;
    while (pos <= text.len and splits < maxsplit) {
        const res = execMatch(pat, text[pos..], true) catch {
            return c.py_exception(c.tp_ValueError, "invalid pattern");
        };
        if (res == null) break;
        const match_obj = res.?;
        const spans = c.py_getdict(match_obj, c.py_name(re_spans_key)) orelse break;
        const span0 = c.py_list_getitem(spans, 0);
        const start_val = c.py_tuple_getitem(span0, 0);
        const end_val = c.py_tuple_getitem(span0, 1);
        const start_off = @as(usize, @intCast(c.py_toint(start_val)));
        const end_off = @as(usize, @intCast(c.py_toint(end_val)));
        const abs_start = pos + start_off;
        const abs_end = pos + end_off;

        const slice = text[pos..abs_start];
        const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
        c.py_newstrv(c.py_r0(), sv);
        c.py_list_append(out, c.py_r0());

        splits += 1;
        pos = if (abs_end > abs_start) abs_end else abs_start + 1;
    }

    const tail = text[pos..];
    const tail_sv = c.c11_sv{ .data = tail.ptr, .size = @intCast(tail.len) };
    c.py_newstrv(c.py_r0(), tail_sv);
    c.py_list_append(out, c.py_r0());
    pk.setRetval(out);
    return true;
}

fn compileFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "expected 1 argument");
    const pat_c = c.py_tostr(pk.argRef(argv, 0));
    if (pat_c == null) return c.py_exception(c.tp_TypeError, "pattern must be a string");

    _ = c.py_newobject(c.py_retval(), tp_pattern, -1, 0);
    const pat_obj = c.py_retval();
    c.py_newstr(c.py_r0(), pat_c);
    c.py_setdict(pat_obj, c.py_name("pattern"), c.py_r0());
    return true;
}

fn patternMatch(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "expected 1 argument");
    const self = pk.argRef(argv, 0);
    const text_c = c.py_tostr(pk.argRef(argv, 1));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");
    const pattern = getPatternString(self) orelse return c.py_exception(c.tp_ValueError, "pattern missing");
    const text = std.mem.span(text_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const pat = parsePattern(arena.allocator(), pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    const res = execMatch(pat, text, false) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };
    if (res == null) c.py_newnone(c.py_retval());
    return true;
}

fn patternSearch(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "expected 1 argument");
    const self = pk.argRef(argv, 0);
    const text_c = c.py_tostr(pk.argRef(argv, 1));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");
    const pattern = getPatternString(self) orelse return c.py_exception(c.tp_ValueError, "pattern missing");
    const text = std.mem.span(text_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const pat = parsePattern(arena.allocator(), pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    const res = execMatch(pat, text, true) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };
    if (res == null) c.py_newnone(c.py_retval());
    return true;
}

fn patternFindall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "expected 1 argument");
    const self = pk.argRef(argv, 0);
    const text_c = c.py_tostr(pk.argRef(argv, 1));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");
    const pattern = getPatternString(self) orelse return c.py_exception(c.tp_ValueError, "pattern missing");
    const text = std.mem.span(text_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const pat = parsePattern(arena.allocator(), pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    c.py_newlist(c.py_r4());
    const out = c.py_r4();

    var pos: usize = 0;
    while (pos <= text.len) {
        const res = execMatch(pat, text[pos..], true) catch {
            return c.py_exception(c.tp_ValueError, "invalid pattern");
        };
        if (res == null) break;
        const match_obj = res.?;
        const spans = c.py_getdict(match_obj, c.py_name(re_spans_key)) orelse break;
        const group_count = pat.group_count;
        if (group_count == 0) {
            const span0 = c.py_list_getitem(spans, 0);
            const start_val = c.py_tuple_getitem(span0, 0);
            const end_val = c.py_tuple_getitem(span0, 1);
            const start_off = @as(usize, @intCast(c.py_toint(start_val)));
            const end_off = @as(usize, @intCast(c.py_toint(end_val)));
            const slice = text[pos + start_off .. pos + end_off];
            const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
            c.py_newstrv(c.py_r1(), sv);
            c.py_list_append(out, c.py_r1());
        } else if (group_count == 1) {
            const span1 = c.py_list_getitem(spans, 1);
            const start_val = c.py_tuple_getitem(span1, 0);
            const end_val = c.py_tuple_getitem(span1, 1);
            const start_off = @as(usize, @intCast(c.py_toint(start_val)));
            const end_off = @as(usize, @intCast(c.py_toint(end_val)));
            const slice = text[pos + start_off .. pos + end_off];
            const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
            c.py_newstrv(c.py_r1(), sv);
            c.py_list_append(out, c.py_r1());
        } else {
            _ = c.py_newtuple(c.py_r1(), @intCast(group_count));
            var i: usize = 1;
            while (i <= group_count) : (i += 1) {
                const span = c.py_list_getitem(spans, @intCast(i));
                const start_val = c.py_tuple_getitem(span, 0);
                const end_val = c.py_tuple_getitem(span, 1);
                const start_off = @as(usize, @intCast(c.py_toint(start_val)));
                const end_off = @as(usize, @intCast(c.py_toint(end_val)));
                const slice = text[pos + start_off .. pos + end_off];
                const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
                c.py_newstrv(c.py_r2(), sv);
                c.py_tuple_setitem(c.py_r1(), @intCast(i - 1), c.py_r2());
            }
            c.py_list_append(out, c.py_r1());
        }

        const span0 = c.py_list_getitem(spans, 0);
        const start_val = c.py_tuple_getitem(span0, 0);
        const end_val = c.py_tuple_getitem(span0, 1);
        const start_off = @as(usize, @intCast(c.py_toint(start_val)));
        const end_off = @as(usize, @intCast(c.py_toint(end_val)));
        const advance = if (end_off > start_off) end_off else start_off + 1;
        pos = pos + advance;
    }
    pk.setRetval(out);
    return true;
}

fn patternSub(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 3 or argc > 4) return c.py_exception(c.tp_TypeError, "sub() expected 2 or 3 arguments");
    const self = pk.argRef(argv, 0);
    const pattern = getPatternString(self) orelse return c.py_exception(c.tp_ValueError, "pattern missing");

    const repl_c = c.py_tostr(pk.argRef(argv, 1));
    if (repl_c == null) return c.py_exception(c.tp_TypeError, "replacement must be a string");
    const text_c = c.py_tostr(pk.argRef(argv, 2));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");

    var count_limit: usize = std.math.maxInt(usize);
    if (argc == 4) {
        const count_val = c.py_toint(pk.argRef(argv, 3));
        if (count_val >= 0) count_limit = @intCast(count_val);
    }

    const repl = std.mem.span(repl_c);
    const text = std.mem.span(text_c);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const pat = parsePattern(alloc, pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    var out = std.ArrayList(u8).empty;
    var pos: usize = 0;
    var replaced: usize = 0;
    while (pos <= text.len and replaced < count_limit) {
        const res = execMatch(pat, text[pos..], true) catch {
            return c.py_exception(c.tp_ValueError, "invalid pattern");
        };
        if (res == null) break;
        const match_obj = res.?;
        const spans = c.py_getdict(match_obj, c.py_name(re_spans_key)) orelse break;
        const span0 = c.py_list_getitem(spans, 0);
        const start_val = c.py_tuple_getitem(span0, 0);
        const end_val = c.py_tuple_getitem(span0, 1);
        const start_off = @as(usize, @intCast(c.py_toint(start_val)));
        const end_off = @as(usize, @intCast(c.py_toint(end_val)));
        const abs_start = pos + start_off;
        const abs_end = pos + end_off;

        out.appendSlice(alloc, text[pos..abs_start]) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

        var groups = alloc.alloc(GroupSpan, pat.group_count + 1) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        var i: usize = 0;
        while (i < groups.len) : (i += 1) groups[i] = .{ .start = 0, .end = 0, .matched = false };

        const spans_list = c.py_getdict(match_obj, c.py_name(re_spans_key)) orelse break;
        i = 0;
        while (i < groups.len) : (i += 1) {
            const span = c.py_list_getitem(spans_list, @intCast(i));
            const s = @as(usize, @intCast(c.py_toint(c.py_tuple_getitem(span, 0))));
            const e = @as(usize, @intCast(c.py_toint(c.py_tuple_getitem(span, 1))));
            groups[i] = .{ .start = pos + s, .end = pos + e, .matched = true };
        }

        const repl_out = replaceWithGroups(alloc, repl, text, groups) catch {
            return c.py_exception(c.tp_RuntimeError, "out of memory");
        };
        out.appendSlice(alloc, repl_out) catch return c.py_exception(c.tp_RuntimeError, "out of memory");

        replaced += 1;
        pos = if (abs_end > abs_start) abs_end else abs_start + 1;
    }

    if (pos < text.len) {
        out.appendSlice(alloc, text[pos..]) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    }

    const out_slice = out.toOwnedSlice(alloc) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
    const sv = c.c11_sv{ .data = out_slice.ptr, .size = @intCast(out_slice.len) };
    c.py_newstrv(c.py_retval(), sv);
    return true;
}

fn patternSplit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2 and argc != 3) return c.py_exception(c.tp_TypeError, "split() expected 1 or 2 arguments");
    const self = pk.argRef(argv, 0);
    const pattern = getPatternString(self) orelse return c.py_exception(c.tp_ValueError, "pattern missing");
    const text_c = c.py_tostr(pk.argRef(argv, 1));
    if (text_c == null) return c.py_exception(c.tp_TypeError, "text must be a string");
    var maxsplit: usize = std.math.maxInt(usize);
    if (argc == 3) {
        const val = c.py_toint(pk.argRef(argv, 2));
        if (val >= 0) maxsplit = @intCast(val);
    }

    const text = std.mem.span(text_c);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const pat = parsePattern(alloc, pattern) catch {
        return c.py_exception(c.tp_ValueError, "invalid pattern");
    };

    c.py_newlist(c.py_r4());
    const out = c.py_r4();

    var pos: usize = 0;
    var splits: usize = 0;
    while (pos <= text.len and splits < maxsplit) {
        const res = execMatch(pat, text[pos..], true) catch {
            return c.py_exception(c.tp_ValueError, "invalid pattern");
        };
        if (res == null) break;
        const match_obj = res.?;
        const spans = c.py_getdict(match_obj, c.py_name(re_spans_key)) orelse break;
        const span0 = c.py_list_getitem(spans, 0);
        const start_val = c.py_tuple_getitem(span0, 0);
        const end_val = c.py_tuple_getitem(span0, 1);
        const start_off = @as(usize, @intCast(c.py_toint(start_val)));
        const end_off = @as(usize, @intCast(c.py_toint(end_val)));
        const abs_start = pos + start_off;
        const abs_end = pos + end_off;

        const slice = text[pos..abs_start];
        const sv = c.c11_sv{ .data = slice.ptr, .size = @intCast(slice.len) };
        c.py_newstrv(c.py_r0(), sv);
        c.py_list_append(out, c.py_r0());

        splits += 1;
        pos = if (abs_end > abs_start) abs_end else abs_start + 1;
    }

    const tail = text[pos..];
    const tail_sv = c.c11_sv{ .data = tail.ptr, .size = @intCast(tail.len) };
    c.py_newstrv(c.py_r0(), tail_sv);
    c.py_list_append(out, c.py_r0());
    pk.setRetval(out);
    return true;
}

fn groupFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "expected 0 or 1 argument");
    const self = pk.argRef(argv, 0);
    var idx: usize = 0;
    if (argc == 2) {
        const val = c.py_toint(pk.argRef(argv, 1));
        if (val < 0) return c.py_exception(c.tp_IndexError, "group index out of range");
        idx = @intCast(val);
    }
    const groups = c.py_getdict(self, c.py_name(re_groups_key)) orelse return c.py_exception(c.tp_RuntimeError, "groups not available");
    const len = c.py_list_len(groups);
    if (idx >= @as(usize, @intCast(len))) return c.py_exception(c.tp_IndexError, "group index out of range");
    const item = c.py_list_getitem(groups, @intCast(idx));
    pk.setRetval(item);
    return true;
}

fn groupsFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "expected 0 arguments");
    const self = pk.argRef(argv, 0);
    const groups = c.py_getdict(self, c.py_name(re_groups_key)) orelse return c.py_exception(c.tp_RuntimeError, "groups not available");
    const len = c.py_list_len(groups);
    if (len <= 1) {
        _ = c.py_newtuple(c.py_retval(), 0);
        return true;
    }
    _ = c.py_newtuple(c.py_retval(), len - 1);
    var i: c_int = 1;
    while (i < len) : (i += 1) {
        c.py_tuple_setitem(c.py_retval(), i - 1, c.py_list_getitem(groups, i));
    }
    return true;
}

fn spanFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "expected 0 or 1 argument");
    const self = pk.argRef(argv, 0);
    var idx: usize = 0;
    if (argc == 2) {
        const val = c.py_toint(pk.argRef(argv, 1));
        if (val < 0) return c.py_exception(c.tp_IndexError, "group index out of range");
        idx = @intCast(val);
    }
    const spans = c.py_getdict(self, c.py_name(re_spans_key)) orelse return c.py_exception(c.tp_RuntimeError, "spans not available");
    const len = c.py_list_len(spans);
    if (idx >= @as(usize, @intCast(len))) return c.py_exception(c.tp_IndexError, "group index out of range");
    pk.setRetval(c.py_list_getitem(spans, @intCast(idx)));
    return true;
}

fn startFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "expected 0 or 1 argument");
    const self = pk.argRef(argv, 0);
    var idx: usize = 0;
    if (argc == 2) {
        const val = c.py_toint(pk.argRef(argv, 1));
        if (val < 0) return c.py_exception(c.tp_IndexError, "group index out of range");
        idx = @intCast(val);
    }
    const spans = c.py_getdict(self, c.py_name(re_spans_key)) orelse return c.py_exception(c.tp_RuntimeError, "spans not available");
    const len = c.py_list_len(spans);
    if (idx >= @as(usize, @intCast(len))) return c.py_exception(c.tp_IndexError, "group index out of range");
    const span = c.py_list_getitem(spans, @intCast(idx));
    pk.setRetval(c.py_tuple_getitem(span, 0));
    return true;
}

fn endFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1 and argc != 2) return c.py_exception(c.tp_TypeError, "expected 0 or 1 argument");
    const self = pk.argRef(argv, 0);
    var idx: usize = 0;
    if (argc == 2) {
        const val = c.py_toint(pk.argRef(argv, 1));
        if (val < 0) return c.py_exception(c.tp_IndexError, "group index out of range");
        idx = @intCast(val);
    }
    const spans = c.py_getdict(self, c.py_name(re_spans_key)) orelse return c.py_exception(c.tp_RuntimeError, "spans not available");
    const len = c.py_list_len(spans);
    if (idx >= @as(usize, @intCast(len))) return c.py_exception(c.tp_IndexError, "group index out of range");
    const span = c.py_list_getitem(spans, @intCast(idx));
    pk.setRetval(c.py_tuple_getitem(span, 1));
    return true;
}

pub fn register() void {
    const name: [:0]const u8 = "re";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);
    tp_match = c.py_newtype("Match", c.tp_object, module, null);
    tp_pattern = c.py_newtype("Pattern", c.tp_object, module, null);

    c.py_bindmethod(tp_match, "group", groupFn);
    c.py_bindmethod(tp_match, "groups", groupsFn);
    c.py_bindmethod(tp_match, "span", spanFn);
    c.py_bindmethod(tp_match, "start", startFn);
    c.py_bindmethod(tp_match, "end", endFn);

    c.py_bindmethod(tp_pattern, "match", patternMatch);
    c.py_bindmethod(tp_pattern, "search", patternSearch);
    c.py_bindmethod(tp_pattern, "findall", patternFindall);
    c.py_bindmethod(tp_pattern, "sub", patternSub);
    c.py_bindmethod(tp_pattern, "split", patternSplit);

    c.py_bindfunc(module, "match", matchFn);
    c.py_bindfunc(module, "search", searchFn);
    c.py_bindfunc(module, "findall", findallFn);
    c.py_bindfunc(module, "sub", subFn);
    c.py_bindfunc(module, "split", splitFn);
    c.py_bindfunc(module, "compile", compileFn);
}
