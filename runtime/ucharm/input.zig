const std = @import("std");
const pk = @import("pk");
const c = pk.c;
const input_core = @import("input_core");

const cterm = @cImport({
    @cDefine("_POSIX_C_SOURCE", "200809L");
    @cInclude("unistd.h");
    @cInclude("termios.h");
    @cInclude("fcntl.h");
    @cInclude("signal.h");
    @cInclude("stdlib.h");
});

const TEST_FD: c_int = 3;
const SYM_SELECT = "\xe2\x9d\xaf ";
const SYM_CHECKBOX_ON = "\xe2\x97\x89";
const SYM_CHECKBOX_OFF = "\xe2\x97\x8b";
const ANSI_HIDE_CURSOR = "\x1b[?25l";
const ANSI_SHOW_CURSOR = "\x1b[?25h";
const ANSI_CLEAR_LINE = "\x1b[2K\r";
const ANSI_CYAN = "\x1b[36m";
const ANSI_BOLD = "\x1b[1m";
const ANSI_RESET = "\x1b[0m";
const ANSI_DIM = "\x1b[2m";

var orig_termios: cterm.termios = undefined;
var raw_mode_enabled: bool = false;
var tty_fd: c_int = -1;

var test_keys_buf: ?[]u8 = null;
var test_keys_pos: usize = 0;
var test_mode_initialized: bool = false;

fn writeOut(bytes: []const u8) void {
    _ = std.posix.write(std.posix.STDOUT_FILENO, bytes) catch {};
}

fn writeCStr(cstr: [*:0]const u8) void {
    writeOut(std.mem.span(cstr));
}

fn writeNewline() void {
    writeOut("\n");
}

fn getTtyFd() c_int {
    if (tty_fd < 0) {
        const fd = cterm.open("/dev/tty", cterm.O_RDWR | cterm.O_NOCTTY);
        tty_fd = if (fd >= 0) fd else std.posix.STDIN_FILENO;
    }
    return tty_fd;
}

fn enableRawMode() void {
    if (raw_mode_enabled) return;

    const stdin_fd = std.posix.STDIN_FILENO;
    const tfd = getTtyFd();

    if (cterm.isatty(stdin_fd) == 1) {
        _ = cterm.tcgetattr(stdin_fd, &orig_termios);
        var raw = orig_termios;
        const lflag_mask = @as(@TypeOf(raw.c_lflag), cterm.ECHO | cterm.ICANON | cterm.ISIG | cterm.IEXTEN);
        raw.c_lflag &= ~lflag_mask;
        const iflag_mask = @as(@TypeOf(raw.c_iflag), cterm.IXON | cterm.ICRNL | cterm.BRKINT | cterm.INPCK | cterm.ISTRIP);
        raw.c_iflag &= ~iflag_mask;
        raw.c_oflag &= ~@as(@TypeOf(raw.c_oflag), cterm.OPOST);
        raw.c_cflag |= @as(@TypeOf(raw.c_cflag), cterm.CS8);
        raw.c_cc[cterm.VMIN] = 0;
        raw.c_cc[cterm.VTIME] = 1;
        _ = cterm.tcsetattr(stdin_fd, cterm.TCSANOW, &raw);
    } else {
        const our_pgrp = cterm.getpgrp();
        const fg_pgrp = cterm.tcgetpgrp(tfd);
        if (our_pgrp != fg_pgrp) {
            _ = cterm.tcsetpgrp(tfd, our_pgrp);
        }

        _ = cterm.tcgetattr(tfd, &orig_termios);
        var raw = orig_termios;
        const lflag_mask = @as(@TypeOf(raw.c_lflag), cterm.ECHO | cterm.ICANON | cterm.ISIG | cterm.IEXTEN);
        raw.c_lflag &= ~lflag_mask;
        const iflag_mask = @as(@TypeOf(raw.c_iflag), cterm.IXON | cterm.ICRNL | cterm.BRKINT | cterm.INPCK | cterm.ISTRIP);
        raw.c_iflag &= ~iflag_mask;
        raw.c_oflag &= ~@as(@TypeOf(raw.c_oflag), cterm.OPOST);
        raw.c_cflag |= @as(@TypeOf(raw.c_cflag), cterm.CS8);
        raw.c_cc[cterm.VMIN] = 0;
        raw.c_cc[cterm.VTIME] = 1;
        _ = cterm.tcsetattr(tfd, cterm.TCSANOW, &raw);
    }

    raw_mode_enabled = true;
}

