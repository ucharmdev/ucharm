/// sqlite3.zig - `sqlite3` module placeholder
///
/// sqlite3 support is not built-in yet. This module exists so that imports
/// fail with a clear error message instead of `ImportError`.
const pk = @import("pk");
const c = pk.c;

fn connectFn(_: *pk.Context) bool {
    return c.py_exception(c.tp_NotImplementedError, "sqlite3 is not enabled in this build (planned)");
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("sqlite3");
    _ = builder.funcWrapped("connect", 1, 5, connectFn);
    c.py_newstr(c.py_r0(), "sqlite3 not enabled");
    c.py_setdict(builder.module, c.py_name("sqlite_version"), c.py_r0());
}
