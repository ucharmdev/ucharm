/// pk.zig - Robust PocketPy Extension API
///
/// Provides a safer, more ergonomic API for building PocketPy modules in Zig.
/// Solves common issues like register overwriting, verbose type checking, and boilerplate.
pub const c = @cImport({
    @cDefine("PK_IS_PUBLIC_INCLUDE", "1");
    @cInclude("pocketpy.h");
});

const std = @import("std");

// =============================================================================
// Value - Safe wrapper around py_TValue
// =============================================================================

/// Safe wrapper around py_TValue that prevents register issues.
/// Values are copied to local storage, avoiding register clobbering.
pub const Value = struct {
    val: c.py_TValue,

    /// Wrap a py_Ref into a Value (copies the value)
    pub fn from(r: c.py_Ref) Value {
        return .{ .val = r.* };
    }

    /// Get the underlying reference (use with caution)
    pub fn ref(self: *Value) c.py_Ref {
        return &self.val;
    }

    /// Get the underlying reference (const version)
    pub fn refConst(self: *const Value) c.py_Ref {
        return @constCast(&self.val);
    }

    // Type checks
    pub fn isNone(self: *Value) bool {
        return c.py_isnone(self.ref());
    }

    pub fn isNil(self: *Value) bool {
        return c.py_isnil(self.ref());
    }

    pub fn isInt(self: *Value) bool {
        return c.py_isint(self.ref());
    }

    pub fn isFloat(self: *Value) bool {
        return c.py_isfloat(self.ref());
    }

    pub fn isBool(self: *Value) bool {
        return c.py_isbool(self.ref());
    }

    pub fn isStr(self: *Value) bool {
        return c.py_isstr(self.ref());
    }

    pub fn isList(self: *Value) bool {
        return c.py_islist(self.ref());
    }

    pub fn isTuple(self: *Value) bool {
        return c.py_istuple(self.ref());
    }

    pub fn isDict(self: *Value) bool {
        return c.py_isdict(self.ref());
    }

    pub fn isCallable(self: *Value) bool {
        return c.py_callable(self.ref());
    }

    pub fn isType(self: *Value, t: c.py_Type) bool {
        return c.py_istype(self.ref(), t);
    }

    pub fn isinstance(self: *Value, t: c.py_Type) bool {
        return c.py_isinstance(self.ref(), t);
    }

    pub fn typeof(self: *Value) c.py_Type {
        return c.py_typeof(self.ref());
    }

    // Value extraction (returns null if wrong type)
    pub fn toInt(self: *Value) ?i64 {
        if (!self.isInt()) return null;
        return c.py_toint(self.ref());
    }

    pub fn toFloat(self: *Value) ?f64 {
        if (!self.isFloat()) return null;
        return c.py_tofloat(self.ref());
    }

    pub fn toNumber(self: *Value) ?f64 {
        if (self.isInt()) return @floatFromInt(c.py_toint(self.ref()));
        if (self.isFloat()) return c.py_tofloat(self.ref());
        return null;
    }

    pub fn toBool(self: *Value) ?bool {
        if (!self.isBool()) return null;
        return c.py_tobool(self.ref());
    }

    pub fn toStr(self: *Value) ?[]const u8 {
        if (!self.isStr()) return null;
        const ptr = c.py_tostr(self.ref());
        return ptr[0..std.mem.len(ptr)];
    }

    pub fn toStrSv(self: *Value) ?c.c11_sv {
        if (!self.isStr()) return null;
        return c.py_tosv(self.ref());
    }

    pub fn getUserdata(self: *Value, comptime T: type) ?*T {
        const ptr = c.py_touserdata(self.ref());
        if (ptr == null) return null;
        return @ptrCast(@alignCast(ptr));
    }

    // Sequence operations
    pub fn len(self: *Value) ?usize {
        if (self.isList()) return @intCast(c.py_list_len(self.ref()));
        if (self.isTuple()) return @intCast(c.py_tuple_len(self.ref()));
        return null;
    }

    pub fn getItem(self: *Value, index: usize) ?Value {
        if (self.isList()) {
            const item = c.py_list_getitem(self.ref(), @intCast(index));
            return Value.from(item);
        }
        if (self.isTuple()) {
            const item = c.py_tuple_getitem(self.ref(), @intCast(index));
            return Value.from(item);
        }
        return null;
    }

    // Dict operations
    pub fn dictLen(self: *Value) ?usize {
        if (!self.isDict()) return null;
        return @intCast(c.py_dict_len(self.ref()));
    }

    pub fn dictGet(self: *Value, key: *Value) ?Value {
        if (!self.isDict()) return null;
        const result = c.py_dict_getitem(self.ref(), key.ref());
        if (result <= 0) return null;
        return Value.from(c.py_retval());
    }

    pub fn dictGetStr(self: *Value, key: [:0]const u8) ?Value {
        if (!self.isDict()) return null;
        const result = c.py_dict_getitem_by_str(self.ref(), key.ptr);
        if (result <= 0) return null;
        return Value.from(c.py_retval());
    }

    // Attribute operations
    pub fn getAttr(self: *Value, name: [:0]const u8) ?Value {
        if (!c.py_getattr(self.ref(), c.py_name(name.ptr))) return null;
        return Value.from(c.py_retval());
    }

    pub fn getDict(self: *Value, name: [:0]const u8) ?Value {
        const ptr = c.py_getdict(self.ref(), c.py_name(name.ptr));
        if (ptr == null) return null;
        return Value.from(ptr.?);
    }

    pub fn setDict(self: *Value, name: [:0]const u8, val: *Value) void {
        c.py_setdict(self.ref(), c.py_name(name.ptr), val.ref());
    }

    // Call the value as a function
    pub fn call(self: *Value, args: []Value) ?Value {
        if (!c.py_call(self.ref(), @intCast(args.len), if (args.len > 0) @ptrCast(args.ptr) else null)) {
            return null;
        }
        return Value.from(c.py_retval());
    }

    pub fn call0(self: *Value) ?Value {
        if (!c.py_call(self.ref(), 0, null)) return null;
        return Value.from(c.py_retval());
    }

    pub fn call1(self: *Value, arg0: *Value) ?Value {
        var args = [_]c.py_TValue{arg0.val};
        if (!c.py_call(self.ref(), 1, @ptrCast(&args))) return null;
        return Value.from(c.py_retval());
    }

    pub fn call2(self: *Value, arg0: *Value, arg1: *Value) ?Value {
        var args = [_]c.py_TValue{ arg0.val, arg1.val };
        if (!c.py_call(self.ref(), 2, @ptrCast(&args))) return null;
        return Value.from(c.py_retval());
    }
};

