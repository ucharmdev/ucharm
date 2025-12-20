const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn oserrorInitFn(ctx: *pk.Context) bool {
    // Allow OSError(errno, message) style construction; PocketPy BaseException only accepts 0 or 1.
    const argc = ctx.argCount();
    if (argc == 1 or argc == 2) {
        // Call BaseException.__init__(self) or BaseException.__init__(self, arg)
        const init_f = c.py_tpfindmagic(c.tp_BaseException, c.py_name("__init__"));
        var self = ctx.arg(0) orelse return ctx.typeError("self required");
        return c.py_call(init_f, @intCast(argc), self.ref());
    }
    if (argc == 3) {
        const init_f = c.py_tpfindmagic(c.tp_BaseException, c.py_name("__init__"));
        const self = ctx.arg(0) orelse return ctx.typeError("self required");
        const errno_arg = ctx.arg(1) orelse return ctx.typeError("errno required");
        var call_argv: [2]c.py_TValue = undefined;
        call_argv[0] = self.val;
        call_argv[1] = errno_arg.val;
        return c.py_call(init_f, 2, @ptrCast(&call_argv[0]));
    }
    return ctx.typeError("__init__() takes at most 2 arguments");
}

fn addErrnoVal(module: c.py_Ref, errorcode: *c.py_TValue, name: [:0]const u8, value: i64) void {
    // Add constant to module
    c.py_newint(c.py_r0(), value);
    c.py_setdict(module, c.py_name(name.ptr), c.py_r0());

    // Add reverse mapping to errorcode dict
    var key_val: c.py_TValue = undefined;
    var name_val: c.py_TValue = undefined;
    c.py_newint(&key_val, value);
    c.py_newstr(&name_val, name.ptr);
    _ = c.py_dict_setitem(errorcode, &key_val, &name_val);
}

pub fn register() void {
    const builder = pk.ModuleBuilder.new("errno");

    // Create errorcode dict - keep as stack value to avoid py_getdict issues
    var errorcode_val: c.py_TValue = undefined;
    c.py_newdict(&errorcode_val);
    c.py_setdict(builder.module, c.py_name("errorcode"), &errorcode_val);

    // Add all errno constants with reverse mapping
    addErrnoVal(builder.module, &errorcode_val, "EPERM", @intFromEnum(std.posix.E.PERM));
    addErrnoVal(builder.module, &errorcode_val, "ENOENT", @intFromEnum(std.posix.E.NOENT));
    addErrnoVal(builder.module, &errorcode_val, "ESRCH", @intFromEnum(std.posix.E.SRCH));
    addErrnoVal(builder.module, &errorcode_val, "EINTR", @intFromEnum(std.posix.E.INTR));
    addErrnoVal(builder.module, &errorcode_val, "EIO", @intFromEnum(std.posix.E.IO));
    addErrnoVal(builder.module, &errorcode_val, "EBADF", @intFromEnum(std.posix.E.BADF));
    addErrnoVal(builder.module, &errorcode_val, "ECHILD", @intFromEnum(std.posix.E.CHILD));
    addErrnoVal(builder.module, &errorcode_val, "EAGAIN", @intFromEnum(std.posix.E.AGAIN));
    addErrnoVal(builder.module, &errorcode_val, "ENOMEM", @intFromEnum(std.posix.E.NOMEM));
    addErrnoVal(builder.module, &errorcode_val, "EACCES", @intFromEnum(std.posix.E.ACCES));
    addErrnoVal(builder.module, &errorcode_val, "EEXIST", @intFromEnum(std.posix.E.EXIST));
    addErrnoVal(builder.module, &errorcode_val, "ENOTDIR", @intFromEnum(std.posix.E.NOTDIR));
    addErrnoVal(builder.module, &errorcode_val, "EISDIR", @intFromEnum(std.posix.E.ISDIR));
    addErrnoVal(builder.module, &errorcode_val, "EINVAL", @intFromEnum(std.posix.E.INVAL));
    addErrnoVal(builder.module, &errorcode_val, "ENOSPC", @intFromEnum(std.posix.E.NOSPC));
    addErrnoVal(builder.module, &errorcode_val, "EPIPE", @intFromEnum(std.posix.E.PIPE));

    // Compatibility: allow `OSError(errno, message)`
    c.py_bindmethod(c.tp_OSError, "__init__", pk.wrapFn(1, 3, oserrorInitFn));
}