fn disableRawMode() void {
    if (!raw_mode_enabled) return;
    const fd = getTtyFd();
    _ = cterm.tcsetattr(fd, cterm.TCSAFLUSH, &orig_termios);
    raw_mode_enabled = false;
}

fn hideCursor() void {
    writeOut(ANSI_HIDE_CURSOR);
}

fn showCursor() void {
    writeOut(ANSI_SHOW_CURSOR);
}

fn clearLine() void {
    writeOut(ANSI_CLEAR_LINE);
}

fn cursorUp(count: usize) void {
    var buf: [16]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "\x1b[{d}A", .{count}) catch return;
    writeOut(slice);
}

fn initTestMode() void {
    if (test_mode_initialized) return;
    test_mode_initialized = true;

    const env = cterm.getenv("MCHARM_TEST_KEYS");
    if (env != null and env[0] != 0) {
        const src = std.mem.span(env);
        const buf = std.heap.page_allocator.alloc(u8, src.len) catch return;
        @memcpy(buf, src);
        test_keys_buf = buf;
        test_keys_pos = 0;
        return;
    }

    const flags = cterm.fcntl(TEST_FD, cterm.F_GETFL);
    if (flags == -1) return;

    _ = cterm.fcntl(TEST_FD, cterm.F_SETFL, flags | cterm.O_NONBLOCK);
    var tmp: [4096]u8 = undefined;
    const n = std.posix.read(TEST_FD, tmp[0 .. tmp.len - 1]) catch 0;
    _ = cterm.fcntl(TEST_FD, cterm.F_SETFL, flags);

    if (n > 0) {
        const slice = tmp[0..n];
        var end = n;
        var i: usize = 0;
        while (i < end) : (i += 1) {
            if (slice[i] == '\n') slice[i] = ',';
        }
        if (end > 0 and slice[end - 1] == ',') {
            end -= 1;
        }
        const buf = std.heap.page_allocator.alloc(u8, end) catch return;
        @memcpy(buf, slice[0..end]);
        test_keys_buf = buf;
        test_keys_pos = 0;
    }
}

fn mapKeyName(name: []const u8) u8 {
    if (name.len == 0) return 0;
    if (std.mem.eql(u8, name, "up")) return 'u';
    if (std.mem.eql(u8, name, "down")) return 'd';
    if (std.mem.eql(u8, name, "enter")) return 'e';
    if (std.mem.eql(u8, name, "space")) return 's';
    if (std.mem.eql(u8, name, "escape")) return 'q';
    if (std.mem.eql(u8, name, "backspace")) return 'b';
    if (name.len == 1 and name[0] == 'k') return 'u';
    if (name.len == 1 and name[0] == 'j') return 'd';
    if (name.len == 1) return name[0];
    return 0;
}

/// Map key name to raw character for prompt/password input (not control codes).
fn mapRawKeyName(name: []const u8) u8 {
    if (name.len == 0) return 0;
    if (std.mem.eql(u8, name, "enter")) return '\r';
    if (std.mem.eql(u8, name, "space")) return ' ';
    if (std.mem.eql(u8, name, "escape")) return 0x1b;
    if (std.mem.eql(u8, name, "backspace")) return 0x7f;
    if (name.len == 1) return name[0];
    return 0;
}

/// Read next raw character from test input (for prompt/password).
fn readRawTestChar() u8 {
    initTestMode();
    if (test_keys_buf == null) return 0;
    const buf = test_keys_buf.?;
    var pos = test_keys_pos;
    while (pos < buf.len and (buf[pos] == ',' or buf[pos] == ' ' or buf[pos] == '\t')) {
        pos += 1;
    }
    if (pos >= buf.len) {
        test_keys_pos = pos;
        return 0;
    }
    var end = pos;
    while (end < buf.len and buf[end] != ',') {
        end += 1;
    }
    var trimmed_end = end;
    while (trimmed_end > pos and (buf[trimmed_end - 1] == ' ' or buf[trimmed_end - 1] == '\t')) {
        trimmed_end -= 1;
    }
    const key = mapRawKeyName(buf[pos..trimmed_end]);
    test_keys_pos = if (end < buf.len) end + 1 else end;
    return key;
}

/// Read a raw character, using test mode if available.
fn readRawChar() u8 {
    initTestMode();
    if (test_keys_buf != null) {
        return readRawTestChar();
    }
    var ch: [1]u8 = undefined;
    const fd = getTtyFd();
    const n = std.posix.read(fd, ch[0..]) catch 0;
    if (n <= 0) return 0;
    return ch[0];
}

