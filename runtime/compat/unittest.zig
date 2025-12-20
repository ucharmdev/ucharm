const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_skip_test: c.py_Type = 0;
var tp_test_result: c.py_Type = 0;
var tp_test_case: c.py_Type = 0;
var tp_test_suite: c.py_Type = 0;
var tp_test_loader: c.py_Type = 0;
var tp_skip_decorator: c.py_Type = 0;

fn isIdentical(a: c.py_Ref, b: c.py_Ref) bool {
    const av = a[0];
    const bv = b[0];
    if (av.type != bv.type) return false;
    if (av.is_ptr and bv.is_ptr) return av.unnamed_0._i64 == bv.unnamed_0._i64;
    if (c.py_isint(a)) return c.py_toint(a) == c.py_toint(b);
    if (c.py_isbool(a)) return c.py_tobool(a) == c.py_tobool(b);
    if (c.py_isfloat(a)) return c.py_tofloat(a) == c.py_tofloat(b);
    return true;
}

fn resultGetList(result: c.py_Ref, name: [:0]const u8) c.py_Ref {
    if (c.py_getdict(result, c.py_name(name.ptr))) |ptr| {
        if (c.py_islist(ptr)) return ptr;
    }
    c.py_newlist(c.py_r0());
    c.py_setdict(result, c.py_name(name.ptr), c.py_r0());
    return c.py_r0();
}

fn resultIncTestsRun(result: c.py_Ref) void {
    if (c.py_getdict(result, c.py_name("testsRun"))) |ptr| {
        if (c.py_isint(ptr)) {
            c.py_newint(c.py_r0(), c.py_toint(ptr) + 1);
            c.py_setdict(result, c.py_name("testsRun"), c.py_r0());
            return;
        }
    }
    c.py_newint(c.py_r0(), 1);
    c.py_setdict(result, c.py_name("testsRun"), c.py_r0());
}

// =============================================================================
// TestResult
// =============================================================================

fn testResultNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_test_result, -1, 0);
    return true;
}

fn testResultInit(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    c.py_newint(c.py_r0(), 0);
    c.py_setdict(self, c.py_name("testsRun"), c.py_r0());
    c.py_newlist(c.py_r0());
    c.py_setdict(self, c.py_name("failures"), c.py_r0());
    c.py_newlist(c.py_r0());
    c.py_setdict(self, c.py_name("errors"), c.py_r0());
    c.py_newlist(c.py_r0());
    c.py_setdict(self, c.py_name("skipped"), c.py_r0());
    c.py_newlist(c.py_r0());
    c.py_setdict(self, c.py_name("expectedFailures"), c.py_r0());
    c.py_newlist(c.py_r0());
    c.py_setdict(self, c.py_name("unexpectedSuccesses"), c.py_r0());
    c.py_newnone(c.py_retval());
    return true;
}

fn testResultWasSuccessful(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const failures = resultGetList(self, "failures");
    const errors = resultGetList(self, "errors");
    const ok = c.py_list_len(failures) == 0 and c.py_list_len(errors) == 0;
    c.py_newbool(c.py_retval(), ok);
    return true;
}

// =============================================================================
// Skip decorators
// =============================================================================

fn skipDecoratorNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_skip_decorator, 2, 0);
    c.py_newbool(c.py_r0(), false);
    c.py_setslot(c.py_retval(), 0, c.py_r0()); // active
    c.py_newnone(c.py_r0());
    c.py_setslot(c.py_retval(), 1, c.py_r0()); // reason
    return true;
}

fn skipDecoratorCall(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "decorator requires a function");
    const self = pk.argRef(argv, 0);
    const func = pk.argRef(argv, 1);
    const active = c.py_getslot(self, 0);
    const reason = c.py_getslot(self, 1);
    if (!c.py_isbool(active) or !c.py_tobool(active)) {
        c.py_retval().* = func.*;
        return true;
    }
    c.py_newbool(c.py_r0(), true);
    _ = c.py_setattr(func, c.py_name("__unittest_skip__"), c.py_r0());
    _ = c.py_setattr(func, c.py_name("__unittest_skip_why__"), reason);
    c.py_retval().* = func.*;
    return true;
}

fn skipFn(ctx: *pk.Context) bool {
    const reason = ctx.arg(0) orelse return ctx.typeError("expected reason");
    _ = c.py_newobject(c.py_retval(), tp_skip_decorator, 2, 0);
    c.py_newbool(c.py_r0(), true);
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    c.py_setslot(c.py_retval(), 1, reason.refConst());
    return true;
}

