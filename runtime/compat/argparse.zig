const std = @import("std");
const pk = @import("pk");
const c = pk.c;

const argparse_opts_key: [:0]const u8 = "__opts__";
const argparse_pos_key: [:0]const u8 = "__pos__";
const argparse_opt_names_key: [:0]const u8 = "__opt_names__";
const argparse_opt_map_key: [:0]const u8 = "__opt_map__";
const argparse_groups_key: [:0]const u8 = "__groups__";
const argparse_subparsers_key: [:0]const u8 = "__subparsers__";
const argparse_subparsers_dest_key: [:0]const u8 = "__subparsers_dest__";
const argparse_prog_key: [:0]const u8 = "prog";
const argparse_description_key: [:0]const u8 = "description";
const argparse_name_key: [:0]const u8 = "name";
const argparse_type_key: [:0]const u8 = "type";
const argparse_default_key: [:0]const u8 = "default";
const argparse_action_key: [:0]const u8 = "action";
const argparse_dest_key: [:0]const u8 = "dest";
const argparse_nargs_key: [:0]const u8 = "nargs";
const argparse_const_key: [:0]const u8 = "const";
const argparse_choices_key: [:0]const u8 = "choices";
const argparse_required_key: [:0]const u8 = "required";
const argparse_group_key: [:0]const u8 = "__group__";

var tp_argument_parser: c.py_Type = 0;
var tp_namespace: c.py_Type = 0;
var tp_mutex_group: c.py_Type = 0;
var tp_subparsers: c.py_Type = 0;

fn ensureStores(self: c.py_Ref) void {
    const opts = c.py_getdict(self, c.py_name(argparse_opts_key));
    if (opts == null) {
        c.py_newdict(c.py_r0());
        c.py_setdict(self, c.py_name(argparse_opts_key), c.py_r0());
    }
    const opt_map = c.py_getdict(self, c.py_name(argparse_opt_map_key));
    if (opt_map == null) {
        c.py_newdict(c.py_r0());
        c.py_setdict(self, c.py_name(argparse_opt_map_key), c.py_r0());
    }
    const pos = c.py_getdict(self, c.py_name(argparse_pos_key));
    if (pos == null) {
        c.py_newlist(c.py_r1());
        c.py_setdict(self, c.py_name(argparse_pos_key), c.py_r1());
    }
    const opt_names = c.py_getdict(self, c.py_name(argparse_opt_names_key));
    if (opt_names == null) {
        c.py_newlist(c.py_r2());
        c.py_setdict(self, c.py_name(argparse_opt_names_key), c.py_r2());
    }
    const groups = c.py_getdict(self, c.py_name(argparse_groups_key));
    if (groups == null) {
        c.py_newlist(c.py_r3());
        c.py_setdict(self, c.py_name(argparse_groups_key), c.py_r3());
    }
    const subparsers = c.py_getdict(self, c.py_name(argparse_subparsers_key));
    if (subparsers == null) {
        c.py_newdict(c.py_r4());
        c.py_setdict(self, c.py_name(argparse_subparsers_key), c.py_r4());
    }
}

