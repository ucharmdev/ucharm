const std = @import("std");
const pk = @import("pk");
const c = pk.c;

const Count = struct {
    current: c.py_i64,
    step: c.py_i64,
};

const Cycle = struct {
    items: c.py_Ref,
    index: usize,
    length: usize,
};

const Repeat = struct {
    value: c.py_Ref,
    times: c.py_i64, // -1 = infinite
};

var tp_count: c.py_Type = 0;
var tp_cycle: c.py_Type = 0;
var tp_repeat: c.py_Type = 0;

fn countNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // Called as count.__new__(cls, start=0, step=1) - cls is first arg
    if (argc < 1 or argc > 3) {
        return c.py_exception(c.tp_TypeError, "expected 0 to 2 arguments");
    }
    _ = pk.argRef(argv, 0); // cls
    const ud = c.py_newobject(c.py_retval(), tp_count, -1, @sizeOf(Count));
    const state: *Count = @ptrCast(@alignCast(ud));
    state.current = if (argc >= 2) c.py_toint(pk.argRef(argv, 1)) else 0;
    state.step = if (argc >= 3) c.py_toint(pk.argRef(argv, 2)) else 1;
    return true;
}

fn iter(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 0 arguments");
    }
    pk.setRetval(pk.argRef(argv, 0));
    return true;
}

fn next(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "expected 0 arguments");
    }
    const self = pk.argRef(argv, 0);
    const state: *Count = @ptrCast(@alignCast(c.py_touserdata(self)));
    const value = state.current;
    state.current += state.step;
    c.py_newint(c.py_retval(), value);
    return true;
}

fn countFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // Called as count(start=0, step=1) - no cls arg
    if (argc > 2) {
        return c.py_exception(c.tp_TypeError, "count() takes at most 2 arguments");
    }
    const ud = c.py_newobject(c.py_retval(), tp_count, -1, @sizeOf(Count));
    const state: *Count = @ptrCast(@alignCast(ud));
    state.current = if (argc >= 1) c.py_toint(pk.argRef(argv, 0)) else 0;
    state.step = if (argc >= 2) c.py_toint(pk.argRef(argv, 1)) else 1;
    return true;
}

// ============== cycle ==============

fn cycleFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "cycle() requires 1 argument");
    }
    const iterable = pk.argRef(argv, 0);

    // Convert to list
    c.py_newlist(c.py_r0());
    if (c.py_islist(iterable)) {
        const len = c.py_list_len(iterable);
        var i: c_int = 0;
        while (i < len) : (i += 1) {
            c.py_list_append(c.py_r0(), c.py_list_getitem(iterable, i));
        }
    } else if (c.py_isstr(iterable)) {
        const sv = c.py_tosv(iterable);
        const s = sv.data[0..@intCast(sv.size)];
        for (s) |ch| {
            _ = c.py_newstrn(c.py_r1(), 1);
            const out_ptr = @as([*]u8, @ptrCast(@constCast(c.py_tostr(c.py_r1()))));
            out_ptr[0] = ch;
            c.py_list_append(c.py_r0(), c.py_r1());
        }
    } else {
        return c.py_exception(c.tp_TypeError, "cycle() argument must be list or string");
    }

    const len: usize = @intCast(c.py_list_len(c.py_r0()));
    const ud = c.py_newobject(c.py_retval(), tp_cycle, 1, @sizeOf(Cycle));
    const state: *Cycle = @ptrCast(@alignCast(ud));
    state.items = c.py_getslot(c.py_retval(), 0);
    state.items.* = c.py_r0().*;
    state.index = 0;
    state.length = len;
    return true;
}

fn cycleIter(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "expected 0 arguments");
    pk.setRetval(pk.argRef(argv, 0));
    return true;
}

fn cycleNext(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "expected 0 arguments");
    const self = pk.argRef(argv, 0);
    const state: *Cycle = @ptrCast(@alignCast(c.py_touserdata(self)));

    if (state.length == 0) {
        return c.py_exception(c.tp_StopIteration, "");
    }

    const item = c.py_list_getitem(state.items, @intCast(state.index));
    pk.setRetval(item);
    state.index = (state.index + 1) % state.length;
    return true;
}

// ============== repeat ==============

fn repeatFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 1 or argc > 2) {
        return c.py_exception(c.tp_TypeError, "repeat() requires 1 or 2 arguments");
    }
    const value = pk.argRef(argv, 0);
    var times: c.py_i64 = -1;
    if (argc == 2) {
        const times_val = pk.argRef(argv, 1);
        if (!c.py_isnone(times_val)) {
            var tmp: i64 = 0;
            if (!c.py_castint(times_val, &tmp)) return false;
            times = @intCast(tmp);
            if (times < 0) times = 0;
        }
    }

    const ud = c.py_newobject(c.py_retval(), tp_repeat, 1, @sizeOf(Repeat));
    const state: *Repeat = @ptrCast(@alignCast(ud));
    state.value = c.py_getslot(c.py_retval(), 0);
    state.value.* = value.*;
    state.times = times;
    return true;
}