fn readTestKey() u8 {
    initTestMode();
    if (test_keys_buf == null) return 0;
    const buf = test_keys_buf.?;
    var pos = test_keys_pos;
    while (pos < buf.len and (buf[pos] == ',' or buf[pos] == ' ' or buf[pos] == '\t')) {
        pos += 1;
    }
    if (pos >= buf.len) {
        test_keys_pos = pos;
        return 0;
    }
    var end = pos;
    while (end < buf.len and buf[end] != ',') {
        end += 1;
    }
    var trimmed_end = end;
    while (trimmed_end > pos and (buf[trimmed_end - 1] == ' ' or buf[trimmed_end - 1] == '\t')) {
        trimmed_end -= 1;
    }
    const key = mapKeyName(buf[pos..trimmed_end]);
    test_keys_pos = if (end < buf.len) end + 1 else end;
    return key;
}

fn readKey() u8 {
    initTestMode();
    if (test_keys_buf != null) {
        return readTestKey();
    }

    var buf: [8]u8 = undefined;
    const fd = getTtyFd();
    const n = std.posix.read(fd, buf[0 .. buf.len - 1]) catch 0;
    if (n <= 0) return 0;
    buf[n] = 0;

    if (buf[0] == 0x1b) {
        var total = n;
        if (n == 1) {
            const n2 = std.posix.read(fd, buf[1 .. buf.len - 1]) catch 0;
            if (n2 > 0) total += n2;
            if (total == 1) return 'q';
        }
        if (total >= 3 and buf[1] == '[') {
            switch (buf[2]) {
                'A' => return 'u',
                'B' => return 'd',
                else => return 0,
            }
        }
        return 0;
    }

    if (n == 1) {
        return switch (buf[0]) {
            '\r', '\n' => 'e',
            ' ' => 's',
            'j' => 'd',
            'k' => 'u',
            'q' => 'q',
            0x03 => 'q',
            'y', 'Y', 'n', 'N' => buf[0],
            0x7f, 0x08 => 'b',
            else => buf[0],
        };
    }

    return 0;
}

fn seqLen(seq: c.py_Ref) c_int {
    if (c.py_islist(seq)) return c.py_list_len(seq);
    if (c.py_istuple(seq)) return c.py_tuple_len(seq);
    return -1;
}

fn seqItem(seq: c.py_Ref, idx: c_int) c.py_Ref {
    if (c.py_islist(seq)) return c.py_list_getitem(seq, idx);
    return c.py_tuple_getitem(seq, idx);
}

fn selectFn(ctx: *pk.Context) bool {
    const prompt_s = ctx.argStr(0) orelse return ctx.typeError("prompt must be a string");
    const prompt_c: [*:0]const u8 = @ptrCast(prompt_s.ptr);

    var choices_arg = ctx.arg(1) orelse return ctx.typeError("choices required");
    const choices = choices_arg.ref();
    const choices_len = seqLen(choices);
    if (choices_len <= 0) {
        return ctx.returnNone();
    }
    var selected: i32 = @intCast(ctx.argInt(2) orelse 0);
    selected = input_core.input_clamp(selected, 0, choices_len - 1);

    writeOut(ANSI_CYAN ++ ANSI_BOLD ++ "? " ++ ANSI_RESET);
    writeCStr(prompt_c);
    writeNewline();

    hideCursor();

    var i: c_int = 0;
    while (i < choices_len) : (i += 1) {
        const choice = c.py_tostr(seqItem(choices, i));
        if (choice == null) continue;
        if (i == selected) {
            writeOut(ANSI_CYAN ++ "  " ++ SYM_SELECT);
            writeCStr(choice.?);
            writeOut(ANSI_RESET);
        } else {
            writeOut("    ");
            writeCStr(choice.?);
        }
        writeNewline();
    }

    enableRawMode();
    var result_idx: c_int = -1;

    while (true) {
        const key = readKey();
        if (key == 0) continue;

        if (key == 'd') {
            selected = input_core.input_wrap_index(selected + 1, choices_len);
        } else if (key == 'u') {
            selected = input_core.input_wrap_index(selected - 1, choices_len);
        } else if (key == 'e' or key == 's') {
            result_idx = selected;
            break;
        } else if (key == 'q') {
            break;
        } else {
            continue;
        }

        cursorUp(@intCast(choices_len));
        i = 0;
        while (i < choices_len) : (i += 1) {
            clearLine();
            const choice = c.py_tostr(seqItem(choices, i));
            if (choice == null) continue;
            if (i == selected) {
                writeOut(ANSI_CYAN ++ "  " ++ SYM_SELECT);
                writeCStr(choice.?);
                writeOut(ANSI_RESET);
            } else {
                writeOut("    ");
                writeCStr(choice.?);
            }
            writeNewline();
        }
    }

    disableRawMode();
    showCursor();

    if (result_idx >= 0 and result_idx < choices_len) {
        pk.setRetval(seqItem(choices, result_idx));
    } else {
        c.py_newnone(c.py_retval());
    }
    return true;
}