fn init(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1 or argc > 3) {
        return c.py_exception(c.tp_TypeError, "expected 0 to 2 arguments");
    }
    const self = pk.argRef(argv, 0);
    ensureStores(self);

    if (argc == 2) {
        const prog = pk.argRef(argv, 1);
        if (!c.py_isnone(prog)) {
            c.py_setdict(self, c.py_name(argparse_prog_key), prog);
        }
    }
    if (argc == 3) {
        const desc = pk.argRef(argv, 2);
        if (!c.py_isnone(desc)) {
            c.py_setdict(self, c.py_name(argparse_description_key), desc);
        }
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn new(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1 or argc > 3) {
        return c.py_exception(c.tp_TypeError, "expected 1 to 3 arguments");
    }
    _ = pk.argRef(argv, 0);
    _ = c.py_newobject(c.py_retval(), tp_argument_parser, -1, 0);
    return true;
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

fn setAttr(obj: c.py_Ref, name_c: [*:0]const u8, val: c.py_Ref) void {
    c.py_setdict(obj, c.py_name(name_c), val);
}

fn deriveDestFromOption(alloc: std.mem.Allocator, names: []const []const u8) ![:0]const u8 {
    var best: []const u8 = "";
    for (names) |n| {
        if (std.mem.startsWith(u8, n, "--")) {
            best = n[2..];
            break;
        }
    }
    if (best.len == 0) {
        // Use first short option.
        const n = names[0];
        if (std.mem.startsWith(u8, n, "-") and n.len >= 2) {
            best = n[1..];
        } else {
            best = n;
        }
    }
    const out = try alloc.dupe(u8, best);
    for (out) |*ch| {
        if (ch.* == '-') ch.* = '_';
    }
    return try alloc.dupeZ(u8, out);
}

fn buildNamesList(alloc: std.mem.Allocator, names_val: c.py_Ref) !std.ArrayList([]const u8) {
    var out: std.ArrayList([]const u8) = .empty;
    if (c.py_istuple(names_val)) {
        const n = c.py_tuple_len(names_val);
        var i: c_int = 0;
        while (i < n) : (i += 1) {
            const item = c.py_tuple_getitem(names_val, i);
            if (!c.py_checkstr(item)) return error.Invalid;
            const s = c.py_tostr(item) orelse return error.Invalid;
            try out.append(alloc, std.mem.span(s));
        }
        return out;
    }
    if (c.py_islist(names_val)) {
        const n = c.py_list_len(names_val);
        var i: c_int = 0;
        while (i < n) : (i += 1) {
            const item = c.py_list_getitem(names_val, i);
            if (!c.py_checkstr(item)) return error.Invalid;
            const s = c.py_tostr(item) orelse return error.Invalid;
            try out.append(alloc, std.mem.span(s));
        }
        return out;
    }
    if (!c.py_checkstr(names_val)) return error.Invalid;
    const s = c.py_tostr(names_val) orelse return error.Invalid;
    try out.append(alloc, std.mem.span(s));
    return out;
}

fn addArgumentImpl(parser: c.py_Ref, group_dests: ?c.py_Ref, argc: c_int, argv: c.py_StackRef) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "add_argument() requires at least one name");
    ensureStores(parser);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var names = buildNamesList(alloc, pk.argRef(argv, 1)) catch return c.py_exception(c.tp_TypeError, "invalid argument names");
    defer names.deinit(alloc);
    if (names.items.len == 0) return c.py_exception(c.tp_TypeError, "add_argument() requires at least one name");

    const opts = c.py_getdict(parser, c.py_name(argparse_opts_key)).?;
    const opt_map = c.py_getdict(parser, c.py_name(argparse_opt_map_key)).?;
    const pos = c.py_getdict(parser, c.py_name(argparse_pos_key)).?;
    const opt_names = c.py_getdict(parser, c.py_name(argparse_opt_names_key)).?;

    const type_val = if (argc > 2) pk.argRef(argv, 2) else c.py_None();
    const default_val = if (argc > 3) pk.argRef(argv, 3) else c.py_None();
    const action_val = if (argc > 4) pk.argRef(argv, 4) else c.py_None();
    const dest_val = if (argc > 5) pk.argRef(argv, 5) else c.py_None();
    const nargs_val = if (argc > 6) pk.argRef(argv, 6) else c.py_None();
    const const_val = if (argc > 7) pk.argRef(argv, 7) else c.py_None();
    const choices_val = if (argc > 8) pk.argRef(argv, 8) else c.py_None();
    const required_val = if (argc > 9) pk.argRef(argv, 9) else c.py_False();
    _ = if (argc > 10) pk.argRef(argv, 10) else c.py_None(); // help (ignored)

    const first = names.items[0];
    const is_option = std.mem.startsWith(u8, first, "-");

    // Build spec dict
    c.py_newdict(c.py_r0());
    const spec = c.py_r0();
    if (!c.py_isnone(type_val)) _ = c.py_dict_setitem_by_str(spec, argparse_type_key, type_val);
    if (!c.py_isnone(default_val)) _ = c.py_dict_setitem_by_str(spec, argparse_default_key, default_val);
    if (!c.py_isnone(action_val)) _ = c.py_dict_setitem_by_str(spec, argparse_action_key, action_val);
    if (!c.py_isnone(nargs_val)) _ = c.py_dict_setitem_by_str(spec, argparse_nargs_key, nargs_val);
    if (!c.py_isnone(const_val)) _ = c.py_dict_setitem_by_str(spec, argparse_const_key, const_val);
    if (!c.py_isnone(choices_val)) _ = c.py_dict_setitem_by_str(spec, argparse_choices_key, choices_val);
    _ = c.py_dict_setitem_by_str(spec, argparse_required_key, required_val);

    if (is_option) {
        var dest_z: [:0]const u8 = undefined;
        if (!c.py_isnone(dest_val)) {
            if (!c.py_checkstr(dest_val)) return false;
            const s = c.py_tostr(dest_val) orelse return c.py_exception(c.tp_TypeError, "dest must be string");
            dest_z = alloc.dupeZ(u8, std.mem.span(s)) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        } else {
            dest_z = deriveDestFromOption(alloc, names.items) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        }

        // Store dest on spec for later.
        c.py_newstr(c.py_r1(), dest_z);
        _ = c.py_dict_setitem_by_str(c.py_r0(), argparse_dest_key, c.py_r1());

        // Add option string aliases -> dest
        for (names.items) |n| {
            const n_z = alloc.dupeZ(u8, n) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
            _ = c.py_dict_setitem_by_str(opt_map, n_z, c.py_r1());
        }

        _ = c.py_dict_setitem_by_str(opts, dest_z, spec);
        c.py_newstr(c.py_r2(), dest_z);
        c.py_list_append(opt_names, c.py_r2());

        if (group_dests) |gd| {
            c.py_list_append(gd, c.py_r2());
        }
    } else {
        // Positional: only the first name is used as dest.
        const dest_z = alloc.dupeZ(u8, first) catch return c.py_exception(c.tp_RuntimeError, "out of memory");
        c.py_newstr(c.py_r1(), dest_z);
        _ = c.py_dict_setitem_by_str(spec, argparse_name_key, c.py_r1());
        _ = c.py_dict_setitem_by_str(spec, argparse_dest_key, c.py_r1());
        c.py_list_append(pos, spec);
        if (group_dests) |gd| {
            c.py_list_append(gd, c.py_r1());
        }
    }

    c.py_newnone(c.py_retval());
    return true;
}