// =============================================================================
// Context - Safe function context for argument handling and returns
// =============================================================================

/// Context passed to wrapped functions for safe API access.
/// Provides safe argument extraction and return value helpers.
pub const Context = struct {
    argc: c_int,
    argv: c.py_StackRef,

    /// Get argument count
    pub fn argCount(self: *const Context) usize {
        return @intCast(self.argc);
    }

    /// Get argument at index as Value (copies to avoid register issues)
    pub fn arg(self: *const Context, index: usize) ?Value {
        if (index >= self.argCount()) return null;
        return Value.from(argRef(self.argv, index));
    }

    /// Get argument at index as int
    pub fn argInt(self: *const Context, index: usize) ?i64 {
        var v = self.arg(index) orelse return null;
        return v.toInt();
    }

    /// Get argument at index as float (accepts int or float)
    pub fn argFloat(self: *const Context, index: usize) ?f64 {
        var v = self.arg(index) orelse return null;
        return v.toNumber();
    }

    /// Get argument at index as string
    /// Note: Returns a slice into the original Python string data
    pub fn argStr(self: *const Context, index: usize) ?[]const u8 {
        if (index >= self.argCount()) return null;
        const arg_ref = argRef(self.argv, index);
        if (!c.py_isstr(arg_ref)) return null;
        const ptr = c.py_tostr(arg_ref);
        return ptr[0..std.mem.len(ptr)];
    }

    /// Get argument at index as bool
    pub fn argBool(self: *const Context, index: usize) ?bool {
        var v = self.arg(index) orelse return null;
        return v.toBool();
    }

    /// Get optional argument (returns null if index out of bounds OR if value is None)
    pub fn argOptional(self: *const Context, index: usize) ?Value {
        var v = self.arg(index) orelse return null;
        if (v.isNone()) return null;
        return v;
    }

    /// Get userdata from argument
    pub fn argUserdata(self: *const Context, index: usize, comptime T: type) ?*T {
        var v = self.arg(index) orelse return null;
        return v.getUserdata(T);
    }

    // Return helpers - all return true for convenience in chaining
    pub fn returnNone(self: *const Context) bool {
        _ = self;
        c.py_newnone(c.py_retval());
        return true;
    }

    pub fn returnInt(self: *const Context, v: i64) bool {
        _ = self;
        c.py_newint(c.py_retval(), v);
        return true;
    }

    pub fn returnFloat(self: *const Context, v: f64) bool {
        _ = self;
        c.py_newfloat(c.py_retval(), v);
        return true;
    }

    pub fn returnBool(self: *const Context, v: bool) bool {
        _ = self;
        c.py_newbool(c.py_retval(), v);
        return true;
    }

    pub fn returnStr(self: *const Context, s: []const u8) bool {
        _ = self;
        c.py_newstrv(c.py_retval(), .{ .data = s.ptr, .size = @intCast(s.len) });
        return true;
    }

    pub fn returnStrZ(self: *const Context, s: [:0]const u8) bool {
        _ = self;
        c.py_newstr(c.py_retval(), s.ptr);
        return true;
    }

    pub fn returnValue(self: *const Context, v: Value) bool {
        _ = self;
        c.py_retval().* = v.val;
        return true;
    }

    /// Return a new empty list
    pub fn returnList(self: *const Context) bool {
        _ = self;
        c.py_newlist(c.py_retval());
        return true;
    }

    /// Return a new empty dict
    pub fn returnDict(self: *const Context) bool {
        _ = self;
        c.py_newdict(c.py_retval());
        return true;
    }

    // Error helpers - all return false for convenience
    pub fn typeError(self: *const Context, comptime msg: [:0]const u8) bool {
        _ = self;
        return c.py_exception(c.tp_TypeError, msg.ptr);
    }

    pub fn valueError(self: *const Context, comptime msg: [:0]const u8) bool {
        _ = self;
        return c.py_exception(c.tp_ValueError, msg.ptr);
    }

    pub fn runtimeError(self: *const Context, comptime msg: [:0]const u8) bool {
        _ = self;
        return c.py_exception(c.tp_RuntimeError, msg.ptr);
    }

    pub fn indexError(self: *const Context, comptime msg: [:0]const u8) bool {
        _ = self;
        return c.py_exception(c.tp_IndexError, msg.ptr);
    }

    pub fn keyError(self: *const Context, key: *Value) bool {
        _ = self;
        return c.KeyError(key.ref());
    }

    pub fn attributeError(self: *const Context, comptime msg: [:0]const u8) bool {
        _ = self;
        return c.py_exception(c.tp_AttributeError, msg.ptr);
    }
};