fn skipIfFn(ctx: *pk.Context) bool {
    const cond = ctx.argBool(0) orelse return ctx.typeError("expected bool");
    const reason = ctx.arg(1) orelse return ctx.typeError("expected reason");
    _ = c.py_newobject(c.py_retval(), tp_skip_decorator, 2, 0);
    c.py_newbool(c.py_r0(), cond);
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    c.py_setslot(c.py_retval(), 1, reason.refConst());
    return true;
}

fn skipUnlessFn(ctx: *pk.Context) bool {
    const cond = ctx.argBool(0) orelse return ctx.typeError("expected bool");
    const reason = ctx.arg(1) orelse return ctx.typeError("expected reason");
    _ = c.py_newobject(c.py_retval(), tp_skip_decorator, 2, 0);
    c.py_newbool(c.py_r0(), !cond);
    c.py_setslot(c.py_retval(), 0, c.py_r0());
    c.py_setslot(c.py_retval(), 1, reason.refConst());
    return true;
}

fn expectedFailureFn(ctx: *pk.Context) bool {
    const func = ctx.arg(0) orelse return ctx.typeError("expected a function");
    c.py_newbool(c.py_r0(), true);
    _ = c.py_setattr(func.refConst(), c.py_name("__unittest_expected_failure__"), c.py_r0());
    return ctx.returnValue(func);
}

fn getMethodFlags(self: c.py_Ref, method_name: c.py_Ref, out_skip: *bool, out_expected_failure: *bool, out_skip_reason: *c.py_TValue) void {
    out_skip.* = false;
    out_expected_failure.* = false;
    c.py_newnone(out_skip_reason);

    // PocketPy does not expose `__class__` on all objects, so use the C API.
    const cls_ref = c.py_tpobject(c.py_typeof(self));
    const cls_tv: c.py_TValue = cls_ref.*;
    const getattr_item = c.py_getbuiltin(c.py_name("getattr"));
    if (getattr_item == null) return;
    var getattr_fn: c.py_TValue = getattr_item.?.*;

    var default_tv: c.py_TValue = undefined;
    c.py_newnone(&default_tv);
    var args_method: [3]c.py_TValue = .{ cls_tv, method_name.*, default_tv };
    if (!c.py_call(&getattr_fn, 3, @ptrCast(&args_method))) {
        c.py_clearexc(null);
        return;
    }
    var fn_tv: c.py_TValue = c.py_retval().*;
    const fn_obj = &fn_tv;

    // Use builtin getattr() to ensure we consult function.__dict__.
    var name_tv: c.py_TValue = undefined;

    c.py_newstr(&name_tv, "__unittest_skip__");
    c.py_newbool(&default_tv, false);
    var args_skip: [3]c.py_TValue = .{ fn_obj.*, name_tv, default_tv };
    if (c.py_call(&getattr_fn, 3, @ptrCast(&args_skip))) {
        const b = c.py_bool(c.py_retval());
        if (b > 0) {
            out_skip.* = true;

            c.py_newstr(&name_tv, "__unittest_skip_why__");
            c.py_newnone(&default_tv);
            var args_why: [3]c.py_TValue = .{ fn_obj.*, name_tv, default_tv };
            if (c.py_call(&getattr_fn, 3, @ptrCast(&args_why))) {
                out_skip_reason.* = c.py_retval().*;
            } else {
                c.py_clearexc(null);
            }
        }
    } else {
        c.py_clearexc(null);
    }

    c.py_newstr(&name_tv, "__unittest_expected_failure__");
    c.py_newbool(&default_tv, false);
    var args_ef: [3]c.py_TValue = .{ fn_obj.*, name_tv, default_tv };
    if (c.py_call(&getattr_fn, 3, @ptrCast(&args_ef))) {
        const b = c.py_bool(c.py_retval());
        out_expected_failure.* = b > 0;
    } else {
        c.py_clearexc(null);
    }
}

// =============================================================================
// TestCase
// =============================================================================

fn testCaseNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1) return c.py_exception(c.tp_TypeError, "TestCase.__new__ missing cls");
    const cls = pk.argRef(argv, 0);
    if (!c.py_istype(cls, c.tp_type)) return c.py_exception(c.tp_TypeError, "expected type");
    _ = c.py_newobject(c.py_retval(), c.py_totype(cls), -1, 0);
    return true;
}

