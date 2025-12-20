const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn seqLen(seq: c.py_Ref) c_int {
    if (c.py_islist(seq)) return c.py_list_len(seq);
    if (c.py_istuple(seq)) return c.py_tuple_len(seq);
    return -1;
}

fn seqItem(seq: c.py_Ref, idx: c_int) c.py_Ref {
    if (c.py_islist(seq)) return c.py_list_getitem(seq, idx);
    return c.py_tuple_getitem(seq, idx);
}

fn getFloatValue(item: c.py_Ref) ?c.py_f64 {
    var val: c.py_f64 = 0.0;
    if (c.py_castfloat(item, &val)) return val;
    return null;
}

fn meanFn(ctx: *pk.Context) bool {
    var seq_arg = ctx.arg(0) orelse return ctx.typeError("expected data");
    const seq = seq_arg.ref();
    const n = seqLen(seq);
    if (n <= 0) {
        return ctx.typeError("mean requires at least one data point");
    }
    var sum: c.py_f64 = 0.0;
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const item = seqItem(seq, i);
        var val: c.py_f64 = 0.0;
        if (!c.py_castfloat(item, &val)) return false;
        sum += val;
    }
    return ctx.returnFloat(sum / @as(c.py_f64, @floatFromInt(n)));
}

fn medianFn(ctx: *pk.Context) bool {
    var seq_arg = ctx.arg(0) orelse return ctx.typeError("expected data");
    const seq = seq_arg.ref();
    const n: usize = @intCast(seqLen(seq));
    if (n == 0) {
        return ctx.typeError("median requires at least one data point");
    }

    // Copy values to array and sort
    var values: [256]c.py_f64 = undefined;
    if (n > 256) {
        return ctx.valueError("data too large");
    }

    var i: usize = 0;
    while (i < n) : (i += 1) {
        const item = seqItem(seq, @intCast(i));
        values[i] = getFloatValue(item) orelse return ctx.typeError("data must be numeric");
    }

    // Simple bubble sort for small arrays
    var j: usize = 0;
    while (j < n) : (j += 1) {
        var k: usize = 0;
        while (k < n - 1 - j) : (k += 1) {
            if (values[k] > values[k + 1]) {
                const tmp = values[k];
                values[k] = values[k + 1];
                values[k + 1] = tmp;
            }
        }
    }

    if (n % 2 == 1) {
        return ctx.returnFloat(values[n / 2]);
    } else {
        return ctx.returnFloat((values[n / 2 - 1] + values[n / 2]) / 2.0);
    }
}

fn getSortedValues(seq: c.py_Ref, values: []c.py_f64) ?usize {
    const n: usize = @intCast(seqLen(seq));
    if (n == 0 or n > values.len) return null;

    var i: usize = 0;
    while (i < n) : (i += 1) {
        const item = seqItem(seq, @intCast(i));
        values[i] = getFloatValue(item) orelse return null;
    }

    // Simple bubble sort
    var j: usize = 0;
    while (j < n) : (j += 1) {
        var k: usize = 0;
        while (k < n - 1 - j) : (k += 1) {
            if (values[k] > values[k + 1]) {
                const tmp = values[k];
                values[k] = values[k + 1];
                values[k + 1] = tmp;
            }
        }
    }
    return n;
}

fn medianLowFn(ctx: *pk.Context) bool {
    var seq_arg = ctx.arg(0) orelse return ctx.typeError("expected data");
    const seq = seq_arg.ref();
    var values: [256]c.py_f64 = undefined;
    const n = getSortedValues(seq, &values) orelse {
        return ctx.typeError("median_low requires numeric data");
    };
    if (n == 0) {
        return ctx.typeError("median_low requires at least one data point");
    }

    // median_low returns the lower of the two middle values for even n
    if (n % 2 == 1) {
        return ctx.returnFloat(values[n / 2]);
    } else {
        return ctx.returnFloat(values[n / 2 - 1]);
    }
}

fn medianHighFn(ctx: *pk.Context) bool {
    var seq_arg = ctx.arg(0) orelse return ctx.typeError("expected data");
    const seq = seq_arg.ref();
    var values: [256]c.py_f64 = undefined;
    const n = getSortedValues(seq, &values) orelse {
        return ctx.typeError("median_high requires numeric data");
    };
    if (n == 0) {
        return ctx.typeError("median_high requires at least one data point");
    }

    // median_high returns the higher of the two middle values for even n
    return ctx.returnFloat(values[n / 2]);
}