// =============================================================================
// Function wrapper - wraps Zig functions to handle boilerplate
// =============================================================================

/// Type signature for wrapped functions
pub const WrappedFn = *const fn (*Context) bool;

/// Wraps a Zig function to create a py_CFunction.
/// Handles argc validation and context creation.
pub fn wrapFn(comptime min_args: comptime_int, comptime max_args: comptime_int, comptime func: WrappedFn) c.py_CFunction {
    const S = struct {
        fn call(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
            if (argc < min_args) {
                return c.py_exception(c.tp_TypeError, "too few arguments");
            }
            if (max_args >= 0 and argc > max_args) {
                return c.py_exception(c.tp_TypeError, "too many arguments");
            }
            var ctx = Context{ .argc = argc, .argv = argv };
            return func(&ctx);
        }
    };
    return S.call;
}

/// Wraps a function that takes exactly N arguments
pub fn wrapFnN(comptime n: comptime_int, comptime func: WrappedFn) c.py_CFunction {
    return wrapFn(n, n, func);
}

/// Wraps a variadic function (any number of arguments)
pub fn wrapFnVariadic(comptime func: WrappedFn) c.py_CFunction {
    return wrapFn(0, -1, func);
}

// =============================================================================
// TypeBuilder - fluent API for creating custom types
// =============================================================================