fn repeatIter(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "expected 0 arguments");
    pk.setRetval(pk.argRef(argv, 0));
    return true;
}

fn repeatNext(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "expected 0 arguments");
    const self = pk.argRef(argv, 0);
    const state: *Repeat = @ptrCast(@alignCast(c.py_touserdata(self)));

    if (state.times == 0) {
        return c.py_exception(c.tp_StopIteration, "");
    }

    pk.setRetval(state.value);
    if (state.times > 0) {
        state.times -= 1;
    }
    return true;
}

// ============== chain ==============

fn appendIterable(out: c.py_Ref, iterable: c.py_Ref) bool {
    if (c.py_islist(iterable)) {
        const len = c.py_list_len(iterable);
        var j: c_int = 0;
        while (j < len) : (j += 1) {
            c.py_list_append(out, c.py_list_getitem(iterable, j));
        }
        return true;
    } else if (c.py_istuple(iterable)) {
        const len = c.py_tuple_len(iterable);
        var j: c_int = 0;
        while (j < len) : (j += 1) {
            c.py_list_append(out, c.py_tuple_getitem(iterable, j));
        }
        return true;
    } else if (c.py_isstr(iterable)) {
        const sv = c.py_tosv(iterable);
        const s = sv.data[0..@intCast(sv.size)];
        for (s) |ch| {
            _ = c.py_newstrn(c.py_r0(), 1);
            const ptr = @as([*]u8, @ptrCast(@constCast(c.py_tostr(c.py_r0()))));
            ptr[0] = ch;
            c.py_list_append(out, c.py_r0());
        }
        return true;
    }
    return false;
}

fn chainFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // Chain returns a list for simplicity (not lazy)
    c.py_newlist(c.py_retval());
    const out = c.py_retval();

    // With *iterables signature, all args are packed into first argument as tuple
    if (argc == 1) {
        const iterables = pk.argRef(argv, 0);
        if (c.py_istuple(iterables)) {
            const len = c.py_tuple_len(iterables);
            var i: c_int = 0;
            while (i < len) : (i += 1) {
                const iterable = c.py_tuple_getitem(iterables, i);
                if (!appendIterable(out, iterable)) {
                    return c.py_exception(c.tp_TypeError, "chain() arguments must be iterable");
                }
            }
            return true;
        } else if (appendIterable(out, iterables)) {
            return true;
        }
    }

    // Fallback: iterate directly over args
    var i: usize = 0;
    while (i < @as(usize, @intCast(argc))) : (i += 1) {
        const iterable = pk.argRef(argv, i);
        if (!appendIterable(out, iterable)) {
            return c.py_exception(c.tp_TypeError, "chain() arguments must be iterable");
        }
    }
    return true;
}

// ============== takewhile ==============

fn takewhileFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "takewhile() requires 2 arguments");
    }
    const pred = pk.argRef(argv, 0);
    const iterable = pk.argRef(argv, 1);

    // Create output list in r0 to preserve it across predicate calls
    c.py_newlist(c.py_r0());

    if (c.py_islist(iterable)) {
        const len = c.py_list_len(iterable);
        var i: c_int = 0;
        while (i < len) : (i += 1) {
            const item = c.py_list_getitem(iterable, i);
            // Call predicate
            const tmp = c.py_pushtmp();
            tmp.* = item.*;
            if (!c.py_call(pred, 1, tmp)) {
                c.py_pop();
                return false;
            }
            c.py_pop();
            if (!c.py_tobool(c.py_retval())) {
                break;
            }
            c.py_list_append(c.py_r0(), item);
        }
    } else {
        return c.py_exception(c.tp_TypeError, "takewhile() iterable must be a list");
    }
    c.py_retval().* = c.py_r0().*;
    return true;
}

// ============== dropwhile ==============

fn dropwhileFn(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "dropwhile() requires 2 arguments");
    }
    const pred = pk.argRef(argv, 0);
    const iterable = pk.argRef(argv, 1);

    // Create output list in r0 to preserve it across predicate calls
    c.py_newlist(c.py_r0());

    if (c.py_islist(iterable)) {
        const len = c.py_list_len(iterable);
        var i: c_int = 0;
        var dropping = true;
        while (i < len) : (i += 1) {
            const item = c.py_list_getitem(iterable, i);
            if (dropping) {
                // Call predicate
                const tmp = c.py_pushtmp();
                tmp.* = item.*;
                if (!c.py_call(pred, 1, tmp)) {
                    c.py_pop();
                    return false;
                }
                c.py_pop();
                if (!c.py_tobool(c.py_retval())) {
                    dropping = false;
                    c.py_list_append(c.py_r0(), item);
                }
            } else {
                c.py_list_append(c.py_r0(), item);
            }
        }
    } else {
        return c.py_exception(c.tp_TypeError, "dropwhile() iterable must be a list");
    }
    c.py_retval().* = c.py_r0().*;
    return true;
}