fn addArgument(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // Expected signature:
    // add_argument(self, *name_or_flags, type=None, default=None, action=None, dest=None,
    //              nargs=None, const=None, choices=None, required=False, help=None)
    return addArgumentImpl(pk.argRef(argv, 0), null, argc, argv);
}

fn groupNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    _ = c.py_newobject(c.py_retval(), tp_mutex_group, 2, 0);
    return true;
}

fn addMutuallyExclusiveGroup(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "add_mutually_exclusive_group() takes no arguments");
    const parser = pk.argRef(argv, 0);
    ensureStores(parser);

    _ = c.py_newobject(c.py_retval(), tp_mutex_group, 2, 0);
    const group = c.py_retval();
    c.py_setslot(group, 0, parser);

    c.py_newlist(c.py_r0());
    c.py_setslot(group, 1, c.py_r0());

    const groups = c.py_getdict(parser, c.py_name(argparse_groups_key)).?;
    c.py_list_append(groups, c.py_r0());
    return true;
}

fn groupAddArgument(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "add_argument() requires at least one name");
    const group = pk.argRef(argv, 0);
    const parser = c.py_getslot(group, 0);
    const dests = c.py_getslot(group, 1);
    return addArgumentImpl(parser, dests, argc, argv);
}

fn subparsersNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    _ = argc;
    _ = argv;
    _ = c.py_newobject(c.py_retval(), tp_subparsers, 2, 0);
    return true;
}

