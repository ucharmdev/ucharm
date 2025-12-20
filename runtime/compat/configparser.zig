const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_config_parser: c.py_Type = 0;

fn getSectionsDict(self: c.py_Ref) c.py_Ref {
    return c.py_getslot(self, 0);
}

fn getSectionsOrder(self: c.py_Ref) c.py_Ref {
    return c.py_getslot(self, 1);
}

fn configParserNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_config_parser, 2, 0);
    c.py_newdict(c.py_r0());
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    c.py_newlist(c.py_r0());
    c.py_setslot(c.py_retval(), 1, c.py_r0());
    return true;
}

fn configParserInit(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    c.py_newnone(c.py_retval());
    return true;
}

fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

fn pyNewStr(out: c.py_OutRef, s: []const u8) void {
    const dst = c.py_newstrn(out, @intCast(s.len));
    @memcpy(dst[0..s.len], s);
}

fn readStringFn(ctx: *pk.Context) bool {
    const self = pk.argRef(ctx.argv, 0);
    const text = ctx.argStr(1) orelse return ctx.typeError("expected string");

    // Reset state for deterministic behavior.
    c.py_newdict(c.py_r0());
    c.py_setslot(self, 0, c.py_r0());
    c.py_newlist(c.py_r0());
    c.py_setslot(self, 1, c.py_r0());

    const sections = getSectionsDict(self);
    const order = getSectionsOrder(self);

    var current_section: ?c.py_TValue = null;

    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw_line| {
        const line = trim(raw_line);
        if (line.len == 0) continue;
        if (line[0] == ';' or line[0] == '#') continue;

        if (line[0] == '[' and line[line.len - 1] == ']') {
            const name = trim(line[1 .. line.len - 1]);
            if (name.len == 0) continue;

            var key_tv: c.py_TValue = undefined;
            pyNewStr(&key_tv, name);

            if (c.py_dict_getitem(sections, &key_tv) <= 0) {
                var sec_tv: c.py_TValue = undefined;
                c.py_newdict(&sec_tv);
                _ = c.py_dict_setitem(sections, &key_tv, &sec_tv);
                c.py_list_append(order, &key_tv);
            }

            current_section = key_tv;
            continue;
        }

        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = trim(line[0..eq]);
        const value = trim(line[eq + 1 ..]);
        if (key.len == 0) continue;

        if (current_section == null) return ctx.runtimeError("no section header");

        const sec_key = &current_section.?;
        if (c.py_dict_getitem(sections, sec_key) <= 0) return ctx.runtimeError("section missing");
        const sec_dict = c.py_retval();

        var opt_tv: c.py_TValue = undefined;
        pyNewStr(&opt_tv, key);
        var val_tv: c.py_TValue = undefined;
        pyNewStr(&val_tv, value);
        _ = c.py_dict_setitem(sec_dict, &opt_tv, &val_tv);
    }

    c.py_newnone(c.py_retval());
    return true;
}

fn sectionsFn(ctx: *pk.Context) bool {
    const self = pk.argRef(ctx.argv, 0);
    const order = getSectionsOrder(self);
    c.py_newlist(c.py_retval());

    const n = c.py_list_len(order);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const item = c.py_list_getitem(order, i);
        c.py_list_append(c.py_retval(), item);
    }
    return true;
}

fn hasSectionFn(ctx: *pk.Context) bool {
    const self = pk.argRef(ctx.argv, 0);
    const section = pk.argRef(ctx.argv, 1);
    const sections = getSectionsDict(self);
    c.py_newbool(c.py_retval(), c.py_dict_getitem(sections, section) > 0);
    return true;
}

fn hasOptionFn(ctx: *pk.Context) bool {
    const self = pk.argRef(ctx.argv, 0);
    const section = pk.argRef(ctx.argv, 1);
    const option = pk.argRef(ctx.argv, 2);
    const sections = getSectionsDict(self);
    if (c.py_dict_getitem(sections, section) <= 0) {
        c.py_newbool(c.py_retval(), false);
        return true;
    }
    const sec_dict = c.py_retval();
    c.py_newbool(c.py_retval(), c.py_dict_getitem(sec_dict, option) > 0);
    return true;
}

fn getFn(ctx: *pk.Context) bool {
    const self = pk.argRef(ctx.argv, 0);
    const section = pk.argRef(ctx.argv, 1);
    const option = pk.argRef(ctx.argv, 2);
    const sections = getSectionsDict(self);
    if (c.py_dict_getitem(sections, section) <= 0) return c.py_exception(c.tp_KeyError, "no such section");
    const sec_dict = c.py_retval();
    if (c.py_dict_getitem(sec_dict, option) <= 0) return c.py_exception(c.tp_KeyError, "no such option");
    return true;
}

fn getIntFn(ctx: *pk.Context) bool {
    if (!getFn(ctx)) return false;
    const s = c.py_tostr(c.py_retval());
    const v = std.fmt.parseInt(i64, s[0..std.mem.len(s)], 10) catch return ctx.valueError("invalid int");
    c.py_newint(c.py_retval(), v);
    return true;
}

fn getFloatFn(ctx: *pk.Context) bool {
    if (!getFn(ctx)) return false;
    const s = c.py_tostr(c.py_retval());
    const v = std.fmt.parseFloat(f64, s[0..std.mem.len(s)]) catch return ctx.valueError("invalid float");
    c.py_newfloat(c.py_retval(), v);
    return true;
}

fn getBoolFn(ctx: *pk.Context) bool {
    if (!getFn(ctx)) return false;
    const s0 = c.py_tostr(c.py_retval());
    const s = std.ascii.allocLowerString(std.heap.page_allocator, s0[0..std.mem.len(s0)]) catch return ctx.runtimeError("oom");
    defer std.heap.page_allocator.free(s);

    const is_true = std.mem.eql(u8, s, "1") or std.mem.eql(u8, s, "yes") or std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "on");
    const is_false = std.mem.eql(u8, s, "0") or std.mem.eql(u8, s, "no") or std.mem.eql(u8, s, "false") or std.mem.eql(u8, s, "off");
    if (!is_true and !is_false) return ctx.valueError("invalid boolean");
    c.py_newbool(c.py_retval(), is_true);
    return true;
}

pub fn register() void {
    const builder = pk.ModuleBuilder.new("configparser");

    var t = pk.TypeBuilder.newSimple("ConfigParser", builder.module);
    tp_config_parser = t
        .magic("__new__", configParserNew)
        .magic("__init__", configParserInit)
        .methodWrapped("read_string", 2, 2, readStringFn)
        .methodWrapped("sections", 1, 1, sectionsFn)
        .methodWrapped("get", 3, 3, getFn)
        .methodWrapped("getint", 3, 3, getIntFn)
        .methodWrapped("getfloat", 3, 3, getFloatFn)
        .methodWrapped("getboolean", 3, 3, getBoolFn)
        .methodWrapped("has_section", 2, 2, hasSectionFn)
        .methodWrapped("has_option", 3, 3, hasOptionFn)
        .build();

    _ = tp_config_parser;
}
