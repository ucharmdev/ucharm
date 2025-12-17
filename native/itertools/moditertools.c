/*
 * moditertools - Native itertools module for microcharm
 * 
 * Provides Python's itertools functionality:
 * - count(start, step) - infinite counter
 * - cycle(iterable) - infinite cycling
 * - repeat(elem, n) - repeat element
 * - chain(*iterables) - chain iterables
 * - islice(iterable, stop) - slice iterator
 * - takewhile(pred, iterable) - take while predicate true
 * - dropwhile(pred, iterable) - drop while predicate true
 * - accumulate(iterable, func) - cumulative sums/products
 * 
 * Usage in Python:
 *   from itertools import count, cycle, chain, islice
 *   
 *   for i in islice(count(10, 2), 5):
 *       print(i)  # 10, 12, 14, 16, 18
 */

#include "../bridge/mpy_bridge.h"

// Zig functions
extern uint64_t itertools_factorial(uint64_t n);
extern uint64_t itertools_permutations_count(uint64_t n, uint64_t r);
extern uint64_t itertools_combinations_count(uint64_t n, uint64_t r);

// ============================================================================
// count(start=0, step=1) - infinite counter
// ============================================================================

typedef struct _itertools_count_obj_t {
    mp_obj_base_t base;
    mp_obj_t current;
    mp_obj_t step;
} itertools_count_obj_t;

static mp_obj_t count_iternext(mp_obj_t self_in) {
    itertools_count_obj_t *self = MP_OBJ_TO_PTR(self_in);
    mp_obj_t result = self->current;
    self->current = mp_binary_op(MP_BINARY_OP_ADD, self->current, self->step);
    return result;
}

static mp_obj_t count_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    itertools_count_type,
    MP_QSTR_count,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, count_make_new,
    iter, count_iternext
);

static mp_obj_t count_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 0, 2, false);
    
    itertools_count_obj_t *self = mp_obj_malloc(itertools_count_obj_t, &itertools_count_type);
    self->current = (n_args >= 1) ? args[0] : mpy_new_int(0);
    self->step = (n_args >= 2) ? args[1] : mpy_new_int(1);
    
    return MP_OBJ_FROM_PTR(self);
}

// ============================================================================
// cycle(iterable) - infinite cycling
// ============================================================================

typedef struct _itertools_cycle_obj_t {
    mp_obj_base_t base;
    mp_obj_t saved;      // List of saved items
    size_t index;        // Current position in saved
    mp_obj_t iter;       // Original iterator (NULL when exhausted)
    bool exhausted;      // Whether original iterator is done
} itertools_cycle_obj_t;

static mp_obj_t cycle_iternext(mp_obj_t self_in) {
    itertools_cycle_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    if (!self->exhausted) {
        // Still consuming original iterator
        mp_obj_t item = mp_iternext(self->iter);
        if (item != MP_OBJ_STOP_ITERATION) {
            mp_obj_list_append(self->saved, item);
            return item;
        }
        self->exhausted = true;
        self->index = 0;
    }
    
    // Cycle through saved items
    size_t len = mp_obj_get_int(mp_obj_len(self->saved));
    if (len == 0) {
        return MP_OBJ_STOP_ITERATION;
    }
    
    mp_obj_t result = mp_obj_subscr(self->saved, mpy_new_int(self->index), MP_OBJ_SENTINEL);
    self->index = (self->index + 1) % len;
    return result;
}

static mp_obj_t cycle_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    itertools_cycle_type,
    MP_QSTR_cycle,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, cycle_make_new,
    iter, cycle_iternext
);

static mp_obj_t cycle_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 1, 1, false);
    
    itertools_cycle_obj_t *self = mp_obj_malloc(itertools_cycle_obj_t, &itertools_cycle_type);
    self->iter = mp_getiter(args[0], NULL);
    self->saved = mpy_new_list();
    self->index = 0;
    self->exhausted = false;
    
    return MP_OBJ_FROM_PTR(self);
}

// ============================================================================
// repeat(elem, n=None) - repeat element
// ============================================================================

typedef struct _itertools_repeat_obj_t {
    mp_obj_base_t base;
    mp_obj_t elem;
    mp_int_t remaining;  // -1 for infinite
} itertools_repeat_obj_t;

static mp_obj_t repeat_iternext(mp_obj_t self_in) {
    itertools_repeat_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    if (self->remaining == 0) {
        return MP_OBJ_STOP_ITERATION;
    }
    
    if (self->remaining > 0) {
        self->remaining--;
    }
    
    return self->elem;
}

