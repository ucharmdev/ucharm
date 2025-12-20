const std = @import("std");
const pk = @import("pk");
const c = pk.c;

const cterm = @cImport({
    @cInclude("sys/ioctl.h");
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

var orig_termios: cterm.termios = undefined;
var raw_mode_enabled: bool = false;

fn writeOut(bytes: []const u8) void {
    _ = std.posix.write(std.posix.STDOUT_FILENO, bytes) catch {};
}

fn sizeFn(_: *pk.Context) bool {
    var ws: cterm.winsize = undefined;
    if (cterm.ioctl(std.posix.STDOUT_FILENO, cterm.TIOCGWINSZ, &ws) == -1 or ws.ws_col == 0) {
        _ = c.py_newtuple(c.py_retval(), 2);
        c.py_newint(c.py_r0(), 80);
        c.py_newint(c.py_r1(), 24);
        c.py_tuple_setitem(c.py_retval(), 0, c.py_r0());
        c.py_tuple_setitem(c.py_retval(), 1, c.py_r1());
        return true;
    }

    _ = c.py_newtuple(c.py_retval(), 2);
    c.py_newint(c.py_r0(), @intCast(ws.ws_col));
    c.py_newint(c.py_r1(), @intCast(ws.ws_row));
    c.py_tuple_setitem(c.py_retval(), 0, c.py_r0());
    c.py_tuple_setitem(c.py_retval(), 1, c.py_r1());
    return true;
}

fn rawModeFn(ctx: *pk.Context) bool {
    var arg = ctx.arg(0) orelse return ctx.typeError("expected 1 argument");
    const enable = arg.toBool() orelse return ctx.typeError("expected bool");

    if (enable and !raw_mode_enabled) {
        if (cterm.tcgetattr(std.posix.STDIN_FILENO, &orig_termios) != 0) {
            return ctx.runtimeError("failed to read terminal settings");
        }
        var raw = orig_termios;
        const lflag_mask = @as(@TypeOf(raw.c_lflag), cterm.ECHO | cterm.ICANON | cterm.ISIG | cterm.IEXTEN);
        raw.c_lflag &= ~lflag_mask;
        const iflag_mask = @as(@TypeOf(raw.c_iflag), cterm.IXON | cterm.ICRNL | cterm.BRKINT | cterm.INPCK | cterm.ISTRIP);
        raw.c_iflag &= ~iflag_mask;
        const oflag_mask = @as(@TypeOf(raw.c_oflag), cterm.OPOST);
        raw.c_oflag &= ~oflag_mask;
        raw.c_cflag |= @as(@TypeOf(raw.c_cflag), cterm.CS8);
        raw.c_cc[cterm.VMIN] = 0;
        raw.c_cc[cterm.VTIME] = 1;
        if (cterm.tcsetattr(std.posix.STDIN_FILENO, cterm.TCSAFLUSH, &raw) != 0) {
            return ctx.runtimeError("failed to enable raw mode");
        }
        raw_mode_enabled = true;
    } else if (!enable and raw_mode_enabled) {
        _ = cterm.tcsetattr(std.posix.STDIN_FILENO, cterm.TCSAFLUSH, &orig_termios);
        raw_mode_enabled = false;
    }

    return ctx.returnNone();
}

fn readKeyFn(ctx: *pk.Context) bool {
    var buf: [8]u8 = undefined;
    const n = std.posix.read(std.posix.STDIN_FILENO, buf[0..]) catch 0;
    if (n == 0) {
        return ctx.returnNone();
    }

    if (n >= 3 and buf[0] == 0x1b and buf[1] == '[') {
        switch (buf[2]) {
            'A' => return ctx.returnStrZ("up"),
            'B' => return ctx.returnStrZ("down"),
            'C' => return ctx.returnStrZ("right"),
            'D' => return ctx.returnStrZ("left"),
            'H' => return ctx.returnStrZ("home"),
            'F' => return ctx.returnStrZ("end"),
            else => {},
        }

        if (n >= 4 and buf[3] == '~') {
            switch (buf[2]) {
                '3' => return ctx.returnStrZ("delete"),
                '5' => return ctx.returnStrZ("pageup"),
                '6' => return ctx.returnStrZ("pagedown"),
                else => {},
            }
        }
    }

    if (n == 1) {
        switch (buf[0]) {
            '\r', '\n' => return ctx.returnStrZ("enter"),
            0x1b => return ctx.returnStrZ("escape"),
            0x7f, 0x08 => return ctx.returnStrZ("backspace"),
            '\t' => return ctx.returnStrZ("tab"),
            3 => return ctx.returnStrZ("ctrl-c"),
            else => {},
        }
    }

    return ctx.returnStr(buf[0..n]);
}

fn cursorPosFn(ctx: *pk.Context) bool {
    const x = ctx.argInt(0) orelse return ctx.typeError("x must be int");
    const y = ctx.argInt(1) orelse return ctx.typeError("y must be int");
    var buf: [32]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "\x1b[{d};{d}H", .{ y + 1, x + 1 }) catch {
        return ctx.runtimeError("failed to format cursor position");
    };
    writeOut(slice);
    return ctx.returnNone();
}

fn cursorUpFn(ctx: *pk.Context) bool {
    const count: i64 = if (ctx.argCount() >= 1) ctx.argInt(0) orelse 1 else 1;
    var buf: [16]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "\x1b[{d}A", .{count}) catch {
        return ctx.runtimeError("failed to format cursor move");
    };
    writeOut(slice);
    return ctx.returnNone();
}