fn addSubparsers(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "add_subparsers(dest=None) takes 0 or 1 argument");
    const parser = pk.argRef(argv, 0);
    ensureStores(parser);
    const dest = pk.argRef(argv, 1);

    _ = c.py_newobject(c.py_retval(), tp_subparsers, 2, 0);
    const sp = c.py_retval();
    c.py_setslot(sp, 0, parser);
    c.py_setslot(sp, 1, dest);

    if (!c.py_isnone(dest)) {
        c.py_setdict(parser, c.py_name(argparse_subparsers_dest_key), dest);
    }
    return true;
}

fn subparsersAddParser(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) return c.py_exception(c.tp_TypeError, "add_parser(name) takes 1 argument");
    const sp = pk.argRef(argv, 0);
    const parent = c.py_getslot(sp, 0);
    const name_val = pk.argRef(argv, 1);
    if (!c.py_checkstr(name_val)) return false;
    const name_c = c.py_tostr(name_val) orelse return c.py_exception(c.tp_TypeError, "name must be string");

    // Create a new ArgumentParser.
    _ = c.py_newobject(c.py_retval(), tp_argument_parser, -1, 0);
    const child = c.py_retval();
    ensureStores(child);

    const subparsers = c.py_getdict(parent, c.py_name(argparse_subparsers_key)).?;
    _ = c.py_dict_setitem_by_str(subparsers, name_c, child);
    return true;
}

