const pk = @import("pk");
const c = pk.c;

var tp_typevar: c.py_Type = 0;

// Helper to create a simple type alias (a class that acts as a type hint)
fn createTypeAlias(module: c.py_Ref, name: [:0]const u8) void {
    const tp = c.py_newtype(name, c.tp_object, module, null);
    c.py_setdict(module, c.py_name(name), c.py_tpobject(tp));
}

// Helper to set a constant to a sentinel object
fn setTypingConstant(module: c.py_Ref, name: [:0]const u8) void {
    _ = c.py_newobject(c.py_r0(), c.tp_object, -1, 0);
    c.py_setdict(module, c.py_name(name), c.py_r0());
}

// TypeVar.__new__(cls, name, *constraints, bound=None, covariant=False, contravariant=False)
fn typeVarNewFn(ctx: *pk.Context) bool {
    var name_arg = ctx.arg(1) orelse return ctx.typeError("TypeVar() requires a name argument");

    // Create a TypeVar instance
    _ = c.py_newobject(c.py_retval(), tp_typevar, -1, 0);

    // Store the name as __name__ attribute
    c.py_setdict(c.py_retval(), c.py_name("__name__"), name_arg.ref());

    return true;
}

// TypeVar.__repr__
fn typeVarReprFn(ctx: *pk.Context) bool {
    var self = ctx.arg(0) orelse return ctx.typeError("self required");
    const name_val = c.py_getdict(self.ref(), c.py_name("__name__"));
    if (name_val) |n| {
        // Return ~name format
        const sv = c.py_tosv(n);
        var buf: [128]u8 = undefined;
        const prefix = "~";
        @memcpy(buf[0..prefix.len], prefix);
        const name_len: usize = @intCast(sv.size);
        if (name_len + prefix.len < buf.len) {
            @memcpy(buf[prefix.len .. prefix.len + name_len], sv.data[0..name_len]);
            return ctx.returnStr(buf[0 .. prefix.len + name_len]);
        }
    }
    return ctx.returnStrZ("~T");
}

// cast(typ, val) -> val (no-op, just returns the value)
fn castFn(ctx: *pk.Context) bool {
    const val = ctx.arg(1) orelse return ctx.typeError("cast() requires 2 arguments");
    return ctx.returnValue(val);
}

// overload(func) -> func (decorator that returns the function unchanged)
fn overloadFn(ctx: *pk.Context) bool {
    const func = ctx.arg(0) orelse return ctx.typeError("overload() requires 1 argument");
    return ctx.returnValue(func);
}

// final(func) -> func (decorator that returns the function unchanged)
fn finalFn(ctx: *pk.Context) bool {
    const func = ctx.arg(0) orelse return ctx.typeError("final() requires 1 argument");
    return ctx.returnValue(func);
}

// no_type_check(func) -> func (decorator that returns the function unchanged)
fn noTypeCheckFn(ctx: *pk.Context) bool {
    const func = ctx.arg(0) orelse return ctx.typeError("no_type_check() requires 1 argument");
    return ctx.returnValue(func);
}

// runtime_checkable(cls) -> cls (decorator that returns the class unchanged)
fn runtimeCheckableFn(ctx: *pk.Context) bool {
    const cls = ctx.arg(0) orelse return ctx.typeError("runtime_checkable() requires 1 argument");
    return ctx.returnValue(cls);
}

// get_args(tp) -> () (returns empty tuple for now)
fn getArgsFn(_: *pk.Context) bool {
    _ = c.py_newtuple(c.py_retval(), 0);
    return true;
}

// get_origin(tp) -> None (returns None for now)
fn getOriginFn(ctx: *pk.Context) bool {
    return ctx.returnNone();
}

