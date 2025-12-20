const std = @import("std");
const pk = @import("pk");
const c = pk.c;

fn randrangeFn(ctx: *pk.Context) bool {
    const argc = ctx.argCount();

    var start: i64 = 0;
    var stop: i64 = undefined;
    var step: i64 = 1;

    if (argc == 1) {
        // randrange(stop)
        stop = ctx.argInt(0) orelse return ctx.typeError("expected int");
    } else if (argc == 2) {
        // randrange(start, stop)
        start = ctx.argInt(0) orelse return ctx.typeError("expected int");
        stop = ctx.argInt(1) orelse return ctx.typeError("expected int");
    } else {
        // randrange(start, stop, step)
        start = ctx.argInt(0) orelse return ctx.typeError("expected int");
        stop = ctx.argInt(1) orelse return ctx.typeError("expected int");
        step = ctx.argInt(2) orelse return ctx.typeError("expected int");
    }

    if (step == 0) {
        return ctx.valueError("zero step for randrange()");
    }

    // Calculate range
    var n: i64 = undefined;
    if (step > 0) {
        if (start >= stop) {
            return ctx.valueError("empty range for randrange()");
        }
        n = @divFloor(stop - start - 1, step) + 1;
    } else {
        if (start <= stop) {
            return ctx.valueError("empty range for randrange()");
        }
        n = @divFloor(start - stop - 1, -step) + 1;
    }

    // Generate random index using std.crypto.random
    var random_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    const rand_val = std.mem.readInt(u64, &random_bytes, .little);
    const idx: i64 = @intCast(@mod(rand_val, @as(u64, @intCast(n))));

    const result = start + idx * step;
    return ctx.returnInt(result);
}

fn sampleFn(ctx: *pk.Context) bool {
    var population_arg = ctx.arg(0) orelse return ctx.typeError("population required");
    const k = ctx.argInt(1) orelse return ctx.typeError("k must be an int");

    if (!population_arg.isList()) {
        return ctx.typeError("population must be a list");
    }

    const population = population_arg.ref();
    const pop_len = c.py_list_len(population);

    if (k < 0) {
        return ctx.valueError("sample larger than population or is negative");
    }
    if (k > pop_len) {
        return ctx.valueError("sample larger than population or is negative");
    }

    // Create result list
    c.py_newlist(c.py_retval());

    if (k == 0) {
        return true;
    }

    // Use reservoir sampling approach - collect indices
    var indices: [256]c_int = undefined;
    if (pop_len > 256) {
        return ctx.valueError("population too large");
    }

    // Initialize indices
    var i: c_int = 0;
    while (i < pop_len) : (i += 1) {
        indices[@intCast(i)] = i;
    }

    // Fisher-Yates shuffle first k elements
    var j: usize = 0;
    while (j < @as(usize, @intCast(k))) : (j += 1) {
        var random_bytes: [8]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);
        const rand_val = std.mem.readInt(u64, &random_bytes, .little);
        const swap_idx = j + @mod(rand_val, @as(usize, @intCast(pop_len)) - j);

        const tmp = indices[j];
        indices[j] = indices[swap_idx];
        indices[swap_idx] = tmp;
    }

    // Add sampled elements
    j = 0;
    while (j < @as(usize, @intCast(k))) : (j += 1) {
        const item = c.py_list_getitem(population, indices[j]);
        c.py_list_append(c.py_retval(), item);
    }

    return true;
}

fn getrandbitsFn(ctx: *pk.Context) bool {
    const k = ctx.argInt(0) orelse return ctx.typeError("k must be an int");

    if (k < 0) {
        return ctx.valueError("number of bits must be non-negative");
    }
    if (k == 0) {
        return ctx.returnInt(0);
    }
    if (k > 62) {
        return ctx.valueError("k too large (max 62)");
    }

    var random_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    const rand_val = std.mem.readInt(u64, &random_bytes, .little);

    // Mask to k bits
    const mask: u64 = (@as(u64, 1) << @intCast(k)) - 1;
    const result: i64 = @intCast(rand_val & mask);

    return ctx.returnInt(result);
}

fn choiceFn(ctx: *pk.Context) bool {
    var seq_arg = ctx.arg(0) orelse return ctx.typeError("sequence required");

    if (seq_arg.isStr()) {
        const sv = c.py_tosv(seq_arg.ref());
        const len: usize = @intCast(sv.size);
        if (len == 0) {
            return ctx.indexError("Cannot choose from an empty sequence");
        }

        var random_bytes: [8]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);
        const rand_val = std.mem.readInt(u64, &random_bytes, .little);
        const idx = @mod(rand_val, len);

        const out = c.py_newstrn(c.py_retval(), 1);
        out[0] = sv.data[idx];
        return true;
    }

    // For list/tuple, pick random element
    var n: c_int = -1;
    if (seq_arg.isList()) {
        n = c.py_list_len(seq_arg.ref());
    } else if (seq_arg.isTuple()) {
        n = c.py_tuple_len(seq_arg.ref());
    }

    if (n < 0) {
        return ctx.typeError("choice() argument must be a non-empty sequence");
    }
    if (n == 0) {
        return ctx.indexError("Cannot choose from an empty sequence");
    }

    var random_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    const rand_val = std.mem.readInt(u64, &random_bytes, .little);
    const idx: c_int = @intCast(@mod(rand_val, @as(u64, @intCast(n))));

    if (seq_arg.isList()) {
        c.py_retval().* = c.py_list_getitem(seq_arg.ref(), idx).*;
    } else {
        c.py_retval().* = c.py_tuple_getitem(seq_arg.ref(), idx).*;
    }
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.extend("random") orelse return;
    _ = builder
        .funcWrapped("randrange", 1, 3, randrangeFn)
        .funcWrapped("sample", 2, 2, sampleFn)
        .funcWrapped("getrandbits", 1, 1, getrandbitsFn)
        .funcWrapped("choice", 1, 1, choiceFn);
}