fn cursorDownFn(ctx: *pk.Context) bool {
    const count: i64 = if (ctx.argCount() >= 1) ctx.argInt(0) orelse 1 else 1;
    var buf: [16]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "\x1b[{d}B", .{count}) catch {
        return ctx.runtimeError("failed to format cursor move");
    };
    writeOut(slice);
    return ctx.returnNone();
}

fn cursorLeftFn(ctx: *pk.Context) bool {
    const count: i64 = if (ctx.argCount() >= 1) ctx.argInt(0) orelse 1 else 1;
    var buf: [16]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "\x1b[{d}D", .{count}) catch {
        return ctx.runtimeError("failed to format cursor move");
    };
    writeOut(slice);
    return ctx.returnNone();
}

fn cursorRightFn(ctx: *pk.Context) bool {
    const count: i64 = if (ctx.argCount() >= 1) ctx.argInt(0) orelse 1 else 1;
    var buf: [16]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "\x1b[{d}C", .{count}) catch {
        return ctx.runtimeError("failed to format cursor move");
    };
    writeOut(slice);
    return ctx.returnNone();
}

fn clearFn(ctx: *pk.Context) bool {
    writeOut("\x1b[2J\x1b[H");
    return ctx.returnNone();
}

fn clearLineFn(ctx: *pk.Context) bool {
    writeOut("\x1b[2K\r");
    return ctx.returnNone();
}

fn hideCursorFn(ctx: *pk.Context) bool {
    writeOut("\x1b[?25l");
    return ctx.returnNone();
}

fn showCursorFn(ctx: *pk.Context) bool {
    writeOut("\x1b[?25h");
    return ctx.returnNone();
}

fn isTtyFn(ctx: *pk.Context) bool {
    return ctx.returnBool(cterm.isatty(std.posix.STDOUT_FILENO) == 1);
}

fn writeFnWrapped(ctx: *pk.Context) bool {
    const text = ctx.argStr(0) orelse return ctx.typeError("text must be a string");
    writeOut(text);
    return ctx.returnNone();
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("term");
    _ = builder
        .funcWrapped("size", 0, 0, sizeFn)
        .funcWrapped("raw_mode", 1, 1, rawModeFn)
        .funcWrapped("read_key", 0, 0, readKeyFn)
        .funcWrapped("cursor_pos", 2, 2, cursorPosFn)
        .funcWrapped("cursor_up", 0, 1, cursorUpFn)
        .funcWrapped("cursor_down", 0, 1, cursorDownFn)
        .funcWrapped("cursor_left", 0, 1, cursorLeftFn)
        .funcWrapped("cursor_right", 0, 1, cursorRightFn)
        .funcWrapped("clear", 0, 0, clearFn)
        .funcWrapped("clear_line", 0, 0, clearLineFn)
        .funcWrapped("hide_cursor", 0, 0, hideCursorFn)
        .funcWrapped("show_cursor", 0, 0, showCursorFn)
        .funcWrapped("is_tty", 0, 0, isTtyFn)
        .funcWrapped("write", 1, 1, writeFnWrapped);
}
