const std = @import("std");
const pk = @import("pk");
const c = pk.c;

// Helper to compare two Python values. Returns -1 on error, 0 if a >= b, 1 if a < b
fn pyLess(a: c.py_Ref, b: c.py_Ref) c_int {
    return c.py_less(a, b);
}

// Helper to sift down (used in heapify and heappop)
fn siftDown(list: c.py_Ref, n: c_int, pos: c_int) bool {
    var i = pos;
    while (true) {
        var smallest = i;
        const left = 2 * i + 1;
        const right = 2 * i + 2;

        if (left < n) {
            const smallest_val = c.py_list_getitem(list, smallest);
            const left_val = c.py_list_getitem(list, left);
            const cmp = pyLess(left_val, smallest_val);
            if (cmp < 0) return false; // error
            if (cmp == 1) smallest = left;
        }

        if (right < n) {
            const smallest_val = c.py_list_getitem(list, smallest);
            const right_val = c.py_list_getitem(list, right);
            const cmp = pyLess(right_val, smallest_val);
            if (cmp < 0) return false; // error
            if (cmp == 1) smallest = right;
        }

        if (smallest == i) break;

        // Swap - need to copy values since getitem returns refs
        const i_val = c.py_list_getitem(list, i);
        const smallest_val = c.py_list_getitem(list, smallest);

        // Use temporary storage
        c.py_r0().* = i_val.*;
        c.py_r1().* = smallest_val.*;
        c.py_list_setitem(list, i, c.py_r1());
        c.py_list_setitem(list, smallest, c.py_r0());

        i = smallest;
    }
    return true;
}

// Helper to sift up (used in heappush)
fn siftUp(list: c.py_Ref, pos: c_int) bool {
    var i = pos;
    while (i > 0) {
        const parent = @divFloor(i - 1, 2);
        const i_val = c.py_list_getitem(list, i);
        const parent_val = c.py_list_getitem(list, parent);

        const cmp = pyLess(i_val, parent_val);
        if (cmp < 0) return false; // error
        if (cmp == 0) break; // i >= parent, done

        // Swap
        c.py_r0().* = i_val.*;
        c.py_r1().* = parent_val.*;
        c.py_list_setitem(list, i, c.py_r1());
        c.py_list_setitem(list, parent, c.py_r0());

        i = parent;
    }
    return true;
}

fn heapifyFn(ctx: *pk.Context) bool {
    var list_arg = ctx.arg(0) orelse return ctx.typeError("expected list");
    if (!list_arg.isList()) {
        return ctx.typeError("expected list");
    }
    const list = list_arg.ref();
    const n = c.py_list_len(list);
    if (n <= 1) {
        return ctx.returnNone();
    }

    // Standard heapify: start from last parent and sift down
    var i = @divFloor(n, 2) - 1;
    while (i >= 0) : (i -= 1) {
        if (!siftDown(list, n, i)) return false;
        if (i == 0) break;
    }

    return ctx.returnNone();
}

fn heappushFn(ctx: *pk.Context) bool {
    var list_arg = ctx.arg(0) orelse return ctx.typeError("expected list");
    var item_arg = ctx.arg(1) orelse return ctx.typeError("expected item");
    if (!list_arg.isList()) {
        return ctx.typeError("expected list");
    }

    const list = list_arg.ref();
    // Append item to end
    c.py_list_append(list, item_arg.ref());

    // Sift up from the new position
    const n = c.py_list_len(list);
    if (!siftUp(list, n - 1)) return false;

    return ctx.returnNone();
}

// Static storage for return values (py_retval gets clobbered by py_less)
var saved_return: c.py_TValue = undefined;

fn heappopFn(ctx: *pk.Context) bool {
    var list_arg = ctx.arg(0) orelse return ctx.typeError("expected list");
    if (!list_arg.isList()) {
        return ctx.typeError("expected list");
    }
    const list = list_arg.ref();
    const n = c.py_list_len(list);
    if (n <= 0) {
        return ctx.indexError("pop from empty heap");
    }

    // Get the min (root) and save to static storage
    const min_val = c.py_list_getitem(list, 0);
    saved_return = min_val.*;

    if (n == 1) {
        _ = c.py_list_delitem(list, 0);
        c.py_retval().* = saved_return;
        return true;
    }

    // Move last element to root
    const last_val = c.py_list_getitem(list, n - 1);
    c.py_list_setitem(list, 0, last_val);
    _ = c.py_list_delitem(list, n - 1);

    // Sift down from root
    if (!siftDown(list, n - 1, 0)) return false;

    // Restore from static storage
    c.py_retval().* = saved_return;
    return true;
}

fn heapreplaceFn(ctx: *pk.Context) bool {
    var list_arg = ctx.arg(0) orelse return ctx.typeError("expected list");
    var item_arg = ctx.arg(1) orelse return ctx.typeError("expected item");
    if (!list_arg.isList()) {
        return ctx.typeError("expected list");
    }
    const list = list_arg.ref();
    const n = c.py_list_len(list);
    if (n <= 0) {
        return ctx.indexError("heap is empty");
    }

    // Get the old min (root) and save to static storage
    const min_val = c.py_list_getitem(list, 0);
    saved_return = min_val.*;

    // Replace root with new item
    c.py_list_setitem(list, 0, item_arg.ref());

    // Sift down from root
    if (!siftDown(list, n, 0)) return false;

    // Restore from static storage
    c.py_retval().* = saved_return;
    return true;
}

