const std = @import("std");
const pk = @import("pk");
const c = pk.c;

// Match a character against a character class like [abc] or [a-z] or [!abc]
// Returns the number of pattern characters consumed (0 if no match, >0 if match)
fn matchCharClass(pattern: []const u8, ch: u8) struct { matched: bool, consumed: usize } {
    if (pattern.len < 2 or pattern[0] != '[') {
        return .{ .matched = false, .consumed = 0 };
    }

    var i: usize = 1;
    var negate = false;
    var matched = false;

    // Check for negation
    if (i < pattern.len and (pattern[i] == '!' or pattern[i] == '^')) {
        negate = true;
        i += 1;
    }

    // Find the closing bracket
    const start = i;
    while (i < pattern.len) {
        // Handle literal ] at start of class
        if (pattern[i] == ']' and i > start) {
            break;
        }

        // Handle range like a-z
        if (i + 2 < pattern.len and pattern[i + 1] == '-' and pattern[i + 2] != ']') {
            const lo = pattern[i];
            const hi = pattern[i + 2];
            if (ch >= lo and ch <= hi) {
                matched = true;
            }
            i += 3;
        } else {
            // Single character
            if (pattern[i] == ch) {
                matched = true;
            }
            i += 1;
        }
    }

    // Check if we found closing bracket
    if (i >= pattern.len or pattern[i] != ']') {
        // Invalid class, treat [ as literal
        return .{ .matched = false, .consumed = 0 };
    }

    if (negate) {
        matched = !matched;
    }

    return .{ .matched = matched, .consumed = i + 1 };
}

fn wildMatch(pattern: []const u8, text: []const u8) bool {
    var pi: usize = 0;
    var ti: usize = 0;
    var star_idx: ?usize = null;
    var match_idx: usize = 0;

    while (ti < text.len) {
        if (pi < pattern.len) {
            // Check for character class [...]
            if (pattern[pi] == '[') {
                const result = matchCharClass(pattern[pi..], text[ti]);
                if (result.consumed > 0) {
                    if (result.matched) {
                        pi += result.consumed;
                        ti += 1;
                        continue;
                    } else {
                        // No match in character class
                        if (star_idx) |s| {
                            pi = s + 1;
                            match_idx += 1;
                            ti = match_idx;
                            continue;
                        }
                        return false;
                    }
                }
                // Invalid class, treat [ as literal and fall through
            }

            // Regular character match or ?
            if (pattern[pi] == text[ti] or pattern[pi] == '?') {
                pi += 1;
                ti += 1;
                continue;
            }

            // Wildcard *
            if (pattern[pi] == '*') {
                star_idx = pi;
                match_idx = ti;
                pi += 1;
                continue;
            }
        }

        // No match - try backtracking to last *
        if (star_idx) |s| {
            pi = s + 1;
            match_idx += 1;
            ti = match_idx;
        } else {
            return false;
        }
    }

    // Consume trailing wildcards
    while (pi < pattern.len and pattern[pi] == '*') {
        pi += 1;
    }

    return pi == pattern.len;
}

fn fnmatchFn(ctx: *pk.Context) bool {
    const name = ctx.argStr(0) orelse return ctx.typeError("name must be a string");
    const pat = ctx.argStr(1) orelse return ctx.typeError("pattern must be a string");

    return ctx.returnBool(wildMatch(pat, name));
}

fn fnmatchcaseFn(ctx: *pk.Context) bool {
    // Case-insensitive version - for now just call fnmatch
    // TODO: implement proper case folding
    return fnmatchFn(ctx);
}

fn filterFn(ctx: *pk.Context) bool {
    var names_arg = ctx.arg(0) orelse return ctx.typeError("names required");
    const pat = ctx.argStr(1) orelse return ctx.typeError("pattern must be a string");

    if (!names_arg.isList()) {
        return ctx.typeError("names must be a list");
    }

    c.py_newlist(c.py_retval());

    const names = names_arg.ref();
    const len = c.py_list_len(names);
    var i: c_int = 0;
    while (i < len) : (i += 1) {
        const item = c.py_list_getitem(names, i);
        if (!c.py_isstr(item)) continue;

        const name_sv = c.py_tosv(item);
        const name = name_sv.data[0..@intCast(name_sv.size)];

        if (wildMatch(pat, name)) {
            c.py_list_append(c.py_retval(), item);
        }
    }

    return true;
}

fn translateFn(ctx: *pk.Context) bool {
    const pat = ctx.argStr(0) orelse return ctx.typeError("pattern must be a string");

    // Allocate buffer for regex (worst case: each char becomes 2 chars + anchors)
    var buf: [1024]u8 = undefined;
    var out_len: usize = 0;

    // Start anchor
    if (out_len < buf.len) {
        buf[out_len] = '(';
        out_len += 1;
    }
    if (out_len < buf.len) {
        buf[out_len] = '?';
        out_len += 1;
    }
    if (out_len < buf.len) {
        buf[out_len] = 's';
        out_len += 1;
    }
    if (out_len < buf.len) {
        buf[out_len] = ')';
        out_len += 1;
    }

    for (pat) |ch| {
        if (out_len >= buf.len - 4) break;

        switch (ch) {
            '*' => {
                buf[out_len] = '.';
                out_len += 1;
                buf[out_len] = '*';
                out_len += 1;
            },
            '?' => {
                buf[out_len] = '.';
                out_len += 1;
            },
            '.', '^', '$', '+', '{', '}', '|', '(', ')', '\\' => {
                buf[out_len] = '\\';
                out_len += 1;
                buf[out_len] = ch;
                out_len += 1;
            },
            else => {
                buf[out_len] = ch;
                out_len += 1;
            },
        }
    }

    // End anchor
    if (out_len < buf.len) {
        buf[out_len] = '\\';
        out_len += 1;
    }
    if (out_len < buf.len) {
        buf[out_len] = 'Z';
        out_len += 1;
    }

    return ctx.returnStr(buf[0..out_len]);
}

pub fn match(pattern: []const u8, text: []const u8) bool {
    return wildMatch(pattern, text);
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("fnmatch");
    _ = builder
        .funcWrapped("fnmatch", 2, 2, fnmatchFn)
        .funcWrapped("fnmatchcase", 2, 2, fnmatchcaseFn)
        .funcWrapped("filter", 2, 2, filterFn)
        .funcWrapped("translate", 1, 1, translateFn);
}