fn multiselectFn(ctx: *pk.Context) bool {
    const prompt_s = ctx.argStr(0) orelse return ctx.typeError("prompt must be a string");
    const prompt_c: [*:0]const u8 = @ptrCast(prompt_s.ptr);

    var choices_arg = ctx.arg(1) orelse return ctx.typeError("choices required");
    const choices = choices_arg.ref();
    const choices_len = seqLen(choices);
    if (choices_len <= 0) {
        c.py_newlist(c.py_retval());
        return true;
    }

    var selected_state: [256]bool = .{false} ** 256;
    var defaults_arg = ctx.arg(2);
    if (defaults_arg != null and defaults_arg.?.isList()) {
        const defaults = defaults_arg.?.ref();
        const defaults_len = c.py_list_len(defaults);
        var d: c_int = 0;
        while (d < defaults_len) : (d += 1) {
            const default_str = c.py_tostr(c.py_list_getitem(defaults, d));
            if (default_str == null) continue;
            var i: c_int = 0;
            while (i < choices_len and i < 256) : (i += 1) {
                const choice_str = c.py_tostr(seqItem(choices, i));
                if (choice_str != null and input_core.input_streq(default_str.?, choice_str.?)) {
                    selected_state[@intCast(i)] = true;
                    break;
                }
            }
        }
    }

    var cursor: c_int = 0;

    writeOut(ANSI_CYAN ++ ANSI_BOLD ++ "? " ++ ANSI_RESET);
    writeCStr(prompt_c);
    writeOut(ANSI_DIM ++ " (space to toggle, enter to confirm)" ++ ANSI_RESET);
    writeNewline();

    hideCursor();

    var i: c_int = 0;
    const checkbox_on = SYM_CHECKBOX_ON ++ " ";
    const checkbox_off = SYM_CHECKBOX_OFF ++ " ";
    while (i < choices_len and i < 256) : (i += 1) {
        const choice = c.py_tostr(seqItem(choices, i));
        if (choice == null) continue;
        if (i == cursor) {
            writeOut(ANSI_CYAN ++ "  ");
        } else {
            writeOut("  ");
        }
        writeOut(if (selected_state[@intCast(i)]) checkbox_on else checkbox_off);
        writeCStr(choice.?);
        if (i == cursor) writeOut(ANSI_RESET);
        writeNewline();
    }

    enableRawMode();
    var confirmed = false;

    while (true) {
        const key = readKey();
        if (key == 0) continue;

        if (key == 'd') {
            cursor = input_core.input_wrap_index(cursor + 1, choices_len);
        } else if (key == 'u') {
            cursor = input_core.input_wrap_index(cursor - 1, choices_len);
        } else if (key == 's') {
            if (cursor >= 0 and cursor < 256) {
                selected_state[@intCast(cursor)] = !selected_state[@intCast(cursor)];
            }
        } else if (key == 'e') {
            confirmed = true;
            break;
        } else if (key == 'q') {
            break;
        } else {
            continue;
        }

        cursorUp(@intCast(@min(choices_len, 256)));
        i = 0;
        while (i < choices_len and i < 256) : (i += 1) {
            clearLine();
            const choice = c.py_tostr(seqItem(choices, i));
            if (choice == null) continue;
            if (i == cursor) {
                writeOut(ANSI_CYAN ++ "  ");
            } else {
                writeOut("  ");
            }
            writeOut(if (selected_state[@intCast(i)]) checkbox_on else checkbox_off);
            writeCStr(choice.?);
            if (i == cursor) writeOut(ANSI_RESET);
            writeNewline();
        }
    }

    disableRawMode();
    showCursor();

    c.py_newlist(c.py_retval());
    const out = c.py_retval();
    if (confirmed) {
        i = 0;
        while (i < choices_len and i < 256) : (i += 1) {
            if (selected_state[@intCast(i)]) {
                c.py_list_append(out, seqItem(choices, i));
            }
        }
    }
    return true;
}