static mp_obj_t repeat_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    itertools_repeat_type,
    MP_QSTR_repeat,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, repeat_make_new,
    iter, repeat_iternext
);

static mp_obj_t repeat_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 1, 2, false);
    
    itertools_repeat_obj_t *self = mp_obj_malloc(itertools_repeat_obj_t, &itertools_repeat_type);
    self->elem = args[0];
    self->remaining = (n_args >= 2) ? mpy_int(args[1]) : -1;
    
    return MP_OBJ_FROM_PTR(self);
}

// ============================================================================
// chain(*iterables) - chain iterables together
// ============================================================================

typedef struct _itertools_chain_obj_t {
    mp_obj_base_t base;
    mp_obj_t iterables;  // List of iterables
    size_t current_idx;  // Current iterable index
    mp_obj_t current_iter; // Current iterator
} itertools_chain_obj_t;

static mp_obj_t chain_iternext(mp_obj_t self_in) {
    itertools_chain_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    size_t len = mp_obj_get_int(mp_obj_len(self->iterables));
    
    while (self->current_idx < len) {
        if (self->current_iter == mp_const_none) {
            mp_obj_t iterable = mp_obj_subscr(self->iterables, mpy_new_int(self->current_idx), MP_OBJ_SENTINEL);
            self->current_iter = mp_getiter(iterable, NULL);
        }
        
        mp_obj_t item = mp_iternext(self->current_iter);
        if (item != MP_OBJ_STOP_ITERATION) {
            return item;
        }
        
        self->current_idx++;
        self->current_iter = mp_const_none;
    }
    
    return MP_OBJ_STOP_ITERATION;
}

static mp_obj_t chain_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    itertools_chain_type,
    MP_QSTR_chain,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, chain_make_new,
    iter, chain_iternext
);

static mp_obj_t chain_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 0, MP_OBJ_FUN_ARGS_MAX, false);
    
    itertools_chain_obj_t *self = mp_obj_malloc(itertools_chain_obj_t, &itertools_chain_type);
    self->iterables = mp_obj_new_list(n_args, (mp_obj_t *)args);
    self->current_idx = 0;
    self->current_iter = mp_const_none;
    
    return MP_OBJ_FROM_PTR(self);
}

// ============================================================================
// islice(iterable, stop) or islice(iterable, start, stop[, step])
// ============================================================================

typedef struct _itertools_islice_obj_t {
    mp_obj_base_t base;
    mp_obj_t iter;
    mp_int_t next_idx;   // Next index to yield
    mp_int_t stop;       // Stop index (-1 for None)
    mp_int_t step;       // Step size
    mp_int_t current;    // Current position in source
} itertools_islice_obj_t;

static mp_obj_t islice_iternext(mp_obj_t self_in) {
    itertools_islice_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    // Check if we've reached stop
    if (self->stop >= 0 && self->next_idx >= self->stop) {
        return MP_OBJ_STOP_ITERATION;
    }
    
    // Skip to next_idx
    while (self->current < self->next_idx) {
        mp_obj_t item = mp_iternext(self->iter);
        if (item == MP_OBJ_STOP_ITERATION) {
            return MP_OBJ_STOP_ITERATION;
        }
        self->current++;
    }
    
    // Get the item at next_idx
    mp_obj_t result = mp_iternext(self->iter);
    if (result == MP_OBJ_STOP_ITERATION) {
        return MP_OBJ_STOP_ITERATION;
    }
    
    self->current++;
    self->next_idx += self->step;
    
    return result;
}

static mp_obj_t islice_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    itertools_islice_type,
    MP_QSTR_islice,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, islice_make_new,
    iter, islice_iternext
);

static mp_obj_t islice_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 2, 4, false);
    
    itertools_islice_obj_t *self = mp_obj_malloc(itertools_islice_obj_t, &itertools_islice_type);
    self->iter = mp_getiter(args[0], NULL);
    self->current = 0;
    
    if (n_args == 2) {
        // islice(iterable, stop)
        self->next_idx = 0;
        self->stop = (args[1] == mp_const_none) ? -1 : mpy_int(args[1]);
        self->step = 1;
    } else {
        // islice(iterable, start, stop[, step])
        self->next_idx = (args[1] == mp_const_none) ? 0 : mpy_int(args[1]);
        self->stop = (args[2] == mp_const_none) ? -1 : mpy_int(args[2]);
        self->step = (n_args >= 4 && args[3] != mp_const_none) ? mpy_int(args[3]) : 1;
    }
    
    if (self->step < 1) {
        mp_raise_ValueError(MP_ERROR_TEXT("step must be positive"));
    }
    
    return MP_OBJ_FROM_PTR(self);
}

