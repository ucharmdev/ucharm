/// tarfile.zig - Minimal `tarfile` module stub
///
/// Provides import-compatibility only for now.
const pk = @import("pk");
const c = pk.c;

fn notImplementedFn(_: *pk.Context) bool {
    return c.py_exception(c.tp_NotImplementedError, "tarfile is not implemented yet");
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("tarfile");
    _ = builder
        .funcWrapped("open", 0, 3, notImplementedFn)
        .funcWrapped("is_tarfile", 1, 1, notImplementedFn);
}
