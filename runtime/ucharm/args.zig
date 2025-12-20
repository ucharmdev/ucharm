const std = @import("std");
const pk = @import("pk");
const c = pk.c;
const args_core = @import("args_core");

fn getSysArgv() !c.py_Ref {
    const sys_mod = c.py_getmodule("sys") orelse {
        return error.MissingSys;
    };
    const argv = c.py_getdict(sys_mod, c.py_name("argv"));
    if (argv == null) return error.MissingArgv;
    return argv.?;
}

fn rawFn(_: *pk.Context) bool {
    const sys_argv = getSysArgv() catch {
        return c.py_exception(c.tp_RuntimeError, "sys.argv not available");
    };
    pk.setRetval(sys_argv);
    return true;
}

fn getFn(ctx: *pk.Context) bool {
    const sys_argv = getSysArgv() catch {
        return ctx.runtimeError("sys.argv not available");
    };
    const len = c.py_list_len(sys_argv);
    var idx = ctx.argInt(0) orelse return ctx.typeError("index must be int");
    if (idx < 0) idx = @as(i64, len) + idx;
    if (idx >= 0 and idx < len) {
        pk.setRetval(c.py_list_getitem(sys_argv, @intCast(idx)));
        return true;
    }
    // Return default if provided, else None
    if (ctx.argCount() == 2) {
        var arg1 = ctx.arg(1) orelse return ctx.returnNone();
        pk.setRetval(arg1.ref());
    } else {
        c.py_newnone(c.py_retval());
    }
    return true;
}

fn countFn(_: *pk.Context) bool {
    const sys_argv = getSysArgv() catch {
        return c.py_exception(c.tp_RuntimeError, "sys.argv not available");
    };
    c.py_newint(c.py_retval(), c.py_list_len(sys_argv));
    return true;
}

fn hasFn(ctx: *pk.Context) bool {
    const flag = ctx.argStr(0) orelse return ctx.typeError("flag must be a string");
    const flag_c: [*:0]const u8 = @ptrCast(flag.ptr);
    const sys_argv = getSysArgv() catch {
        return ctx.runtimeError("sys.argv not available");
    };
    const len = c.py_list_len(sys_argv);
    var i: c_int = 0;
    while (i < len) : (i += 1) {
        const arg = c.py_list_getitem(sys_argv, i);
        const arg_c = c.py_tostr(arg);
        if (arg_c != null and args_core.args_streq(arg_c, flag_c)) {
            return ctx.returnBool(true);
        }
    }
    return ctx.returnBool(false);
}

fn findValue(sys_argv: c.py_Ref, flag_c: [*:0]const u8) ?c.py_Ref {
    const len = c.py_list_len(sys_argv);
    const flag_len = args_core.args_strlen(flag_c);
    var i: c_int = 0;
    while (i < len) : (i += 1) {
        const arg = c.py_list_getitem(sys_argv, i);
        const arg_c = c.py_tostr(arg);
        if (arg_c == null) continue;

        if (args_core.args_streq(arg_c, flag_c) and i + 1 < len) {
            return c.py_list_getitem(sys_argv, i + 1);
        }

        const arg_slice = std.mem.span(arg_c);
        if (arg_slice.len > flag_len and std.mem.startsWith(u8, arg_slice, std.mem.span(flag_c)) and arg_slice[flag_len] == '=') {
            const value_ptr: [*:0]const u8 = @ptrCast(arg_c + flag_len + 1);
            c.py_newstr(c.py_r0(), value_ptr);
            return c.py_r0();
        }
    }
    return null;
}

fn valueFn(ctx: *pk.Context) bool {
    const flag = ctx.argStr(0) orelse return ctx.typeError("flag must be a string");
    const flag_c: [*:0]const u8 = @ptrCast(flag.ptr);
    const sys_argv = getSysArgv() catch {
        return ctx.runtimeError("sys.argv not available");
    };
    if (findValue(sys_argv, flag_c)) |val| {
        pk.setRetval(val);
        return true;
    }
    if (ctx.argCount() == 2) {
        var arg1 = ctx.arg(1) orelse return ctx.returnNone();
        pk.setRetval(arg1.ref());
    } else {
        c.py_newnone(c.py_retval());
    }
    return true;
}

fn intValueFn(ctx: *pk.Context) bool {
    const flag = ctx.argStr(0) orelse return ctx.typeError("flag must be a string");
    const flag_c: [*:0]const u8 = @ptrCast(flag.ptr);
    const sys_argv = getSysArgv() catch {
        return ctx.runtimeError("sys.argv not available");
    };
    if (findValue(sys_argv, flag_c)) |val| {
        const str_c = c.py_tostr(val);
        if (str_c != null and args_core.args_is_valid_int(str_c)) {
            return ctx.returnInt(args_core.args_parse_int(str_c));
        }
    }
    if (ctx.argCount() == 2) {
        var arg1 = ctx.arg(1) orelse return ctx.returnInt(0);
        pk.setRetval(arg1.ref());
    } else {
        c.py_newint(c.py_retval(), 0);
    }
    return true;
}