fn parseArgs(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "expected 1 argument");
    }

    const self = pk.argRef(argv, 0);
    ensureStores(self);

    var args_list = pk.argRef(argv, 1);
    if (c.py_isnone(args_list)) {
        const sys_mod = c.py_getmodule("sys");
        if (sys_mod == null) {
            return c.py_exception(c.tp_RuntimeError, "sys module not available");
        }
        const sys_argv = c.py_getdict(sys_mod.?, c.py_name("argv"));
        if (sys_argv == null) {
            return c.py_exception(c.tp_RuntimeError, "sys.argv not available");
        }
        c.py_newlist(c.py_r0());
        const sys_len = c.py_list_len(sys_argv.?);
        var i: c_int = 1;
        while (i < sys_len) : (i += 1) {
            const item = c.py_list_getitem(sys_argv.?, i);
            c.py_list_append(c.py_r0(), item);
        }
        args_list = c.py_r0();
    }

    const argc_list = seqLen(args_list);
    if (argc_list < 0) {
        return c.py_exception(c.tp_TypeError, "argv must be a list or tuple");
    }

    // Handle subparsers: if first token matches a registered subparser name, delegate parsing.
    const subparsers = c.py_getdict(self, c.py_name(argparse_subparsers_key)).?;
    if (c.py_dict_len(subparsers) > 0 and argc_list > 0) {
        const first_val = seqItem(args_list, 0);
        if (c.py_checkstr(first_val)) {
            const first_c = c.py_tostr(first_val) orelse null;
            if (first_c) |cmd| {
                const res = c.py_dict_getitem_by_str(subparsers, cmd);
                if (res > 0) {
                    const child = c.py_retval();
                    // Build remaining args list
                    c.py_newlist(c.py_r0());
                    var i: c_int = 1;
                    while (i < argc_list) : (i += 1) {
                        c.py_list_append(c.py_r0(), seqItem(args_list, i));
                    }

                    // Call child's parse_args directly.
                    var call_argv: [2]c.py_TValue = undefined;
                    call_argv[0] = child.*;
                    call_argv[1] = c.py_r0().*;
                    if (!parseArgs(2, @ptrCast(&call_argv[0]))) return false;
                    const ns = c.py_retval();

                    // Set dest if configured
                    const dest_val = c.py_getdict(self, c.py_name(argparse_subparsers_dest_key));
                    if (dest_val != null and !c.py_isnone(dest_val.?)) {
                        const dest_c = c.py_tostr(dest_val.?) orelse return c.py_exception(c.tp_TypeError, "dest must be string");
                        c.py_newstr(c.py_r1(), cmd);
                        setAttr(ns, dest_c, c.py_r1());
                    }
                    return true;
                }
            }
        }
    }

    const opts = c.py_getdict(self, c.py_name(argparse_opts_key)).?;
    const opt_map = c.py_getdict(self, c.py_name(argparse_opt_map_key)).?;
    const pos = c.py_getdict(self, c.py_name(argparse_pos_key)).?;
    const opt_names = c.py_getdict(self, c.py_name(argparse_opt_names_key)).?;
    const groups = c.py_getdict(self, c.py_name(argparse_groups_key)).?;

    _ = c.py_newobject(c.py_r3(), tp_namespace, -1, 0);
    const ns = c.py_r3();

    // Track which dests were explicitly set
    c.py_newdict(c.py_r4());
    const seen = c.py_r4();

    const opt_count = c.py_list_len(opt_names);
    var oi: c_int = 0;
    while (oi < opt_count) : (oi += 1) {
        const name_val = c.py_list_getitem(opt_names, oi);
        const name_c = c.py_tostr(name_val);
        if (name_c == null) continue;
        const res = c.py_dict_getitem_by_str(opts, name_c);
        if (res <= 0) continue;
        c.py_r5().* = c.py_retval().*;
        const spec = c.py_r5();
        const has_action = c.py_dict_getitem_by_str(spec, argparse_action_key);
        var action_c: ?[*:0]const u8 = null;
        if (has_action > 0 and !c.py_isnone(c.py_retval())) {
            c.py_r6().* = c.py_retval().*;
            action_c = c.py_tostr(c.py_r6());
        }

        const has_default = c.py_dict_getitem_by_str(spec, argparse_default_key);
        if (has_default > 0 and !c.py_isnone(c.py_retval())) {
            c.py_r7().* = c.py_retval().*;
            setAttr(ns, name_c, c.py_r7());
        } else if (action_c != null) {
            const action = std.mem.span(action_c.?);
            if (std.mem.eql(u8, action, "store_true")) {
                c.py_newbool(c.py_r0(), false);
                setAttr(ns, name_c, c.py_r0());
            } else if (std.mem.eql(u8, action, "store_false")) {
                c.py_newbool(c.py_r0(), true);
                setAttr(ns, name_c, c.py_r0());
            }
        }
    }

    var pos_idx: c_int = 0;
    var i: c_int = 0;
    while (i < argc_list) {
        const arg_val = seqItem(args_list, i);
        const arg_c = c.py_tostr(arg_val);
        if (arg_c == null) {
            return c.py_exception(c.tp_TypeError, "argument must be a string");
        }
        const arg = std.mem.span(arg_c);
        if (std.mem.startsWith(u8, arg, "-")) {
            const res = c.py_dict_getitem_by_str(opt_map, arg_c);
            if (res <= 0) return c.py_exception(c.tp_SystemExit, "unknown option");
            c.py_r5().* = c.py_retval().*;
            const dest_val = c.py_r5();
            const dest_c = c.py_tostr(dest_val) orelse return c.py_exception(c.tp_RuntimeError, "dest missing");

            const spec_res = c.py_dict_getitem_by_str(opts, dest_c);
            if (spec_res <= 0) return c.py_exception(c.tp_SystemExit, "unknown option");
            c.py_r6().* = c.py_retval().*;
            const spec = c.py_r6();

            // Mutually exclusive groups check
            const g_len = c.py_list_len(groups);
            var gi: c_int = 0;
            while (gi < g_len) : (gi += 1) {
                const group_list = c.py_list_getitem(groups, gi);
                const dlen = c.py_list_len(group_list);
                var dj: c_int = 0;
                var in_group = false;
                while (dj < dlen) : (dj += 1) {
                    const dv = c.py_list_getitem(group_list, dj);
                    if (!c.py_checkstr(dv)) continue;
                    const dc = c.py_tostr(dv) orelse continue;
                    if (std.mem.eql(u8, std.mem.span(dc), std.mem.span(dest_c))) {
                        in_group = true;
                        break;
                    }
                }
                if (in_group) {
                    // if any other dest in this group already seen, error
                    var dk: c_int = 0;
                    while (dk < dlen) : (dk += 1) {
                        const dv = c.py_list_getitem(group_list, dk);
                        if (!c.py_checkstr(dv)) continue;
                        const dc = c.py_tostr(dv) orelse continue;
                        if (std.mem.eql(u8, std.mem.span(dc), std.mem.span(dest_c))) continue;
                        const seen_res = c.py_dict_getitem_by_str(seen, dc);
                        if (seen_res > 0) return c.py_exception(c.tp_SystemExit, "mutually exclusive");
                    }
                }
            }

            _ = c.py_dict_setitem_by_str(seen, dest_c, c.py_True());

            const has_action = c.py_dict_getitem_by_str(spec, argparse_action_key);
            if (has_action > 0 and !c.py_isnone(c.py_retval())) {
                c.py_r7().* = c.py_retval().*;
                const action_name = c.py_tostr(c.py_r7()) orelse return c.py_exception(c.tp_TypeError, "action must be string");
                const action = std.mem.span(action_name);
                if (std.mem.eql(u8, action, "store_true")) {
                    c.py_newbool(c.py_r0(), true);
                    setAttr(ns, dest_c, c.py_r0());
                    i += 1;
                    continue;
                }
                if (std.mem.eql(u8, action, "store_false")) {
                    c.py_newbool(c.py_r0(), false);
                    setAttr(ns, dest_c, c.py_r0());
                    i += 1;
                    continue;
                }
            }

            // Determine nargs
            var nargs_mode: ?u8 = null;
            const has_nargs = c.py_dict_getitem_by_str(spec, argparse_nargs_key);
            if (has_nargs > 0 and !c.py_isnone(c.py_retval())) {
                const s = c.py_tostr(c.py_retval()) orelse return c.py_exception(c.tp_TypeError, "nargs must be string");
                const sv = std.mem.span(s);
                if (sv.len == 1) nargs_mode = sv[0];
            }

            if (nargs_mode == '*' or nargs_mode == '?') {
                c.py_newlist(c.py_r0());
                var j: c_int = i + 1;
                while (j < argc_list) : (j += 1) {
                    const next_val = seqItem(args_list, j);
                    const next_c = c.py_tostr(next_val) orelse break;
                    if (std.mem.startsWith(u8, std.mem.span(next_c), "-")) {
                        const m = c.py_dict_getitem_by_str(opt_map, next_c);
                        if (m > 0) break;
                    }
                    c.py_list_append(c.py_r0(), next_val);
                }

                if (nargs_mode == '?') {
                    if (c.py_list_len(c.py_r0()) == 0) {
                        const has_const = c.py_dict_getitem_by_str(spec, argparse_const_key);
                        if (has_const > 0 and !c.py_isnone(c.py_retval())) {
                            c.py_r1().* = c.py_retval().*;
                            setAttr(ns, dest_c, c.py_r1());
                        } else {
                            c.py_newnone(c.py_r1());
                            setAttr(ns, dest_c, c.py_r1());
                        }
                        i += 1;
                    } else {
                        const one = c.py_list_getitem(c.py_r0(), 0);
                        setAttr(ns, dest_c, one);
                        i += 2;
                    }
                    continue;
                }

                // nargs '*'
                // Convert list elements (if any) via type and validate choices.
                var out_list = c.py_r0();
                // Type conversion for list values
                const has_type = c.py_dict_getitem_by_str(spec, argparse_type_key);
                if (has_type > 0 and !c.py_isnone(c.py_retval())) {
                    const typ = c.py_retval();
                    const n = c.py_list_len(out_list);
                    c.py_newlist(c.py_r1());
                    var k: c_int = 0;
                    while (k < n) : (k += 1) {
                        const raw = c.py_list_getitem(out_list, k);
                        if (!c.py_call(typ, 1, raw)) return false;
                        c.py_list_append(c.py_r1(), c.py_retval());
                    }
                    out_list = c.py_r1();
                }
                setAttr(ns, dest_c, out_list);
                i += 1 + c.py_list_len(out_list);
                continue;
            }

            // Default: requires one value
            if (i + 1 >= argc_list) return c.py_exception(c.tp_SystemExit, "missing option value");
            var val = seqItem(args_list, i + 1);
            const has_type = c.py_dict_getitem_by_str(spec, argparse_type_key);
            if (has_type > 0 and !c.py_isnone(c.py_retval())) {
                c.py_r7().* = c.py_retval().*;
                const typ = c.py_r7();
                if (!c.py_call(typ, 1, val)) return false;
                c.py_r7().* = c.py_retval().*;
                val = c.py_r7();
            }

            const has_choices = c.py_dict_getitem_by_str(spec, argparse_choices_key);
            if (has_choices > 0 and !c.py_isnone(c.py_retval())) {
                const ch_list = c.py_retval();
                if (c.py_islist(ch_list) or c.py_istuple(ch_list)) {
                    const v_c = c.py_tostr(val) orelse return c.py_exception(c.tp_SystemExit, "invalid choice");
                    const v = std.mem.span(v_c);
                    const n = seqLen(ch_list);
                    var ok = false;
                    var cj: c_int = 0;
                    while (cj < n) : (cj += 1) {
                        const item = seqItem(ch_list, cj);
                        const ic = c.py_tostr(item) orelse continue;
                        if (std.mem.eql(u8, v, std.mem.span(ic))) {
                            ok = true;
                            break;
                        }
                    }
                    if (!ok) return c.py_exception(c.tp_SystemExit, "invalid choice");
                }
            }

            setAttr(ns, dest_c, val);
            i += 2;
        } else {
            if (pos_idx >= c.py_list_len(pos)) {
                return c.py_exception(c.tp_SystemExit, "unexpected argument");
            }
            const spec = c.py_list_getitem(pos, pos_idx);
            pos_idx += 1;
            var val = arg_val;
            const name_res = c.py_dict_getitem_by_str(spec, argparse_name_key);
            if (name_res <= 0) {
                return c.py_exception(c.tp_RuntimeError, "positional name missing");
            }
            c.py_r5().* = c.py_retval().*;
            const name_val = c.py_r5();
            const name_c = c.py_tostr(name_val);
            if (name_c == null) {
                return c.py_exception(c.tp_TypeError, "positional name must be string");
            }

            // Handle nargs for positional
            var nargs_mode: ?u8 = null;
            const has_nargs = c.py_dict_getitem_by_str(spec, argparse_nargs_key);
            if (has_nargs > 0 and !c.py_isnone(c.py_retval())) {
                const s = c.py_tostr(c.py_retval()) orelse return c.py_exception(c.tp_TypeError, "nargs must be string");
                const sv = std.mem.span(s);
                if (sv.len == 1) nargs_mode = sv[0];
            }

            if (nargs_mode == '+') {
                c.py_newlist(c.py_r0());
                var j: c_int = i;
                while (j < argc_list) : (j += 1) {
                    const next_val = seqItem(args_list, j);
                    const next_c = c.py_tostr(next_val) orelse break;
                    if (std.mem.startsWith(u8, std.mem.span(next_c), "-")) {
                        const m = c.py_dict_getitem_by_str(opt_map, next_c);
                        if (m > 0) break;
                    }
                    c.py_list_append(c.py_r0(), next_val);
                }
                if (c.py_list_len(c.py_r0()) == 0) return c.py_exception(c.tp_SystemExit, "missing argument");
                setAttr(ns, name_c, c.py_r0());
                i += c.py_list_len(c.py_r0());
                continue;
            }

            // Type conversion for single positional
            const has_type = c.py_dict_getitem_by_str(spec, argparse_type_key);
            if (has_type > 0 and !c.py_isnone(c.py_retval())) {
                const typ = c.py_retval();
                if (!c.py_call(typ, 1, val)) return false;
                val = c.py_retval();
            }

            setAttr(ns, name_c, val);
            i += 1;
        }
    }

    // Enforce required options
    oi = 0;
    while (oi < opt_count) : (oi += 1) {
        const name_val = c.py_list_getitem(opt_names, oi);
        const name_c = c.py_tostr(name_val);
        if (name_c == null) continue;
        const res = c.py_dict_getitem_by_str(opts, name_c);
        if (res <= 0) continue;
        c.py_r5().* = c.py_retval().*;
        const spec = c.py_r5();
        const has_required = c.py_dict_getitem_by_str(spec, argparse_required_key);
        if (has_required > 0 and c.py_tobool(c.py_retval())) {
            const seen_res = c.py_dict_getitem_by_str(seen, name_c);
            if (seen_res <= 0) return c.py_exception(c.tp_SystemExit, "required option missing");
        }
    }

    pk.setRetval(ns);
    return true;
}