fn confirmFn(ctx: *pk.Context) bool {
    const prompt_s = ctx.argStr(0) orelse return ctx.typeError("prompt must be a string");
    const prompt_c: [*:0]const u8 = @ptrCast(prompt_s.ptr);
    const default_val = ctx.argBool(1) orelse true;

    writeOut(ANSI_CYAN ++ ANSI_BOLD ++ "? " ++ ANSI_RESET);
    writeCStr(prompt_c);
    writeOut(" ");
    writeOut(ANSI_DIM);
    writeOut(if (default_val) "(Y/n)" else "(y/N)");
    writeOut(ANSI_RESET ++ " ");

    enableRawMode();

    var result = default_val;
    while (true) {
        const key = readKey();
        if (key == 0) continue;
        if (key == 'y' or key == 'Y') {
            result = true;
            break;
        } else if (key == 'n' or key == 'N') {
            result = false;
            break;
        } else if (key == 'e') {
            result = default_val;
            break;
        } else if (key == 'q') {
            result = false;
            break;
        }
    }

    disableRawMode();

    writeOut(ANSI_CYAN);
    writeOut(if (result) "Yes" else "No");
    writeOut(ANSI_RESET);
    writeNewline();

    return ctx.returnBool(result);
}

fn promptFn(ctx: *pk.Context) bool {
    const message = ctx.argStr(0) orelse return ctx.typeError("message must be a string");
    const message_c: [*:0]const u8 = @ptrCast(message.ptr);

    var default_arg = ctx.arg(1);
    const default_val: ?[*:0]const u8 = if (default_arg != null and !default_arg.?.isNone()) blk: {
        const s = default_arg.?.toStr() orelse break :blk null;
        break :blk @ptrCast(s.ptr);
    } else null;

    writeOut(ANSI_CYAN ++ ANSI_BOLD ++ "? " ++ ANSI_RESET);
    writeCStr(message_c);
    if (default_val != null) {
        writeOut(ANSI_DIM ++ " (");
        writeCStr(default_val.?);
        writeOut(")" ++ ANSI_RESET);
    }
    writeOut(" ");

    var input_buf: [1024]u8 = undefined;
    var input_len: usize = 0;

    enableRawMode();

    while (input_len < input_buf.len - 1) {
        const cch = readRawChar();
        if (cch == 0) continue;
        if (cch == '\r' or cch == '\n') {
            break;
        } else if (cch == 0x1b or cch == 0x03) {
            disableRawMode();
            writeNewline();
            if (default_val != null) {
                c.py_newstr(c.py_retval(), default_val.?);
            } else {
                c.py_newstr(c.py_retval(), "");
            }
            return true;
        } else if (cch == 0x7f or cch == 0x08) {
            if (input_len > 0) {
                input_len -= 1;
                writeOut("\x08 \x08");
            }
        } else if (cch >= 32 and cch < 127) {
            input_buf[input_len] = cch;
            input_len += 1;
            writeOut(&[_]u8{cch});
        }
    }

    disableRawMode();
    writeNewline();

    if (input_len == 0 and default_val != null) {
        c.py_newstr(c.py_retval(), default_val.?);
        return true;
    }

    return ctx.returnStr(input_buf[0..input_len]);
}

fn passwordFn(ctx: *pk.Context) bool {
    const message = ctx.argStr(0) orelse return ctx.typeError("message must be a string");
    const message_c: [*:0]const u8 = @ptrCast(message.ptr);

    writeOut(ANSI_CYAN ++ ANSI_BOLD ++ "? " ++ ANSI_RESET);
    writeCStr(message_c);
    writeOut(" ");

    var input_buf: [1024]u8 = undefined;
    var input_len: usize = 0;

    enableRawMode();

    while (input_len < input_buf.len - 1) {
        const cch = readRawChar();
        if (cch == 0) continue;
        if (cch == '\r' or cch == '\n') {
            break;
        } else if (cch == 0x1b or cch == 0x03) {
            disableRawMode();
            writeNewline();
            c.py_newstr(c.py_retval(), "");
            return true;
        } else if (cch == 0x7f or cch == 0x08) {
            if (input_len > 0) {
                input_len -= 1;
            }
        } else if (cch >= 32 and cch < 127) {
            input_buf[input_len] = cch;
            input_len += 1;
        }
    }

    disableRawMode();
    writeNewline();

    return ctx.returnStr(input_buf[0..input_len]);
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("input");
    _ = builder
        // Use signature-based binding for kwargs support
        .funcSigWrapped("select(prompt, choices, default=0)", 2, 3, selectFn)
        .funcSigWrapped("multiselect(prompt, choices, defaults=None)", 2, 3, multiselectFn)
        .funcSigWrapped("confirm(prompt, default=True)", 1, 2, confirmFn)
        .funcSigWrapped("prompt(message, default=None)", 1, 2, promptFn)
        .funcWrapped("password", 1, 1, passwordFn);
}