// ============================================================================
// takewhile(predicate, iterable)
// ============================================================================

typedef struct _itertools_takewhile_obj_t {
    mp_obj_base_t base;
    mp_obj_t predicate;
    mp_obj_t iter;
    bool done;
} itertools_takewhile_obj_t;

static mp_obj_t takewhile_iternext(mp_obj_t self_in) {
    itertools_takewhile_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    if (self->done) {
        return MP_OBJ_STOP_ITERATION;
    }
    
    mp_obj_t item = mp_iternext(self->iter);
    if (item == MP_OBJ_STOP_ITERATION) {
        return MP_OBJ_STOP_ITERATION;
    }
    
    // Test predicate
    mp_obj_t result = mp_call_function_1(self->predicate, item);
    if (!mp_obj_is_true(result)) {
        self->done = true;
        return MP_OBJ_STOP_ITERATION;
    }
    
    return item;
}

static mp_obj_t takewhile_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    itertools_takewhile_type,
    MP_QSTR_takewhile,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, takewhile_make_new,
    iter, takewhile_iternext
);

static mp_obj_t takewhile_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 2, 2, false);
    
    itertools_takewhile_obj_t *self = mp_obj_malloc(itertools_takewhile_obj_t, &itertools_takewhile_type);
    self->predicate = args[0];
    self->iter = mp_getiter(args[1], NULL);
    self->done = false;
    
    return MP_OBJ_FROM_PTR(self);
}

// ============================================================================
// dropwhile(predicate, iterable)
// ============================================================================

typedef struct _itertools_dropwhile_obj_t {
    mp_obj_base_t base;
    mp_obj_t predicate;
    mp_obj_t iter;
    bool dropping;
} itertools_dropwhile_obj_t;

static mp_obj_t dropwhile_iternext(mp_obj_t self_in) {
    itertools_dropwhile_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    while (true) {
        mp_obj_t item = mp_iternext(self->iter);
        if (item == MP_OBJ_STOP_ITERATION) {
            return MP_OBJ_STOP_ITERATION;
        }
        
        if (self->dropping) {
            mp_obj_t result = mp_call_function_1(self->predicate, item);
            if (!mp_obj_is_true(result)) {
                self->dropping = false;
                return item;
            }
        } else {
            return item;
        }
    }
}

static mp_obj_t dropwhile_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    itertools_dropwhile_type,
    MP_QSTR_dropwhile,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, dropwhile_make_new,
    iter, dropwhile_iternext
);

static mp_obj_t dropwhile_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 2, 2, false);
    
    itertools_dropwhile_obj_t *self = mp_obj_malloc(itertools_dropwhile_obj_t, &itertools_dropwhile_type);
    self->predicate = args[0];
    self->iter = mp_getiter(args[1], NULL);
    self->dropping = true;
    
    return MP_OBJ_FROM_PTR(self);
}

// ============================================================================
// accumulate(iterable[, func, initial])
// ============================================================================

typedef struct _itertools_accumulate_obj_t {
    mp_obj_base_t base;
    mp_obj_t iter;
    mp_obj_t func;       // None for add
    mp_obj_t total;      // Running total
    bool started;
} itertools_accumulate_obj_t;

static mp_obj_t accumulate_iternext(mp_obj_t self_in) {
    itertools_accumulate_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    mp_obj_t item = mp_iternext(self->iter);
    if (item == MP_OBJ_STOP_ITERATION) {
        return MP_OBJ_STOP_ITERATION;
    }
    
    if (!self->started) {
        self->started = true;
        if (self->total == mp_const_none) {
            self->total = item;
        } else {
            // Apply func to initial and first item
            if (self->func == mp_const_none) {
                self->total = mp_binary_op(MP_BINARY_OP_ADD, self->total, item);
            } else {
                mp_obj_t call_args[2] = {self->total, item};
                self->total = mp_call_function_n_kw(self->func, 2, 0, call_args);
            }
        }
    } else {
        if (self->func == mp_const_none) {
            self->total = mp_binary_op(MP_BINARY_OP_ADD, self->total, item);
        } else {
            mp_obj_t call_args[2] = {self->total, item};
            self->total = mp_call_function_n_kw(self->func, 2, 0, call_args);
        }
    }
    
    return self->total;
}

static mp_obj_t accumulate_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    itertools_accumulate_type,
    MP_QSTR_accumulate,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, accumulate_make_new,
    iter, accumulate_iternext
);