// get_type_hints(obj) -> {} (returns empty dict for now)
fn getTypeHintsFn(ctx: *pk.Context) bool {
    return ctx.returnDict();
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("typing");

    // TypeVar - special handling to make it callable
    tp_typevar = c.py_newtype("TypeVar", c.tp_object, builder.module, null);
    c.py_bind(c.py_tpobject(tp_typevar), "__new__(cls, name, *constraints, bound=None, covariant=False, contravariant=False)", pk.wrapFn(2, -1, typeVarNewFn));
    c.py_bindmethod(tp_typevar, "__repr__", pk.wrapFn(1, 1, typeVarReprFn));
    c.py_setdict(builder.module, c.py_name("TypeVar"), c.py_tpobject(tp_typevar));

    // Generic types (type aliases)
    createTypeAlias(builder.module, "List");
    createTypeAlias(builder.module, "Dict");
    createTypeAlias(builder.module, "Set");
    createTypeAlias(builder.module, "FrozenSet");
    createTypeAlias(builder.module, "Tuple");
    createTypeAlias(builder.module, "Type");
    createTypeAlias(builder.module, "Callable");
    createTypeAlias(builder.module, "Generic");
    createTypeAlias(builder.module, "Protocol");

    // Abstract base classes
    createTypeAlias(builder.module, "Sequence");
    createTypeAlias(builder.module, "MutableSequence");
    createTypeAlias(builder.module, "Mapping");
    createTypeAlias(builder.module, "MutableMapping");
    createTypeAlias(builder.module, "Iterable");
    createTypeAlias(builder.module, "Iterator");
    createTypeAlias(builder.module, "Generator");
    createTypeAlias(builder.module, "Reversible");
    createTypeAlias(builder.module, "Container");
    createTypeAlias(builder.module, "Collection");
    createTypeAlias(builder.module, "Hashable");
    createTypeAlias(builder.module, "Sized");

    // Async types
    createTypeAlias(builder.module, "Awaitable");
    createTypeAlias(builder.module, "Coroutine");
    createTypeAlias(builder.module, "AsyncGenerator");
    createTypeAlias(builder.module, "AsyncIterator");
    createTypeAlias(builder.module, "AsyncIterable");

    // IO types
    createTypeAlias(builder.module, "IO");
    createTypeAlias(builder.module, "TextIO");
    createTypeAlias(builder.module, "BinaryIO");

    // Special forms (sentinel objects)
    setTypingConstant(builder.module, "Any");
    setTypingConstant(builder.module, "Optional");
    setTypingConstant(builder.module, "Union");
    setTypingConstant(builder.module, "ClassVar");
    setTypingConstant(builder.module, "Final");
    setTypingConstant(builder.module, "Literal");
    setTypingConstant(builder.module, "Annotated");
    setTypingConstant(builder.module, "NoReturn");
    setTypingConstant(builder.module, "Never");
    setTypingConstant(builder.module, "Self");
    setTypingConstant(builder.module, "LiteralString");
    setTypingConstant(builder.module, "TypeAlias");
    setTypingConstant(builder.module, "Concatenate");
    setTypingConstant(builder.module, "ParamSpec");
    setTypingConstant(builder.module, "TypeVarTuple");
    setTypingConstant(builder.module, "Unpack");
    setTypingConstant(builder.module, "Required");
    setTypingConstant(builder.module, "NotRequired");
    setTypingConstant(builder.module, "ReadOnly");

    // TYPE_CHECKING constant (False at runtime)
    _ = builder.constBool("TYPE_CHECKING", false);

    // Functions
    _ = builder
        .funcWrapped("cast", 2, 2, castFn)
        .funcWrapped("overload", 1, 1, overloadFn)
        .funcWrapped("final", 1, 1, finalFn)
        .funcWrapped("no_type_check", 1, 1, noTypeCheckFn)
        .funcWrapped("runtime_checkable", 1, 1, runtimeCheckableFn)
        .funcWrapped("get_args", 1, 1, getArgsFn)
        .funcWrapped("get_origin", 1, 1, getOriginFn)
        .funcWrapped("get_type_hints", 1, 3, getTypeHintsFn);
}