fn islice(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    // Signature is islice(iterable, *args) so argc=2: iterable + tuple of args
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "islice() requires iterable and stop/start/stop/step args");
    }
    const iterable = pk.argRef(argv, 0);
    const args_tuple = pk.argRef(argv, 1);

    var start: c.py_i64 = 0;
    var stop: c.py_i64 = 0;
    var step: c.py_i64 = 1;

    if (!c.py_istuple(args_tuple)) {
        return c.py_exception(c.tp_TypeError, "islice() args must be tuple");
    }

    const nargs = c.py_tuple_len(args_tuple);
    if (nargs == 1) {
        // islice(iterable, stop)
        stop = c.py_toint(c.py_tuple_getitem(args_tuple, 0));
    } else if (nargs == 2) {
        // islice(iterable, start, stop)
        start = c.py_toint(c.py_tuple_getitem(args_tuple, 0));
        stop = c.py_toint(c.py_tuple_getitem(args_tuple, 1));
    } else if (nargs == 3) {
        // islice(iterable, start, stop, step)
        start = c.py_toint(c.py_tuple_getitem(args_tuple, 0));
        stop = c.py_toint(c.py_tuple_getitem(args_tuple, 1));
        step = c.py_toint(c.py_tuple_getitem(args_tuple, 2));
    } else {
        return c.py_exception(c.tp_TypeError, "islice() requires 1 to 3 positional args after iterable");
    }

    if (step < 1) {
        return c.py_exception(c.tp_ValueError, "step must be >= 1");
    }

    c.py_newlist(c.py_retval());
    const out = c.py_retval();

    // Handle count iterator specially
    if (c.py_isinstance(iterable, tp_count)) {
        const state: *Count = @ptrCast(@alignCast(c.py_touserdata(iterable)));
        var idx: c.py_i64 = 0;
        while (idx < stop) : (idx += 1) {
            if (idx >= start and @mod(idx - start, step) == 0) {
                c.py_newint(c.py_r0(), state.current);
                c.py_list_append(out, c.py_r0());
            }
            state.current += state.step;
        }
        return true;
    }

    // Handle cycle iterator
    if (c.py_isinstance(iterable, tp_cycle)) {
        const state: *Cycle = @ptrCast(@alignCast(c.py_touserdata(iterable)));
        var idx: c.py_i64 = 0;
        while (idx < stop) : (idx += 1) {
            if (idx >= start and @mod(idx - start, step) == 0) {
                const item = c.py_list_getitem(state.items, @intCast(state.index));
                c.py_list_append(out, item);
            }
            state.index = (state.index + 1) % state.length;
        }
        return true;
    }

    // Handle list
    if (c.py_islist(iterable)) {
        const len = c.py_list_len(iterable);
        var idx: c.py_i64 = 0;
        var src_idx: c_int = 0;
        while (idx < stop and src_idx < len) : ({
            idx += 1;
            src_idx += 1;
        }) {
            if (idx >= start and @mod(idx - start, step) == 0) {
                c.py_list_append(out, c.py_list_getitem(iterable, src_idx));
            }
        }
        return true;
    }

    // Handle range by calling list() on it first
    // For now just try iterating with __iter__ and __next__
    return c.py_exception(c.tp_TypeError, "islice() iterable must be list, count, or cycle");
}

pub fn register() void {
    const name: [:0]const u8 = "itertools";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);

    // count type
    tp_count = c.py_newtype("count", c.tp_object, module, null);
    c.py_bind(c.py_tpobject(tp_count), "__new__(cls, start=0, step=1)", countNew);
    c.py_bindmethod(tp_count, "__iter__", iter);
    c.py_bindmethod(tp_count, "__next__", next);

    // cycle type
    tp_cycle = c.py_newtype("cycle", c.tp_object, module, null);
    c.py_bindmethod(tp_cycle, "__iter__", cycleIter);
    c.py_bindmethod(tp_cycle, "__next__", cycleNext);

    // repeat type
    tp_repeat = c.py_newtype("repeat", c.tp_object, module, null);
    c.py_bindmethod(tp_repeat, "__iter__", repeatIter);
    c.py_bindmethod(tp_repeat, "__next__", repeatNext);

    // Module functions
    c.py_bind(module, "count(start=0, step=1)", countFn);
    c.py_bind(module, "cycle(iterable)", cycleFn);
    c.py_bind(module, "repeat(object, times=None)", repeatFn);
    c.py_bind(module, "chain(*iterables)", chainFn);
    c.py_bind(module, "islice(iterable, *args)", islice);
    c.py_bind(module, "takewhile(predicate, iterable)", takewhileFn);
    c.py_bind(module, "dropwhile(predicate, iterable)", dropwhileFn);
}