static mp_obj_t accumulate_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 1, 3, false);
    
    itertools_accumulate_obj_t *self = mp_obj_malloc(itertools_accumulate_obj_t, &itertools_accumulate_type);
    self->iter = mp_getiter(args[0], NULL);
    self->func = (n_args >= 2) ? args[1] : mp_const_none;
    self->total = (n_args >= 3) ? args[2] : mp_const_none;
    self->started = false;
    
    return MP_OBJ_FROM_PTR(self);
}

// ============================================================================
// starmap(function, iterable)
// ============================================================================

typedef struct _itertools_starmap_obj_t {
    mp_obj_base_t base;
    mp_obj_t func;
    mp_obj_t iter;
} itertools_starmap_obj_t;

static mp_obj_t starmap_iternext(mp_obj_t self_in) {
    itertools_starmap_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    mp_obj_t item = mp_iternext(self->iter);
    if (item == MP_OBJ_STOP_ITERATION) {
        return MP_OBJ_STOP_ITERATION;
    }
    
    // Unpack item as arguments
    size_t len;
    mp_obj_t *items;
    mp_obj_get_array(item, &len, &items);
    
    return mp_call_function_n_kw(self->func, len, 0, items);
}

static mp_obj_t starmap_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args);

MP_DEFINE_CONST_OBJ_TYPE(
    itertools_starmap_type,
    MP_QSTR_starmap,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, starmap_make_new,
    iter, starmap_iternext
);

static mp_obj_t starmap_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    (void)type;
    mp_arg_check_num(n_args, n_kw, 2, 2, false);
    
    itertools_starmap_obj_t *self = mp_obj_malloc(itertools_starmap_obj_t, &itertools_starmap_type);
    self->func = args[0];
    self->iter = mp_getiter(args[1], NULL);
    
    return MP_OBJ_FROM_PTR(self);
}

// ============================================================================
// Helper functions as module-level callables
// ============================================================================

MPY_FUNC_VAR(itertools, count, 0, 2) {
    return count_make_new(&itertools_count_type, n_args, 0, args);
}
MPY_FUNC_OBJ_VAR(itertools, count, 0, 2);

MPY_FUNC_1(itertools, cycle) {
    return cycle_make_new(&itertools_cycle_type, 1, 0, &arg0);
}
MPY_FUNC_OBJ_1(itertools, cycle);

MPY_FUNC_VAR(itertools, repeat, 1, 2) {
    return repeat_make_new(&itertools_repeat_type, n_args, 0, args);
}
MPY_FUNC_OBJ_VAR(itertools, repeat, 1, 2);

MPY_FUNC_VAR(itertools, chain, 0, MP_OBJ_FUN_ARGS_MAX) {
    return chain_make_new(&itertools_chain_type, n_args, 0, args);
}
MPY_FUNC_OBJ_VAR(itertools, chain, 0, MP_OBJ_FUN_ARGS_MAX);

MPY_FUNC_VAR(itertools, islice, 2, 4) {
    return islice_make_new(&itertools_islice_type, n_args, 0, args);
}
MPY_FUNC_OBJ_VAR(itertools, islice, 2, 4);

MPY_FUNC_2(itertools, takewhile) {
    mp_obj_t make_args[2] = {arg0, arg1};
    return takewhile_make_new(&itertools_takewhile_type, 2, 0, make_args);
}
MPY_FUNC_OBJ_2(itertools, takewhile);

MPY_FUNC_2(itertools, dropwhile) {
    mp_obj_t make_args[2] = {arg0, arg1};
    return dropwhile_make_new(&itertools_dropwhile_type, 2, 0, make_args);
}
MPY_FUNC_OBJ_2(itertools, dropwhile);

MPY_FUNC_VAR(itertools, accumulate, 1, 3) {
    return accumulate_make_new(&itertools_accumulate_type, n_args, 0, args);
}
MPY_FUNC_OBJ_VAR(itertools, accumulate, 1, 3);

MPY_FUNC_2(itertools, starmap) {
    mp_obj_t make_args[2] = {arg0, arg1};
    return starmap_make_new(&itertools_starmap_type, 2, 0, make_args);
}
MPY_FUNC_OBJ_2(itertools, starmap);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(itertools)
    // Iterator constructors
    MPY_MODULE_FUNC(itertools, count)
    MPY_MODULE_FUNC(itertools, cycle)
    MPY_MODULE_FUNC(itertools, repeat)
    MPY_MODULE_FUNC(itertools, chain)
    MPY_MODULE_FUNC(itertools, islice)
    MPY_MODULE_FUNC(itertools, takewhile)
    MPY_MODULE_FUNC(itertools, dropwhile)
    MPY_MODULE_FUNC(itertools, accumulate)
    MPY_MODULE_FUNC(itertools, starmap)
MPY_MODULE_END(itertools)
