const pk = @import("pk");
const c = pk.c;
const ansi_core = @import("ansi_core");

fn newStrFromBuf(buf: []const u8) void {
    const out = c.py_newstrn(c.py_retval(), @intCast(buf.len));
    if (buf.len > 0) {
        const dst = @as([*]u8, @ptrCast(out))[0..buf.len];
        @memcpy(dst, buf);
    }
}

fn resetFn(ctx: *pk.Context) bool {
    return ctx.returnStrZ("\x1b[0m");
}

fn fgFn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("expected 1 argument");
    var buf: [32]u8 = undefined;

    if (arg.isInt()) {
        const idx = arg.toInt().?;
        if (idx >= 0 and idx < 16) {
            const len = ansi_core.ansi_fg_standard(@intCast(idx), &buf);
            newStrFromBuf(buf[0..len]);
            return true;
        }
        if (idx >= 0 and idx <= 255) {
            const len = ansi_core.ansi_fg_256(@intCast(idx), &buf);
            newStrFromBuf(buf[0..len]);
            return true;
        }
        return ctx.returnStrZ("");
    }

    const str = arg.toStr() orelse return ctx.typeError("color must be a string or int");
    // Need null-terminated string for ansi_core functions
    var str_buf: [64]u8 = undefined;
    if (str.len >= str_buf.len) return ctx.returnStrZ("");
    @memcpy(str_buf[0..str.len], str);
    str_buf[str.len] = 0;
    const str_z: [*:0]const u8 = @ptrCast(&str_buf);

    if (ansi_core.ansi_is_hex_color(str_z)) {
        const color = ansi_core.ansi_parse_hex_color(str_z);
        if (color.valid) {
            const len = ansi_core.ansi_fg_rgb(color.r, color.g, color.b, &buf);
            newStrFromBuf(buf[0..len]);
            return true;
        }
    } else {
        const ci = ansi_core.ansi_color_name_to_index(str_z);
        if (ci.index >= 0) {
            const len = ansi_core.ansi_fg_standard(@intCast(ci.index), &buf);
            newStrFromBuf(buf[0..len]);
            return true;
        }
    }

    return ctx.returnStrZ("");
}

fn bgFn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("expected 1 argument");
    var buf: [32]u8 = undefined;

    if (arg.isInt()) {
        const idx = arg.toInt().?;
        if (idx >= 0 and idx < 16) {
            const len = ansi_core.ansi_bg_standard(@intCast(idx), &buf);
            newStrFromBuf(buf[0..len]);
            return true;
        }
        if (idx >= 0 and idx <= 255) {
            const len = ansi_core.ansi_bg_256(@intCast(idx), &buf);
            newStrFromBuf(buf[0..len]);
            return true;
        }
        return ctx.returnStrZ("");
    }

    const str = arg.toStr() orelse return ctx.typeError("color must be a string or int");
    var str_buf: [64]u8 = undefined;
    if (str.len >= str_buf.len) return ctx.returnStrZ("");
    @memcpy(str_buf[0..str.len], str);
    str_buf[str.len] = 0;
    const str_z: [*:0]const u8 = @ptrCast(&str_buf);

    if (ansi_core.ansi_is_hex_color(str_z)) {
        const color = ansi_core.ansi_parse_hex_color(str_z);
        if (color.valid) {
            const len = ansi_core.ansi_bg_rgb(color.r, color.g, color.b, &buf);
            newStrFromBuf(buf[0..len]);
            return true;
        }
    } else {
        const ci = ansi_core.ansi_color_name_to_index(str_z);
        if (ci.index >= 0) {
            const len = ansi_core.ansi_bg_standard(@intCast(ci.index), &buf);
            newStrFromBuf(buf[0..len]);
            return true;
        }
    }

    return ctx.returnStrZ("");
}

fn rgbFn(ctx: *pk.Context) bool {
    const r = @as(u8, @intCast(ctx.argInt(0) orelse return ctx.typeError("r must be int")));
    const g = @as(u8, @intCast(ctx.argInt(1) orelse return ctx.typeError("g must be int")));
    const b = @as(u8, @intCast(ctx.argInt(2) orelse return ctx.typeError("b must be int")));

    var is_bg: bool = false;
    if (ctx.argCount() >= 4) {
        if (ctx.arg(3)) |bg_arg| {
            var bg_val = bg_arg;
            is_bg = bg_val.toBool() orelse false;
        }
    }

    var buf: [32]u8 = undefined;
    const len = if (is_bg)
        ansi_core.ansi_bg_rgb(r, g, b, &buf)
    else
        ansi_core.ansi_fg_rgb(r, g, b, &buf);

    newStrFromBuf(buf[0..len]);
    return true;
}

fn boldFn(ctx: *pk.Context) bool {
    return ctx.returnStrZ("\x1b[1m");
}

fn dimFn(ctx: *pk.Context) bool {
    return ctx.returnStrZ("\x1b[2m");
}

fn italicFn(ctx: *pk.Context) bool {
    return ctx.returnStrZ("\x1b[3m");
}

fn underlineFn(ctx: *pk.Context) bool {
    return ctx.returnStrZ("\x1b[4m");
}

fn blinkFn(ctx: *pk.Context) bool {
    return ctx.returnStrZ("\x1b[5m");
}

fn reverseFn(ctx: *pk.Context) bool {
    return ctx.returnStrZ("\x1b[7m");
}

fn hiddenFn(ctx: *pk.Context) bool {
    return ctx.returnStrZ("\x1b[8m");
}

fn strikethroughFn(ctx: *pk.Context) bool {
    return ctx.returnStrZ("\x1b[9m");
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("ansi");
    _ = builder
        .funcWrapped("reset", 0, 0, resetFn)
        .funcWrapped("fg", 1, 1, fgFn)
        .funcWrapped("bg", 1, 1, bgFn)
        .funcWrapped("rgb", 3, 4, rgbFn)
        .funcWrapped("bold", 0, 0, boldFn)
        .funcWrapped("dim", 0, 0, dimFn)
        .funcWrapped("italic", 0, 0, italicFn)
        .funcWrapped("underline", 0, 0, underlineFn)
        .funcWrapped("blink", 0, 0, blinkFn)
        .funcWrapped("reverse", 0, 0, reverseFn)
        .funcWrapped("hidden", 0, 0, hiddenFn)
        .funcWrapped("strikethrough", 0, 0, strikethroughFn);
}