pub const TypeBuilder = struct {
    type_obj: c.py_Type,

    /// Create a new type
    pub fn new(name: [:0]const u8, base: c.py_Type, module: c.py_GlobalRef, dtor: c.py_Dtor) TypeBuilder {
        return .{
            .type_obj = c.py_newtype(name.ptr, base, module, dtor),
        };
    }

    /// Create a new type with object as base
    pub fn newSimple(name: [:0]const u8, module: c.py_GlobalRef) TypeBuilder {
        return new(name, c.tp_object, module, null);
    }

    /// Bind a magic method (__init__, __call__, etc.)
    pub fn magic(self: *TypeBuilder, name: [:0]const u8, func: c.py_CFunction) *TypeBuilder {
        c.py_bindmagic(self.type_obj, c.py_name(name.ptr), func);
        return self;
    }

    /// Bind a wrapped magic method
    pub fn magicWrapped(self: *TypeBuilder, name: [:0]const u8, comptime min: comptime_int, comptime max: comptime_int, comptime func: WrappedFn) *TypeBuilder {
        return self.magic(name, wrapFn(min, max, func));
    }

    /// Bind a regular method
    pub fn method(self: *TypeBuilder, name: [:0]const u8, func: c.py_CFunction) *TypeBuilder {
        c.py_bindmethod(self.type_obj, name.ptr, func);
        return self;
    }

    /// Bind a wrapped method
    pub fn methodWrapped(self: *TypeBuilder, name: [:0]const u8, comptime min: comptime_int, comptime max: comptime_int, comptime func: WrappedFn) *TypeBuilder {
        return self.method(name, wrapFn(min, max, func));
    }

    /// Bind a static method
    pub fn staticMethod(self: *TypeBuilder, name: [:0]const u8, func: c.py_CFunction) *TypeBuilder {
        c.py_bindstaticmethod(self.type_obj, name.ptr, func);
        return self;
    }

    /// Bind a property (getter only)
    pub fn property(self: *TypeBuilder, name: [:0]const u8, getter: c.py_CFunction) *TypeBuilder {
        c.py_bindproperty(self.type_obj, name.ptr, getter, null);
        return self;
    }

    /// Bind a property (getter and setter)
    pub fn propertyRW(self: *TypeBuilder, name: [:0]const u8, getter: c.py_CFunction, setter: c.py_CFunction) *TypeBuilder {
        c.py_bindproperty(self.type_obj, name.ptr, getter, setter);
        return self;
    }

    /// Mark type as final (cannot be subclassed)
    pub fn setFinal(self: *TypeBuilder) *TypeBuilder {
        c.py_tpsetfinal(self.type_obj);
        return self;
    }

    /// Get the built type
    pub fn build(self: *TypeBuilder) c.py_Type {
        return self.type_obj;
    }
};

// =============================================================================
// ModuleBuilder - fluent API for creating modules
// =============================================================================

