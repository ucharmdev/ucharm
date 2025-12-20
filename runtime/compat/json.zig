const pk = @import("pk");
const c = pk.c;

// Store reference to original loads function
var original_loads: c.py_TValue = undefined;

fn loadsFn(ctx: *pk.Context) bool {
    const arg = ctx.arg(0) orelse return ctx.typeError("expected string");

    // Call original loads
    var args: [1]c.py_TValue = .{arg.val};
    if (c.py_call(&original_loads, @intCast(ctx.argCount()), @ptrCast(&args))) {
        return true;
    }

    // Failed - check if it's a SyntaxError or ValueError, convert to ValueError
    // since JSONDecodeError = ValueError
    if (c.py_matchexc(c.tp_SyntaxError) or c.py_matchexc(c.tp_ValueError)) {
        c.py_clearexc(null);
        return ctx.valueError("Invalid JSON");
    }

    // Let other exceptions propagate
    return false;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.extend("json") orelse return;

    // Set JSONDecodeError as an alias to ValueError
    c.py_setdict(builder.module, c.py_name("JSONDecodeError"), c.py_tpobject(c.tp_ValueError));

    // Get reference to original loads
    const loads_ptr = c.py_getdict(builder.module, c.py_name("loads"));
    if (loads_ptr == null) return;
    original_loads = loads_ptr.?.*;

    // Replace loads with our wrapper
    _ = builder.funcWrapped("loads", 1, 1, loadsFn);
}