fn testCaseInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    if (argc >= 2 and c.py_isstr(pk.argRef(argv, 1))) {
        c.py_setdict(self, c.py_name("_testMethodName"), pk.argRef(argv, 1));
    } else {
        c.py_newstr(c.py_r0(), "runTest");
        c.py_setdict(self, c.py_name("_testMethodName"), c.py_r0());
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn raiseAssert(msg: [:0]const u8) bool {
    return c.py_exception(c.tp_AssertionError, msg.ptr);
}

fn failFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc >= 2 and c.py_isstr(pk.argRef(argv, 1))) {
        return c.py_exception(c.tp_AssertionError, c.py_tostr(pk.argRef(argv, 1)));
    }
    return c.py_exception(c.tp_AssertionError, "fail");
}

fn assertTrueFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const expr = pk.argRef(argv, 1);
    const b = c.py_bool(expr);
    if (b < 0) return false;
    if (b == 0) return raiseAssert("assertTrue failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertFalseFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const expr = pk.argRef(argv, 1);
    const b = c.py_bool(expr);
    if (b < 0) return false;
    if (b != 0) return raiseAssert("assertFalse failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertEqualFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 1);
    const b = pk.argRef(argv, 2);
    const eq = c.py_equal(a, b);
    if (eq < 0) return false;
    if (eq == 0) return raiseAssert("assertEqual failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertNotEqualFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 1);
    const b = pk.argRef(argv, 2);
    const eq = c.py_equal(a, b);
    if (eq < 0) return false;
    if (eq != 0) return raiseAssert("assertNotEqual failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertIsFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 1);
    const b = pk.argRef(argv, 2);
    if (!isIdentical(a, b)) return raiseAssert("assertIs failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertIsNotFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 1);
    const b = pk.argRef(argv, 2);
    if (isIdentical(a, b)) return raiseAssert("assertIsNot failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertIsNoneFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 1);
    if (!c.py_isnone(a)) return raiseAssert("assertIsNone failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertIsNotNoneFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = pk.argRef(argv, 1);
    if (c.py_isnone(a)) return raiseAssert("assertIsNotNone failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertInFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const member = pk.argRef(argv, 1);
    const container = pk.argRef(argv, 2);
    if (!c.py_getattr(container, c.py_name("__contains__"))) return false;
    var contains_fn: c.py_TValue = c.py_retval().*;
    var args: [1]c.py_TValue = .{member.*};
    if (!c.py_call(&contains_fn, 1, @ptrCast(&args))) return false;
    const b = c.py_bool(c.py_retval());
    if (b < 0) return false;
    if (b == 0) return raiseAssert("assertIn failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertNotInFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const member = pk.argRef(argv, 1);
    const container = pk.argRef(argv, 2);
    if (!c.py_getattr(container, c.py_name("__contains__"))) return false;
    var contains_fn: c.py_TValue = c.py_retval().*;
    var args: [1]c.py_TValue = .{member.*};
    if (!c.py_call(&contains_fn, 1, @ptrCast(&args))) return false;
    const b = c.py_bool(c.py_retval());
    if (b < 0) return false;
    if (b != 0) return raiseAssert("assertNotIn failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertIsInstanceFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const obj = pk.argRef(argv, 1);
    const cls = pk.argRef(argv, 2);
    if (!c.py_istype(cls, c.tp_type)) return c.py_exception(c.tp_TypeError, "expected type");
    const ok = c.py_isinstance(obj, c.py_totype(cls));
    if (!ok) return raiseAssert("assertIsInstance failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertNotIsInstanceFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const obj = pk.argRef(argv, 1);
    const cls = pk.argRef(argv, 2);
    if (!c.py_istype(cls, c.tp_type)) return c.py_exception(c.tp_TypeError, "expected type");
    const ok = c.py_isinstance(obj, c.py_totype(cls));
    if (ok) return raiseAssert("assertNotIsInstance failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn num(v: c.py_Ref) ?f64 {
    if (c.py_isint(v)) return @floatFromInt(c.py_toint(v));
    if (c.py_isfloat(v)) return c.py_tofloat(v);
    return null;
}

fn assertGreaterFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = num(pk.argRef(argv, 1)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    const b = num(pk.argRef(argv, 2)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    if (!(a > b)) return raiseAssert("assertGreater failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertLessFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = num(pk.argRef(argv, 1)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    const b = num(pk.argRef(argv, 2)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    if (!(a < b)) return raiseAssert("assertLess failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertGreaterEqualFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = num(pk.argRef(argv, 1)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    const b = num(pk.argRef(argv, 2)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    if (!(a >= b)) return raiseAssert("assertGreaterEqual failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertLessEqualFn(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = num(pk.argRef(argv, 1)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    const b = num(pk.argRef(argv, 2)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    if (!(a <= b)) return raiseAssert("assertLessEqual failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn assertAlmostEqualFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const a = num(pk.argRef(argv, 1)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    const b = num(pk.argRef(argv, 2)) orelse return c.py_exception(c.tp_TypeError, "expected number");
    var places: i64 = 7;
    if (argc >= 4 and c.py_isint(pk.argRef(argv, 3))) places = c.py_toint(pk.argRef(argv, 3));
    const tol = std.math.pow(f64, 10.0, -@as(f64, @floatFromInt(places)));
    if (@abs(a - b) > tol) return raiseAssert("assertAlmostEqual failed");
    c.py_newnone(c.py_retval());
    return true;
}

fn skipTestFn(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    return c.py_exception(tp_skip_test, "skipped");
}

// assertRaises: callable form or context manager form
var tp_raises_ctx: c.py_Type = 0;

fn raisesCtxNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_raises_ctx, 2, 0);
    c.py_newnone(c.py_r0());
    c.py_setslot(c.py_retval(), 0, c.py_r0()); // exc_type (type object)
    c.py_newnone(c.py_r0());
    c.py_setslot(c.py_retval(), 1, c.py_r0()); // test case (for AssertionError)
    return true;
}

fn raisesCtxEnter(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    c.py_retval().* = pk.argRef(argv, 0).*;
    return true;
}

fn raisesCtxExit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const exc_type = c.py_getslot(self, 0);
    if (argc < 2 or c.py_isnone(pk.argRef(argv, 1))) {
        return c.py_exception(c.tp_AssertionError, "did not raise");
    }
    const exc = pk.argRef(argv, 1);
    if (!c.py_istype(exc_type, c.tp_type)) return c.py_exception(c.tp_TypeError, "expected exception type");
    if (!c.py_isinstance(exc, c.py_totype(exc_type))) {
        return c.py_exception(c.tp_AssertionError, "wrong exception type");
    }
    c.py_newbool(c.py_retval(), true);
    return true;
}

fn assertRaisesFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "assertRaises requires exception type");
    const self = pk.argRef(argv, 0);
    const exc_type = pk.argRef(argv, 1);
    if (!c.py_istype(exc_type, c.tp_type)) return c.py_exception(c.tp_TypeError, "expected exception type");

    if (argc >= 3) {
        const callable_fn = pk.argRef(argv, 2);
        if (!c.py_callable(callable_fn)) return c.py_exception(c.tp_TypeError, "expected callable");
        if (!c.py_call(callable_fn, 0, null)) {
            if (!c.py_matchexc(c.py_totype(exc_type))) {
                return false;
            }
            c.py_clearexc(null);
            c.py_newnone(c.py_retval());
            return true;
        }
        return c.py_exception(c.tp_AssertionError, "did not raise");
    }

    _ = c.py_newobject(c.py_retval(), tp_raises_ctx, 2, 0);
    c.py_setslot(c.py_retval(), 0, exc_type);
    c.py_setslot(c.py_retval(), 1, self);
    return true;
}

fn testCaseRun(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);

    var result_tv: c.py_TValue = undefined;
    var result: c.py_Ref = undefined;
    if (argc >= 2 and !c.py_isnone(pk.argRef(argv, 1))) {
        result = pk.argRef(argv, 1);
    } else {
        if (!c.py_tpcall(tp_test_result, 0, null)) return false;
        result_tv = c.py_retval().*;
        result = &result_tv;
    }

    resultIncTestsRun(result);

    const method_name_ptr = c.py_getdict(self, c.py_name("_testMethodName"));
    var method_name: c.py_Ref = undefined;
    if (method_name_ptr != null and c.py_isstr(method_name_ptr.?)) {
        method_name = method_name_ptr.?;
    } else {
        c.py_newstr(c.py_r0(), "runTest");
        method_name = c.py_r0();
    }

    var is_skip: bool = false;
    var is_expected_failure: bool = false;
    var skip_reason: c.py_TValue = undefined;
    getMethodFlags(self, method_name, &is_skip, &is_expected_failure, &skip_reason);
    if (is_skip) {
        const skipped = resultGetList(result, "skipped");
        c.py_list_append(skipped, &skip_reason);
        c.py_retval().* = result.*;
        return true;
    }

    // setUp
    if (c.py_getattr(self, c.py_name("setUp"))) {
        var setup_fn: c.py_TValue = c.py_retval().*;
        _ = c.py_call(&setup_fn, 0, null) or return false;
    } else {
        c.py_clearexc(null);
    }

    // Run test method
    if (!c.py_getattr(self, c.py_name(c.py_tostr(method_name)))) return false;
    var bound: c.py_TValue = c.py_retval().*;

    const expected_failure = is_expected_failure;

    if (!c.py_call(&bound, 0, null)) {
        if (c.py_matchexc(tp_skip_test)) {
            c.py_clearexc(null);
            const skipped = resultGetList(result, "skipped");
            c.py_newstr(c.py_r0(), "skipped");
            c.py_list_append(skipped, c.py_r0());
        } else if (expected_failure and c.py_matchexc(c.tp_AssertionError)) {
            c.py_clearexc(null);
            const ef = resultGetList(result, "expectedFailures");
            c.py_newstr(c.py_r0(), "expectedFailure");
            c.py_list_append(ef, c.py_r0());
        } else if (c.py_matchexc(c.tp_AssertionError)) {
            c.py_clearexc(null);
            const failures = resultGetList(result, "failures");
            c.py_newstr(c.py_r0(), "failure");
            c.py_list_append(failures, c.py_r0());
        } else {
            // Any other exception is an error
            const errors = resultGetList(result, "errors");
            c.py_newstr(c.py_r0(), "error");
            c.py_list_append(errors, c.py_r0());
            c.py_clearexc(null);
        }
    } else {
        if (expected_failure) {
            const us = resultGetList(result, "unexpectedSuccesses");
            c.py_newstr(c.py_r0(), "unexpectedSuccess");
            c.py_list_append(us, c.py_r0());
        }
    }

    // tearDown
    if (c.py_getattr(self, c.py_name("tearDown"))) {
        var teardown_fn: c.py_TValue = c.py_retval().*;
        _ = c.py_call(&teardown_fn, 0, null) or return false;
    } else {
        c.py_clearexc(null);
    }

    c.py_retval().* = result.*;
    return true;
}

// =============================================================================
// TestSuite
// =============================================================================

fn testSuiteNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_test_suite, -1, 0);
    return true;
}

fn testSuiteInit(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    c.py_newlist(c.py_r0());
    c.py_setdict(self, c.py_name("_tests"), c.py_r0());
    c.py_newnone(c.py_retval());
    return true;
}

fn testSuiteAddTest(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const t = pk.argRef(argv, 1);
    const tests = resultGetList(self, "_tests");
    c.py_list_append(tests, t);
    c.py_newnone(c.py_retval());
    return true;
}

fn testSuiteCount(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const tests = resultGetList(self, "_tests");
    c.py_newint(c.py_retval(), c.py_list_len(tests));
    return true;
}

fn testSuiteRun(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const result = pk.argRef(argv, 1);
    const tests = resultGetList(self, "_tests");

    const n = c.py_list_len(tests);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const test_obj = c.py_list_getitem(tests, i);
        if (!c.py_getattr(test_obj, c.py_name("run"))) return false;
        var run_fn: c.py_TValue = c.py_retval().*;
        var args: [1]c.py_TValue = .{result.*};
        _ = c.py_call(&run_fn, 1, @ptrCast(&args)) or return false;
    }
    c.py_retval().* = result.*;
    return true;
}

// =============================================================================
// TestLoader
// =============================================================================

fn testLoaderNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_test_loader, -1, 0);
    return true;
}

fn testLoaderInit(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    c.py_newnone(c.py_retval());
    return true;
}

fn testLoaderLoadTests(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "expected TestCase class");
    const test_case_cls = pk.argRef(argv, 1);

    if (!c.py_tpcall(tp_test_suite, 0, null)) return false;
    var suite_tv: c.py_TValue = c.py_retval().*;
    const suite = &suite_tv;

    const dir_item = c.py_getbuiltin(c.py_name("dir"));
    if (dir_item == null) return c.py_exception(c.tp_RuntimeError, "dir not found");
    var dir_fn: c.py_TValue = dir_item.?.*;
    var args: [1]c.py_TValue = .{test_case_cls.*};
    if (!c.py_call(&dir_fn, 1, @ptrCast(&args))) return false;
    var names_tv: c.py_TValue = c.py_retval().*;
    const names = &names_tv;
    if (!c.py_islist(names)) return c.py_exception(c.tp_RuntimeError, "dir() did not return list");

    const n = c.py_list_len(names);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const name_obj = c.py_list_getitem(names, i);
        if (!c.py_isstr(name_obj)) continue;
        const sv = c.py_tosv(name_obj);
        const bytes: []const u8 = @as([*]const u8, @ptrCast(sv.data))[0..@intCast(sv.size)];
        if (bytes.len < 4 or !std.mem.eql(u8, bytes[0..4], "test")) continue;

        // instance = TestCaseClass(name)
        var name_tv: c.py_TValue = name_obj.*;
        if (!c.py_call(test_case_cls, 1, &name_tv)) return false;
        var inst_tv: c.py_TValue = c.py_retval().*;
        const inst = &inst_tv;

        // suite.addTest(instance)
        if (!c.py_getattr(suite, c.py_name("addTest"))) return false;
        var add_fn: c.py_TValue = c.py_retval().*;
        var add_args: [1]c.py_TValue = .{inst.*};
        _ = c.py_call(&add_fn, 1, @ptrCast(&add_args)) or return false;
    }

    c.py_retval().* = suite.*;
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("unittest");

    tp_skip_test = c.py_newtype("SkipTest", c.tp_Exception, builder.module, null);

    var result_builder = pk.TypeBuilder.newSimple("TestResult", builder.module);
    tp_test_result = result_builder
        .magic("__new__", testResultNew)
        .magic("__init__", testResultInit)
        .method("wasSuccessful", testResultWasSuccessful)
        .build();

    var raises_builder = pk.TypeBuilder.newSimple("_AssertRaisesContext", builder.module);
    tp_raises_ctx = raises_builder
        .magic("__new__", raisesCtxNew)
        .method("__enter__", raisesCtxEnter)
        .magic("__exit__", raisesCtxExit)
        .build();

    var case_builder = pk.TypeBuilder.new("TestCase", c.tp_object, builder.module, null);
    tp_test_case = case_builder
        .magic("__new__", testCaseNew)
        .magic("__init__", testCaseInit)
        .method("run", testCaseRun)
        .method("fail", failFn)
        .method("assertTrue", assertTrueFn)
        .method("assertFalse", assertFalseFn)
        .method("assertEqual", assertEqualFn)
        .method("assertNotEqual", assertNotEqualFn)
        .method("assertIs", assertIsFn)
        .method("assertIsNot", assertIsNotFn)
        .method("assertIsNone", assertIsNoneFn)
        .method("assertIsNotNone", assertIsNotNoneFn)
        .method("assertIn", assertInFn)
        .method("assertNotIn", assertNotInFn)
        .method("assertIsInstance", assertIsInstanceFn)
        .method("assertNotIsInstance", assertNotIsInstanceFn)
        .method("assertGreater", assertGreaterFn)
        .method("assertLess", assertLessFn)
        .method("assertGreaterEqual", assertGreaterEqualFn)
        .method("assertLessEqual", assertLessEqualFn)
        .method("assertAlmostEqual", assertAlmostEqualFn)
        .method("assertRaises", assertRaisesFn)
        .method("skipTest", skipTestFn)
        .build();

    // Keyword arguments support for places=...
    c.py_bind(c.py_tpobject(tp_test_case), "assertAlmostEqual(self, first, second, places=7)", assertAlmostEqualFn);

    var suite_builder = pk.TypeBuilder.newSimple("TestSuite", builder.module);
    tp_test_suite = suite_builder
        .magic("__new__", testSuiteNew)
        .magic("__init__", testSuiteInit)
        .method("addTest", testSuiteAddTest)
        .method("run", testSuiteRun)
        .method("countTestCases", testSuiteCount)
        .build();

    var loader_builder = pk.TypeBuilder.newSimple("TestLoader", builder.module);
    tp_test_loader = loader_builder
        .magic("__new__", testLoaderNew)
        .magic("__init__", testLoaderInit)
        .method("loadTestsFromTestCase", testLoaderLoadTests)
        .build();

    var skip_builder = pk.TypeBuilder.newSimple("_SkipDecorator", builder.module);
    tp_skip_decorator = skip_builder
        .magic("__new__", skipDecoratorNew)
        .magic("__call__", skipDecoratorCall)
        .build();

    _ = builder
        .funcWrapped("skip", 1, 1, skipFn)
        .funcWrapped("skipIf", 2, 2, skipIfFn)
        .funcWrapped("skipUnless", 2, 2, skipUnlessFn)
        .funcWrapped("expectedFailure", 1, 1, expectedFailureFn);
}