pub const ModuleBuilder = struct {
    module: c.py_GlobalRef,

    /// Create a new module
    pub fn new(name: [:0]const u8) ModuleBuilder {
        return .{
            .module = c.py_newmodule(name.ptr),
        };
    }

    /// Get an existing module (for extending)
    pub fn extend(name: [:0]const u8) ?ModuleBuilder {
        const m = c.py_getmodule(name.ptr);
        if (m == null) return null;
        return .{ .module = m };
    }

    /// Import and extend a module (imports it first if not loaded)
    pub fn importAndExtend(name: [:0]const u8) ?ModuleBuilder {
        // Try to import first
        const result = c.py_import(name.ptr);
        if (result < 0) {
            c.py_clearexc(null);
            return null;
        }
        if (result == 0) return null;
        return extend(name);
    }

    /// Bind a raw function
    pub fn func(self: *ModuleBuilder, name: [:0]const u8, f: c.py_CFunction) *ModuleBuilder {
        c.py_bindfunc(self.module, name.ptr, f);
        return self;
    }

    /// Bind a wrapped function with argc validation
    pub fn funcWrapped(self: *ModuleBuilder, name: [:0]const u8, comptime min: comptime_int, comptime max: comptime_int, comptime f: WrappedFn) *ModuleBuilder {
        return self.func(name, wrapFn(min, max, f));
    }

    /// Bind a function with signature (decl-based style) - supports kwargs
    pub fn funcSig(self: *ModuleBuilder, sig: [:0]const u8, f: c.py_CFunction) *ModuleBuilder {
        c.py_bind(self.module, sig.ptr, f);
        return self;
    }

    /// Bind a wrapped function with signature - supports kwargs!
    /// Use this for functions that need keyword argument support.
    /// The signature defines default values, e.g. "style(text, fg=None, bg=None, bold=False)"
    pub fn funcSigWrapped(self: *ModuleBuilder, sig: [:0]const u8, comptime min: comptime_int, comptime max: comptime_int, comptime f: WrappedFn) *ModuleBuilder {
        return self.funcSig(sig, wrapFn(min, max, f));
    }

    /// Add an integer constant
    pub fn constInt(self: *ModuleBuilder, name: [:0]const u8, value: i64) *ModuleBuilder {
        c.py_newint(c.py_r0(), value);
        c.py_setdict(self.module, c.py_name(name.ptr), c.py_r0());
        return self;
    }

    /// Add a float constant
    pub fn constFloat(self: *ModuleBuilder, name: [:0]const u8, value: f64) *ModuleBuilder {
        c.py_newfloat(c.py_r0(), value);
        c.py_setdict(self.module, c.py_name(name.ptr), c.py_r0());
        return self;
    }

    /// Add a string constant
    pub fn constStr(self: *ModuleBuilder, name: [:0]const u8, value: [:0]const u8) *ModuleBuilder {
        c.py_newstr(c.py_r0(), value.ptr);
        c.py_setdict(self.module, c.py_name(name.ptr), c.py_r0());
        return self;
    }

    /// Add a bool constant
    pub fn constBool(self: *ModuleBuilder, name: [:0]const u8, value: bool) *ModuleBuilder {
        c.py_newbool(c.py_r0(), value);
        c.py_setdict(self.module, c.py_name(name.ptr), c.py_r0());
        return self;
    }

    /// Add None constant
    pub fn constNone(self: *ModuleBuilder, name: [:0]const u8) *ModuleBuilder {
        c.py_newnone(c.py_r0());
        c.py_setdict(self.module, c.py_name(name.ptr), c.py_r0());
        return self;
    }

    /// Execute Python code in the module context
    pub fn exec(self: *ModuleBuilder, code: [:0]const u8) bool {
        return c.py_exec(code.ptr, "<module>", c.EXEC_MODE, self.module);
    }

    /// Get the module reference
    pub fn getModule(self: *ModuleBuilder) c.py_GlobalRef {
        return self.module;
    }

    /// Get dict entry from module
    pub fn getDict(self: *ModuleBuilder, name: [:0]const u8) ?Value {
        const ptr = c.py_getdict(self.module, c.py_name(name.ptr));
        if (ptr == null) return null;
        return Value.from(ptr.?);
    }

    /// Set dict entry in module
    pub fn setDict(self: *ModuleBuilder, name: [:0]const u8, val: *Value) *ModuleBuilder {
        c.py_setdict(self.module, c.py_name(name.ptr), val.ref());
        return self;
    }
};