fn heappushpopFn(ctx: *pk.Context) bool {
    var list_arg = ctx.arg(0) orelse return ctx.typeError("expected list");
    var item_arg = ctx.arg(1) orelse return ctx.typeError("expected item");
    if (!list_arg.isList()) {
        return ctx.typeError("expected list");
    }
    const list = list_arg.ref();
    const n = c.py_list_len(list);

    // If heap is empty, return item immediately
    if (n == 0) {
        return ctx.returnValue(item_arg);
    }

    // Compare item with root
    const root_val = c.py_list_getitem(list, 0);
    const cmp = pyLess(item_arg.ref(), root_val);
    if (cmp < 0) return false; // error

    // If item <= root, return item (no change to heap)
    if (cmp == 1 or c.py_equal(item_arg.ref(), root_val) == 1) {
        return ctx.returnValue(item_arg);
    }

    // Otherwise, save root to static storage, replace root with item, and sift down
    saved_return = root_val.*;
    c.py_list_setitem(list, 0, item_arg.ref());
    if (!siftDown(list, n, 0)) return false;

    // Restore from static storage
    c.py_retval().* = saved_return;
    return true;
}

fn nlargestFn(ctx: *pk.Context) bool {
    const n_val = ctx.argInt(0) orelse return ctx.typeError("expected int for n");
    var iterable_arg = ctx.arg(1) orelse return ctx.typeError("expected iterable");

    if (n_val < 0) {
        return ctx.valueError("n must be non-negative");
    }
    const n: usize = @intCast(n_val);

    if (n == 0) {
        return ctx.returnList();
    }

    if (!iterable_arg.isList()) {
        return ctx.typeError("expected list");
    }

    const iterable = iterable_arg.ref();
    const len = c.py_list_len(iterable);
    if (len == 0) {
        return ctx.returnList();
    }

    // Collect indices and sort by value (descending)
    var indices: [256]c_int = undefined;
    if (len > 256) {
        return ctx.valueError("data too large");
    }

    var i: c_int = 0;
    while (i < len) : (i += 1) {
        indices[@intCast(i)] = i;
    }

    // Simple selection sort descending
    const count: usize = @intCast(len);
    for (0..count) |j| {
        var max_idx = j;
        for ((j + 1)..count) |k| {
            const val_k = c.py_list_getitem(iterable, indices[k]);
            const val_max = c.py_list_getitem(iterable, indices[max_idx]);
            const cmp = pyLess(val_max, val_k);
            if (cmp < 0) return false;
            if (cmp == 1) max_idx = k;
        }
        if (max_idx != j) {
            const tmp = indices[j];
            indices[j] = indices[max_idx];
            indices[max_idx] = tmp;
        }
    }

    // Take first n
    const result_count = @min(n, count);
    c.py_newlist(c.py_retval());
    for (0..result_count) |j| {
        const val = c.py_list_getitem(iterable, indices[j]);
        c.py_list_append(c.py_retval(), val);
    }

    return true;
}

fn nsmallestFn(ctx: *pk.Context) bool {
    const n_val = ctx.argInt(0) orelse return ctx.typeError("expected int for n");
    var iterable_arg = ctx.arg(1) orelse return ctx.typeError("expected iterable");

    if (n_val < 0) {
        return ctx.valueError("n must be non-negative");
    }
    const n: usize = @intCast(n_val);

    if (n == 0) {
        return ctx.returnList();
    }

    if (!iterable_arg.isList()) {
        return ctx.typeError("expected list");
    }

    const iterable = iterable_arg.ref();
    const len = c.py_list_len(iterable);
    if (len == 0) {
        return ctx.returnList();
    }

    // Collect indices and sort by value (ascending)
    var indices: [256]c_int = undefined;
    if (len > 256) {
        return ctx.valueError("data too large");
    }

    var i: c_int = 0;
    while (i < len) : (i += 1) {
        indices[@intCast(i)] = i;
    }

    // Simple selection sort ascending
    const count: usize = @intCast(len);
    for (0..count) |j| {
        var min_idx = j;
        for ((j + 1)..count) |k| {
            const val_k = c.py_list_getitem(iterable, indices[k]);
            const val_min = c.py_list_getitem(iterable, indices[min_idx]);
            const cmp = pyLess(val_k, val_min);
            if (cmp < 0) return false;
            if (cmp == 1) min_idx = k;
        }
        if (min_idx != j) {
            const tmp = indices[j];
            indices[j] = indices[min_idx];
            indices[min_idx] = tmp;
        }
    }

    // Take first n
    const result_count = @min(n, count);
    c.py_newlist(c.py_retval());
    for (0..result_count) |j| {
        const val = c.py_list_getitem(iterable, indices[j]);
        c.py_list_append(c.py_retval(), val);
    }

    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("heapq");
    _ = builder
        .funcWrapped("heapify", 1, 1, heapifyFn)
        .funcWrapped("heappush", 2, 2, heappushFn)
        .funcWrapped("heappop", 1, 1, heappopFn)
        .funcWrapped("heapreplace", 2, 2, heapreplaceFn)
        .funcWrapped("heappushpop", 2, 2, heappushpopFn)
        .funcWrapped("nlargest", 2, 2, nlargestFn)
        .funcWrapped("nsmallest", 2, 2, nsmallestFn);
}
