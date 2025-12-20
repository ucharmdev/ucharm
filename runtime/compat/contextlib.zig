/// contextlib.zig - Python contextlib module implementation
///
/// Provides context manager utilities: contextmanager, closing, suppress, nullcontext.
const pk = @import("pk");
const c = pk.c;

const contextlib_py =
    \\class _GeneratorContextManager:
    \\    def __init__(self, func, args, kwargs):
    \\        self.gen = func(*args, **kwargs)
    \\        self.func = func
    \\        self.args = args
    \\        self.kwargs = kwargs
    \\
    \\    def __enter__(self):
    \\        try:
    \\            return next(self.gen)
    \\        except StopIteration:
    \\            raise RuntimeError("generator didn't yield")
    \\
    \\    def __exit__(self, *args):
    \\        typ = args[0] if len(args) > 0 else None
    \\        value = args[1] if len(args) > 1 else None
    \\        traceback = args[2] if len(args) > 2 else None
    \\        if typ is None:
    \\            # Normal exit - try to exhaust the generator
    \\            exhausted = False
    \\            try:
    \\                next(self.gen)
    \\            except StopIteration:
    \\                exhausted = True
    \\            if exhausted:
    \\                return False
    \\            raise RuntimeError("generator didn't stop")
    \\        # Exception exit - re-throw into generator
    \\        if value is None:
    \\            value = typ()
    \\        try:
    \\            self.gen.throw(typ, value, traceback)
    \\        except StopIteration as exc:
    \\            return exc is not value
    \\        except:
    \\            raise
    \\        raise RuntimeError("generator didn't stop after throw()")
    \\
    \\class _ContextManagerWrapper:
    \\    def __init__(self, func):
    \\        self.func = func
    \\
    \\    def __call__(self, *args, **kwargs):
    \\        return _GeneratorContextManager(self.func, args, kwargs)
    \\
    \\def contextmanager(func):
    \\    return _ContextManagerWrapper(func)
    \\
    \\class closing:
    \\    def __init__(self, thing):
    \\        self.thing = thing
    \\
    \\    def __enter__(self):
    \\        return self.thing
    \\
    \\    def __exit__(self, *exc_info):
    \\        self.thing.close()
    \\        return False
    \\
    \\class suppress:
    \\    def __init__(self, *exceptions):
    \\        self._exceptions = exceptions
    \\
    \\    def __enter__(self):
    \\        return self
    \\
    \\    def __exit__(self, *args):
    \\        exctype = args[0] if len(args) > 0 else None
    \\        if exctype is None:
    \\            return False
    \\        for exc in self._exceptions:
    \\            if issubclass(exctype, exc):
    \\                return True
    \\        return False
    \\
    \\class nullcontext:
    \\    def __init__(self, enter_result=None):
    \\        self.enter_result = enter_result
    \\
    \\    def __enter__(self):
    \\        return self.enter_result
    \\
    \\    def __exit__(self, *excinfo):
    \\        return False
;

pub fn register() void {
    var builder = pk.ModuleBuilder.new("contextlib");
    _ = builder.exec(contextlib_py);
}