fn positionalFn(_: *pk.Context) bool {
    const sys_argv = getSysArgv() catch {
        return c.py_exception(c.tp_RuntimeError, "sys.argv not available");
    };
    const len = c.py_list_len(sys_argv);
    c.py_newlist(c.py_retval());
    const out = c.py_retval();
    var after_dashdash = false;
    var skip_next = false;

    var i: c_int = 1;
    while (i < len) : (i += 1) {
        if (skip_next) {
            skip_next = false;
            continue;
        }
        const item = c.py_list_getitem(sys_argv, i);
        const arg_c = c.py_tostr(item);
        if (arg_c == null) continue;

        if (after_dashdash) {
            c.py_list_append(out, item);
            continue;
        }
        if (args_core.args_is_dashdash(arg_c)) {
            after_dashdash = true;
            continue;
        }

        if (args_core.args_is_long_flag(arg_c)) {
            if (std.mem.indexOfScalar(u8, std.mem.span(arg_c), '=') == null) {
                if (i + 1 < len) {
                    const next = c.py_list_getitem(sys_argv, i + 1);
                    const next_c = c.py_tostr(next);
                    if (next_c != null and !args_core.args_is_long_flag(next_c) and !args_core.args_is_short_flag(next_c)) {
                        skip_next = true;
                    }
                }
            }
            continue;
        }

        if (args_core.args_is_short_flag(arg_c) and !args_core.args_is_negative_number(arg_c)) {
            if (i + 1 < len) {
                const next = c.py_list_getitem(sys_argv, i + 1);
                const next_c = c.py_tostr(next);
                if (next_c != null and !args_core.args_is_long_flag(next_c) and !args_core.args_is_short_flag(next_c)) {
                    skip_next = true;
                }
            }
            continue;
        }

        c.py_list_append(out, item);
    }
    return true;
}

const AliasCtx = struct { aliases: c.py_Ref };

fn aliasCollector(key: c.py_Ref, val: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
    if (!c.py_isstr(val)) return true;
    const alias_ctx: *AliasCtx = @ptrCast(@alignCast(ctx.?));
    _ = c.py_dict_setitem(alias_ctx.aliases, key, val);
    return true;
}

const DefaultsCtx = struct { result: c.py_Ref };

fn isTypeObj(val: c.py_Ref, typ: c.py_Type) bool {
    return c.py_isidentical(val, c.py_tpobject(typ));
}

fn defaultsCollector(key: c.py_Ref, val: c.py_Ref, ctx: ?*anyopaque) callconv(.c) bool {
    if (c.py_isstr(val)) return true;
    const key_c = c.py_tostr(key);
    if (key_c == null) return true;
    if (!args_core.args_is_long_flag(key_c) and !args_core.args_is_short_flag(key_c)) return true;

    const clean = args_core.args_get_flag_name(key_c);
    c.py_newstr(c.py_r0(), clean);
    const name_key = c.py_r0();

    const ctx_ptr: *DefaultsCtx = @ptrCast(@alignCast(ctx.?));
    const existing = c.py_dict_getitem(ctx_ptr.result, name_key);
    if (existing > 0) return true;

    if (c.py_istuple(val)) {
        const tlen = c.py_tuple_len(val);
        if (tlen >= 2) {
            const def_val = c.py_tuple_getitem(val, 1);
            _ = c.py_dict_setitem(ctx_ptr.result, name_key, def_val);
            return true;
        }
        if (tlen == 1) {
            const first = c.py_tuple_getitem(val, 0);
            if (isTypeObj(first, c.tp_bool)) {
                c.py_newbool(c.py_r1(), false);
                _ = c.py_dict_setitem(ctx_ptr.result, name_key, c.py_r1());
            }
        }
        return true;
    }

    if (isTypeObj(val, c.tp_bool)) {
        c.py_newbool(c.py_r1(), false);
        _ = c.py_dict_setitem(ctx_ptr.result, name_key, c.py_r1());
    }
    return true;
}