// =============================================================================
// Utility helpers
// =============================================================================

/// Safe string buffer for building strings
pub const StringBuffer = struct {
    buf: [4096]u8 = undefined,
    len: usize = 0,

    pub fn append(self: *StringBuffer, s: []const u8) void {
        const remaining = self.buf.len - self.len;
        const to_copy = @min(s.len, remaining);
        @memcpy(self.buf[self.len..][0..to_copy], s[0..to_copy]);
        self.len += to_copy;
    }

    pub fn appendByte(self: *StringBuffer, byte: u8) void {
        if (self.len < self.buf.len) {
            self.buf[self.len] = byte;
            self.len += 1;
        }
    }

    pub fn slice(self: *const StringBuffer) []const u8 {
        return self.buf[0..self.len];
    }

    pub fn clear(self: *StringBuffer) void {
        self.len = 0;
    }
};

/// Iterator over Python sequences (list or tuple)
pub const SeqIterator = struct {
    seq: Value,
    index: usize = 0,
    length: usize,

    pub fn init(seq: Value) ?SeqIterator {
        const length = seq.len() orelse return null;
        return .{ .seq = seq, .length = length };
    }

    pub fn next(self: *SeqIterator) ?Value {
        if (self.index >= self.length) return null;
        const item = self.seq.getItem(self.index);
        self.index += 1;
        return item;
    }

    pub fn reset(self: *SeqIterator) void {
        self.index = 0;
    }
};

// =============================================================================
// Value creation helpers
// =============================================================================

/// Create a new int value
pub fn newInt(v: i64) Value {
    var val: c.py_TValue = undefined;
    c.py_newint(&val, v);
    return .{ .val = val };
}

/// Create a new float value
pub fn newFloat(v: f64) Value {
    var val: c.py_TValue = undefined;
    c.py_newfloat(&val, v);
    return .{ .val = val };
}

/// Create a new bool value
pub fn newBool(v: bool) Value {
    var val: c.py_TValue = undefined;
    c.py_newbool(&val, v);
    return .{ .val = val };
}

/// Create a new string value
pub fn newStr(s: []const u8) Value {
    var val: c.py_TValue = undefined;
    c.py_newstrv(&val, .{ .data = s.ptr, .size = @intCast(s.len) });
    return .{ .val = val };
}

/// Create a new string value from null-terminated string
pub fn newStrZ(s: [:0]const u8) Value {
    var val: c.py_TValue = undefined;
    c.py_newstr(&val, s.ptr);
    return .{ .val = val };
}

/// Create a None value
pub fn newNone() Value {
    var val: c.py_TValue = undefined;
    c.py_newnone(&val);
    return .{ .val = val };
}

/// Create a new empty list
pub fn newList() Value {
    var val: c.py_TValue = undefined;
    c.py_newlist(&val);
    return .{ .val = val };
}

/// Create a new empty dict
pub fn newDict() Value {
    var val: c.py_TValue = undefined;
    c.py_newdict(&val);
    return .{ .val = val };
}

/// Create a new tuple with given size (values uninitialized)
pub fn newTuple(size: usize) Value {
    var val: c.py_TValue = undefined;
    _ = c.py_newtuple(&val, @intCast(size));
    return .{ .val = val };
}

// =============================================================================
// Legacy helpers (for backwards compatibility)
// =============================================================================

pub fn argRef(argv: c.py_StackRef, idx: usize) c.py_Ref {
    const argv_ptr = argv.?;
    const argv_many: [*]c.py_TValue = @ptrCast(argv_ptr);
    return @ptrCast(argv_many + idx);
}

pub fn setRetval(val: c.py_Ref) void {
    c.py_retval().* = val.*;
}
