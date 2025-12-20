/// gzip.zig - `gzip` module stub
///
/// Zig 0.15's stdlib compression APIs are not stable enough for us to ship yet.
/// This module exists so `import gzip` produces a clear error instead of `ImportError`.
const pk = @import("pk");
const c = pk.c;

fn notImplementedFn(_: *pk.Context) bool {
    return c.py_exception(c.tp_NotImplementedError, "gzip is not implemented yet");
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("gzip");
    _ = builder
        .funcWrapped("compress", 1, 2, notImplementedFn)
        .funcWrapped("decompress", 1, 1, notImplementedFn);
}