fn parseFn(ctx: *pk.Context) bool {
    const sys_argv = getSysArgv() catch {
        return ctx.runtimeError("sys.argv not available");
    };
    var spec = ctx.arg(0) orelse return ctx.typeError("expected 1 argument");
    if (!spec.isDict()) {
        return ctx.typeError("spec must be a dict");
    }

    const result = c.py_pushtmp();
    c.py_newdict(result);
    const positional_out = c.py_pushtmp();
    c.py_newlist(positional_out);
    _ = c.py_dict_setitem_by_str(result, "_", positional_out);

    c.py_newdict(c.py_r2());
    const aliases = c.py_r2();
    var alias_ctx = AliasCtx{ .aliases = aliases };
    _ = c.py_dict_apply(spec.ref(), aliasCollector, &alias_ctx);

    const argc_list = c.py_list_len(sys_argv);
    var after_dashdash = false;

    var i: c_int = 1;
    while (i < argc_list) : (i += 1) {
        const arg_val = c.py_list_getitem(sys_argv, i);
        const arg_c = c.py_tostr(arg_val);
        if (arg_c == null) continue;

        if (after_dashdash) {
            c.py_list_append(positional_out, arg_val);
            continue;
        }

        if (args_core.args_is_dashdash(arg_c)) {
            after_dashdash = true;
            continue;
        }

        if (args_core.args_is_long_flag(arg_c) or (args_core.args_is_short_flag(arg_c) and !args_core.args_is_negative_number(arg_c))) {
            var flag_key = arg_val;
            var value_str: ?[*:0]const u8 = null;

            const arg_slice = std.mem.span(arg_c);
            if (std.mem.indexOfScalar(u8, arg_slice, '=')) |eq_pos| {
                if (eq_pos < 127) {
                    var buf: [128]u8 = undefined;
                    @memcpy(buf[0..eq_pos], arg_slice[0..eq_pos]);
                    buf[eq_pos] = 0;
                    c.py_newstr(c.py_r3(), @ptrCast(&buf));
                    flag_key = c.py_r3();
                    value_str = @ptrCast(arg_c + eq_pos + 1);
                }
            }

            const alias_res = c.py_dict_getitem(aliases, flag_key);
            if (alias_res > 0) {
                flag_key = c.py_retval();
            }

            var spec_res = c.py_dict_getitem(spec.ref(), flag_key);
            if (spec_res <= 0) {
                const flag_name = args_core.args_get_flag_name(c.py_tostr(flag_key).?);
                if (args_core.args_is_negated_flag(flag_name)) {
                    const base = args_core.args_get_negated_base(flag_name);
                    var full_flag: [128]u8 = undefined;
                    const slice = std.fmt.bufPrint(&full_flag, "--{s}", .{std.mem.span(base)}) catch {
                        continue;
                    };
                    if (slice.len > 0 and slice.len < full_flag.len) {
                        full_flag[slice.len] = 0;
                        c.py_newstr(c.py_r0(), @ptrCast(&full_flag));
                        spec_res = c.py_dict_getitem(spec.ref(), c.py_r0());
                        if (spec_res > 0) {
                            c.py_newbool(c.py_r1(), false);
                            _ = c.py_dict_setitem_by_str(result, base, c.py_r1());
                            continue;
                        }
                    }
                }
                continue;
            }

            var type_obj = c.py_retval();
            const clean_name = args_core.args_get_flag_name(c.py_tostr(flag_key).?);
            c.py_newstr(c.py_r0(), clean_name);
            const name_key = c.py_r0();

            if (c.py_istuple(type_obj)) {
                if (c.py_tuple_len(type_obj) >= 1) {
                    type_obj = c.py_tuple_getitem(type_obj, 0);
                }
            }

            if (isTypeObj(type_obj, c.tp_bool)) {
                c.py_newbool(c.py_r1(), true);
                _ = c.py_dict_setitem(result, name_key, c.py_r1());
            } else {
                var value_ref: c.py_Ref = undefined;
                if (value_str) |vs| {
                    c.py_newstr(c.py_r1(), vs);
                    value_ref = c.py_r1();
                } else if (i + 1 < argc_list) {
                    i += 1;
                    value_ref = c.py_list_getitem(sys_argv, i);
                } else {
                    continue;
                }

                if (isTypeObj(type_obj, c.tp_int)) {
                    const vs = c.py_tostr(value_ref);
                    if (vs != null and args_core.args_is_valid_int(vs)) {
                        c.py_newint(c.py_r2(), args_core.args_parse_int(vs));
                        _ = c.py_dict_setitem(result, name_key, c.py_r2());
                    }
                } else {
                    _ = c.py_dict_setitem(result, name_key, value_ref);
                }
            }
        } else {
            c.py_list_append(positional_out, arg_val);
        }
    }

    var defaults_ctx = DefaultsCtx{ .result = result };
    _ = c.py_dict_apply(spec.ref(), defaultsCollector, &defaults_ctx);

    pk.setRetval(result);
    c.py_pop();
    c.py_pop();
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("args");
    _ = builder
        .funcWrapped("raw", 0, 0, rawFn)
        .funcWrapped("get", 1, 2, getFn)
        .funcWrapped("count", 0, 0, countFn)
        .funcWrapped("has", 1, 1, hasFn)
        .funcWrapped("value", 1, 2, valueFn)
        .funcWrapped("int_value", 1, 2, intValueFn)
        .funcWrapped("positional", 0, 0, positionalFn)
        .funcWrapped("parse", 1, 1, parseFn);
}