pub fn register() void {
    const name: [:0]const u8 = "argparse";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);
    tp_argument_parser = c.py_newtype("ArgumentParser", c.tp_object, module, null);
    tp_namespace = c.py_newtype("Namespace", c.tp_object, module, null);
    tp_mutex_group = c.py_newtype("_MutuallyExclusiveGroup", c.tp_object, module, null);
    tp_subparsers = c.py_newtype("_SubParsers", c.tp_object, module, null);

    const sig_new: [:0]const u8 = "__new__(cls, prog=None, description=None)";
    const sig_init: [:0]const u8 = "__init__(self, prog=None, description=None)";
    const sig_add: [:0]const u8 =
        "add_argument(self, *name_or_flags, type=None, default=None, action=None, dest=None, nargs=None, const=None, choices=None, required=False, help=None)";
    const sig_parse: [:0]const u8 = "parse_args(self, argv=None)";
    c.py_bind(c.py_tpobject(tp_argument_parser), sig_new, new);
    c.py_bind(c.py_tpobject(tp_argument_parser), sig_init, init);
    c.py_bind(c.py_tpobject(tp_argument_parser), sig_add, addArgument);
    c.py_bind(c.py_tpobject(tp_argument_parser), sig_parse, parseArgs);
    c.py_bindmethod(tp_argument_parser, "add_mutually_exclusive_group", addMutuallyExclusiveGroup);
    c.py_bind(c.py_tpobject(tp_argument_parser), "add_subparsers(self, dest=None)", addSubparsers);

    const parser_name: [:0]const u8 = "ArgumentParser";
    c.py_setdict(module, c.py_name(parser_name), c.py_tpobject(tp_argument_parser));
    const ns_name: [:0]const u8 = "Namespace";
    c.py_setdict(module, c.py_name(ns_name), c.py_tpobject(tp_namespace));

    c.py_bind(c.py_tpobject(tp_mutex_group), "__new__(cls)", groupNew);
    c.py_bind(c.py_tpobject(tp_mutex_group), sig_add, groupAddArgument);

    c.py_bind(c.py_tpobject(tp_subparsers), "__new__(cls)", subparsersNew);
    c.py_bindmethod(tp_subparsers, "add_parser", subparsersAddParser);
}
