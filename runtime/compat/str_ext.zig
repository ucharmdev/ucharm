/// str_ext.zig - String method extensions for PocketPy
///
/// Adds missing CPython string methods like isdigit(), isalpha(), etc.
/// These are added to the built-in str type at runtime.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn isdigitFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("isdigit requires a string");
    if (s.len == 0) return ctx.returnBool(false);
    for (s) |ch| {
        if (ch < '0' or ch > '9') return ctx.returnBool(false);
    }
    return ctx.returnBool(true);
}

fn isalphaFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("isalpha requires a string");
    if (s.len == 0) return ctx.returnBool(false);
    for (s) |ch| {
        if (!((ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z'))) return ctx.returnBool(false);
    }
    return ctx.returnBool(true);
}

fn isalnumFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("isalnum requires a string");
    if (s.len == 0) return ctx.returnBool(false);
    for (s) |ch| {
        const is_letter = (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z');
        const is_digit = ch >= '0' and ch <= '9';
        if (!is_letter and !is_digit) return ctx.returnBool(false);
    }
    return ctx.returnBool(true);
}

fn isspaceFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("isspace requires a string");
    if (s.len == 0) return ctx.returnBool(false);
    for (s) |ch| {
        if (ch != ' ' and ch != '\t' and ch != '\n' and ch != '\r' and ch != '\x0b' and ch != '\x0c') {
            return ctx.returnBool(false);
        }
    }
    return ctx.returnBool(true);
}

fn isupperFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("isupper requires a string");
    var has_cased = false;
    for (s) |ch| {
        if (ch >= 'a' and ch <= 'z') return ctx.returnBool(false);
        if (ch >= 'A' and ch <= 'Z') has_cased = true;
    }
    return ctx.returnBool(has_cased);
}

fn islowerFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("islower requires a string");
    var has_cased = false;
    for (s) |ch| {
        if (ch >= 'A' and ch <= 'Z') return ctx.returnBool(false);
        if (ch >= 'a' and ch <= 'z') has_cased = true;
    }
    return ctx.returnBool(has_cased);
}

fn istitleFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("istitle requires a string");
    if (s.len == 0) return ctx.returnBool(false);
    var prev_cased = false;
    var has_cased = false;
    for (s) |ch| {
        const is_upper = ch >= 'A' and ch <= 'Z';
        const is_lower = ch >= 'a' and ch <= 'z';
        if (is_upper) {
            if (prev_cased) return ctx.returnBool(false);
            prev_cased = true;
            has_cased = true;
        } else if (is_lower) {
            if (!prev_cased) return ctx.returnBool(false);
            prev_cased = true;
            has_cased = true;
        } else {
            prev_cased = false;
        }
    }
    return ctx.returnBool(has_cased);
}

fn isdecimalFn(ctx: *pk.Context) bool {
    // For ASCII, isdecimal is the same as isdigit
    return isdigitFn(ctx);
}

fn isnumericFn(ctx: *pk.Context) bool {
    // For ASCII, isnumeric is the same as isdigit
    return isdigitFn(ctx);
}

fn isidentifierFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("isidentifier requires a string");
    if (s.len == 0) return ctx.returnBool(false);
    // First character must be letter or underscore
    const first = s[0];
    if (!((first >= 'a' and first <= 'z') or (first >= 'A' and first <= 'Z') or first == '_')) {
        return ctx.returnBool(false);
    }
    // Rest can be letter, digit, or underscore
    for (s[1..]) |ch| {
        const is_letter = (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z');
        const is_digit = ch >= '0' and ch <= '9';
        if (!is_letter and !is_digit and ch != '_') return ctx.returnBool(false);
    }
    return ctx.returnBool(true);
}

fn isprintableFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("isprintable requires a string");
    // Empty string is printable
    if (s.len == 0) return ctx.returnBool(true);
    for (s) |ch| {
        // Printable ASCII is 0x20-0x7E
        if (ch < 0x20 or ch > 0x7e) return ctx.returnBool(false);
    }
    return ctx.returnBool(true);
}

fn isasciiFn(ctx: *pk.Context) bool {
    const s = ctx.argStr(0) orelse return ctx.typeError("isascii requires a string");
    for (s) |ch| {
        if (ch > 0x7f) return ctx.returnBool(false);
    }
    return ctx.returnBool(true);
}

pub fn register() void {
    // Get the str type object and add methods to it
    const str_type = c.py_tpobject(c.tp_str);

    // Bind methods using signature-based binding for proper self handling
    c.py_bind(str_type, "isdigit(self)", pk.wrapFn(1, 1, isdigitFn));
    c.py_bind(str_type, "isalpha(self)", pk.wrapFn(1, 1, isalphaFn));
    c.py_bind(str_type, "isalnum(self)", pk.wrapFn(1, 1, isalnumFn));
    c.py_bind(str_type, "isspace(self)", pk.wrapFn(1, 1, isspaceFn));
    c.py_bind(str_type, "isupper(self)", pk.wrapFn(1, 1, isupperFn));
    c.py_bind(str_type, "islower(self)", pk.wrapFn(1, 1, islowerFn));
    c.py_bind(str_type, "istitle(self)", pk.wrapFn(1, 1, istitleFn));
    c.py_bind(str_type, "isdecimal(self)", pk.wrapFn(1, 1, isdecimalFn));
    c.py_bind(str_type, "isnumeric(self)", pk.wrapFn(1, 1, isnumericFn));
    c.py_bind(str_type, "isidentifier(self)", pk.wrapFn(1, 1, isidentifierFn));
    c.py_bind(str_type, "isprintable(self)", pk.wrapFn(1, 1, isprintableFn));
    c.py_bind(str_type, "isascii(self)", pk.wrapFn(1, 1, isasciiFn));
}
