const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn sinhFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    return ctx.returnFloat(std.math.sinh(x));
}

fn coshFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    return ctx.returnFloat(std.math.cosh(x));
}

fn tanhFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    return ctx.returnFloat(std.math.tanh(x));
}

fn asinhFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    return ctx.returnFloat(std.math.asinh(x));
}

fn acoshFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    if (x < 1.0) {
        return ctx.valueError("math domain error");
    }
    return ctx.returnFloat(std.math.acosh(x));
}

fn atanhFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    if (x <= -1.0 or x >= 1.0) {
        return ctx.valueError("math domain error");
    }
    return ctx.returnFloat(std.math.atanh(x));
}

fn frexpFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    const result = std.math.frexp(x);
    const p = c.py_newtuple(c.py_retval(), 2);
    c.py_newfloat(&p[0], result.significand);
    c.py_newint(&p[1], result.exponent);
    return true;
}

fn ldexpFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    const i = ctx.argInt(1) orelse return ctx.typeError("expected int");
    return ctx.returnFloat(std.math.ldexp(x, @intCast(i)));
}

fn expm1Fn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    return ctx.returnFloat(std.math.expm1(x));
}

fn log1pFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    if (x <= -1.0) {
        return ctx.valueError("math domain error");
    }
    return ctx.returnFloat(std.math.log1p(x));
}

fn hypotFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    const y = ctx.argFloat(1) orelse return ctx.typeError("expected number");
    return ctx.returnFloat(std.math.hypot(x, y));
}

fn cbrtFn(ctx: *pk.Context) bool {
    const x = ctx.argFloat(0) orelse return ctx.typeError("expected number");
    return ctx.returnFloat(std.math.cbrt(x));
}

pub fn register() void {
    var builder = pk.ModuleBuilder.extend("math") orelse return;

    // Add tau constant (2 * pi)
    _ = builder.constFloat("tau", 2.0 * std.math.pi);

    _ = builder
        .funcWrapped("sinh", 1, 1, sinhFn)
        .funcWrapped("cosh", 1, 1, coshFn)
        .funcWrapped("tanh", 1, 1, tanhFn)
        .funcWrapped("asinh", 1, 1, asinhFn)
        .funcWrapped("acosh", 1, 1, acoshFn)
        .funcWrapped("atanh", 1, 1, atanhFn)
        .funcWrapped("frexp", 1, 1, frexpFn)
        .funcWrapped("ldexp", 2, 2, ldexpFn)
        .funcWrapped("expm1", 1, 1, expm1Fn)
        .funcWrapped("log1p", 1, 1, log1pFn)
        .funcWrapped("hypot", 2, 2, hypotFn)
        .funcWrapped("cbrt", 1, 1, cbrtFn);
}