fn modeFn(ctx: *pk.Context) bool {
    var seq_arg = ctx.arg(0) orelse return ctx.typeError("expected data");
    const seq = seq_arg.ref();
    const n: usize = @intCast(seqLen(seq));
    if (n == 0) {
        return ctx.typeError("mode requires at least one data point");
    }

    // Simple mode: find most common value by counting
    // Store py_TValue references and counts
    var values: [256]c.py_TValue = undefined;
    var counts: [256]usize = undefined;
    var unique: usize = 0;

    var i: usize = 0;
    while (i < n) : (i += 1) {
        const item = seqItem(seq, @intCast(i));

        // Find if value exists using py_equal
        var found = false;
        var j: usize = 0;
        while (j < unique) : (j += 1) {
            const eq_result = c.py_equal(&values[j], item);
            if (eq_result < 0) return false; // Exception raised
            if (eq_result == 1) {
                counts[j] += 1;
                found = true;
                break;
            }
        }
        if (!found) {
            if (unique >= 256) return ctx.valueError("too many unique values");
            values[unique] = item.*;
            counts[unique] = 1;
            unique += 1;
        }
    }

    // Find max count
    var max_count: usize = 0;
    var mode_idx: usize = 0;
    i = 0;
    while (i < unique) : (i += 1) {
        if (counts[i] > max_count) {
            max_count = counts[i];
            mode_idx = i;
        }
    }

    c.py_retval().* = values[mode_idx];
    return true;
}

fn varianceFn(ctx: *pk.Context) bool {
    var seq_arg = ctx.arg(0) orelse return ctx.typeError("expected data");
    const seq = seq_arg.ref();
    const n: usize = @intCast(seqLen(seq));
    if (n < 2) {
        return ctx.typeError("variance requires at least two data points");
    }

    // Calculate mean
    var sum: c.py_f64 = 0.0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const item = seqItem(seq, @intCast(i));
        sum += getFloatValue(item) orelse return ctx.typeError("data must be numeric");
    }
    const mean = sum / @as(c.py_f64, @floatFromInt(n));

    // Calculate sum of squared differences
    var sq_sum: c.py_f64 = 0.0;
    i = 0;
    while (i < n) : (i += 1) {
        const item = seqItem(seq, @intCast(i));
        const val = getFloatValue(item).?;
        const diff = val - mean;
        sq_sum += diff * diff;
    }

    // Sample variance (n-1)
    return ctx.returnFloat(sq_sum / @as(c.py_f64, @floatFromInt(n - 1)));
}

fn pvarianceFn(ctx: *pk.Context) bool {
    var seq_arg = ctx.arg(0) orelse return ctx.typeError("expected data");
    const seq = seq_arg.ref();
    const n: usize = @intCast(seqLen(seq));
    if (n < 1) {
        return ctx.typeError("pvariance requires at least one data point");
    }

    // Calculate mean
    var sum: c.py_f64 = 0.0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const item = seqItem(seq, @intCast(i));
        sum += getFloatValue(item) orelse return ctx.typeError("data must be numeric");
    }
    const mean = sum / @as(c.py_f64, @floatFromInt(n));

    // Calculate sum of squared differences
    var sq_sum: c.py_f64 = 0.0;
    i = 0;
    while (i < n) : (i += 1) {
        const item = seqItem(seq, @intCast(i));
        const val = getFloatValue(item).?;
        const diff = val - mean;
        sq_sum += diff * diff;
    }

    // Population variance (n)
    return ctx.returnFloat(sq_sum / @as(c.py_f64, @floatFromInt(n)));
}

fn stdevFn(ctx: *pk.Context) bool {
    if (!varianceFn(ctx)) return false;
    var variance: c.py_f64 = 0;
    if (!c.py_castfloat(c.py_retval(), &variance)) return false;
    return ctx.returnFloat(@sqrt(variance));
}

fn pstdevFn(ctx: *pk.Context) bool {
    if (!pvarianceFn(ctx)) return false;
    var variance: c.py_f64 = 0;
    if (!c.py_castfloat(c.py_retval(), &variance)) return false;
    return ctx.returnFloat(@sqrt(variance));
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("statistics");
    _ = builder
        .funcWrapped("mean", 1, 1, meanFn)
        .funcWrapped("median", 1, 1, medianFn)
        .funcWrapped("median_low", 1, 1, medianLowFn)
        .funcWrapped("median_high", 1, 1, medianHighFn)
        .funcWrapped("mode", 1, 1, modeFn)
        .funcWrapped("variance", 1, 1, varianceFn)
        .funcWrapped("pvariance", 1, 1, pvarianceFn)
        .funcWrapped("stdev", 1, 1, stdevFn)
        .funcWrapped("pstdev", 1, 1, pstdevFn);
}
