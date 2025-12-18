/*
 * modrandom - Native random module for ucharm
 *
 * Provides random number generation functions including shuffle and sample.
 * This module replaces MicroPython's built-in random module to add missing
 * functions (shuffle, sample) while maintaining API compatibility.
 *
 * Usage in Python:
 *   import random
 *   random.shuffle(mylist)
 *   sample = random.sample(mylist, 3)
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>
#include <stdlib.h>

// ============================================================================
// Zig Function Declarations
// ============================================================================

ZIG_EXTERN void random_seed(uint64_t seed);
ZIG_EXTERN double random_random(void);
ZIG_EXTERN int64_t random_randint(int64_t a, int64_t b);
ZIG_EXTERN int64_t random_randrange(int64_t n);
ZIG_EXTERN uint64_t random_getrandbits(uint32_t k);
ZIG_EXTERN double random_uniform(double a, double b);
ZIG_EXTERN void random_shuffle_indices(size_t *indices, size_t len);
ZIG_EXTERN void random_sample_indices(size_t *indices, size_t k, size_t n);

// ============================================================================
// MicroPython Wrappers
// ============================================================================

// random.seed(n) -> None
MPY_FUNC_VAR(random, seed, 0, 1) {
    uint64_t seed_val = 0;
    if (n_args > 0) {
        seed_val = (uint64_t)mpy_int(args[0]);
    }
    random_seed(seed_val);
    return mp_const_none;
}
MPY_FUNC_OBJ_VAR(random, seed, 0, 1);

// random.random() -> float
MPY_FUNC_0(random, random) {
    return mpy_new_float(random_random());
}
MPY_FUNC_OBJ_0(random, random);

// random.randint(a, b) -> int
MPY_FUNC_2(random, randint) {
    int64_t a = mpy_int(arg0);
    int64_t b = mpy_int(arg1);
    return mpy_new_int64(random_randint(a, b));
}
MPY_FUNC_OBJ_2(random, randint);

// random.randrange(stop) or random.randrange(start, stop[, step])
MPY_FUNC_VAR(random, randrange, 1, 3) {
    int64_t start, stop, step;
    
    if (n_args == 1) {
        start = 0;
        stop = mpy_int(args[0]);
        step = 1;
    } else if (n_args == 2) {
        start = mpy_int(args[0]);
        stop = mpy_int(args[1]);
        step = 1;
    } else {
        start = mpy_int(args[0]);
        stop = mpy_int(args[1]);
        step = mpy_int(args[2]);
        if (step == 0) {
            mp_raise_ValueError(MP_ERROR_TEXT("zero step"));
        }
    }
    
    int64_t range_size;
    if (step > 0) {
        range_size = (stop - start + step - 1) / step;
    } else {
        range_size = (start - stop - step - 1) / (-step);
    }
    
    if (range_size <= 0) {
        mp_raise_ValueError(MP_ERROR_TEXT("empty range"));
    }
    
    int64_t result = start + random_randrange(range_size) * step;
    return mpy_new_int64(result);
}
MPY_FUNC_OBJ_VAR(random, randrange, 1, 3);

// random.getrandbits(k) -> int
MPY_FUNC_1(random, getrandbits) {
    uint32_t k = (uint32_t)mpy_int(arg0);
    return mpy_new_int64((int64_t)random_getrandbits(k));
}
MPY_FUNC_OBJ_1(random, getrandbits);

// random.uniform(a, b) -> float
MPY_FUNC_2(random, uniform) {
    double a = mp_obj_get_float(arg0);
    double b = mp_obj_get_float(arg1);
    return mpy_new_float(random_uniform(a, b));
}
MPY_FUNC_OBJ_2(random, uniform);

// random.choice(seq) -> element
MPY_FUNC_1(random, choice) {
    // Handle strings specially
    if (mp_obj_is_str(arg0)) {
        size_t str_len;
        const char *str = mp_obj_str_get_data(arg0, &str_len);
        if (str_len == 0) {
            mp_raise_ValueError(MP_ERROR_TEXT("empty sequence"));
        }
        size_t idx = (size_t)random_randrange((int64_t)str_len);
        return mp_obj_new_str(&str[idx], 1);
    }
    
    // Handle lists/tuples
    size_t len;
    mp_obj_t *items;
    mp_obj_get_array(arg0, &len, &items);
    
    if (len == 0) {
        mp_raise_ValueError(MP_ERROR_TEXT("empty sequence"));
    }
    
    size_t idx = (size_t)random_randrange((int64_t)len);
    return items[idx];
}
MPY_FUNC_OBJ_1(random, choice);

// random.shuffle(x) -> None (shuffles list in place)
MPY_FUNC_1(random, shuffle) {
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(arg0, &len, &items);  // Must be a list
    
    if (len <= 1) {
        return mp_const_none;
    }
    
    // Create index array
    size_t *indices = m_new(size_t, len);
    for (size_t i = 0; i < len; i++) {
        indices[i] = i;
    }
    
    // Shuffle indices
    random_shuffle_indices(indices, len);
    
    // Create temp array for items
    mp_obj_t *temp = m_new(mp_obj_t, len);
    for (size_t i = 0; i < len; i++) {
        temp[i] = items[indices[i]];
    }
    
    // Copy back to original list
    for (size_t i = 0; i < len; i++) {
        items[i] = temp[i];
    }
    
    m_del(mp_obj_t, temp, len);
    m_del(size_t, indices, len);
    
    return mp_const_none;
}
MPY_FUNC_OBJ_1(random, shuffle);

// random.sample(population, k) -> list
MPY_FUNC_2(random, sample) {
    size_t len;
    mp_obj_t *items;
    mp_obj_get_array(arg0, &len, &items);
    
    size_t k = (size_t)mpy_int(arg1);
    
    if (k > len) {
        mp_raise_ValueError(MP_ERROR_TEXT("sample larger than population"));
    }
    
    if (k == 0) {
        return mp_obj_new_list(0, NULL);
    }
    
    // Get random indices
    size_t *indices = m_new(size_t, k);
    random_sample_indices(indices, k, len);
    
    // Build result list
    mp_obj_t result = mp_obj_new_list(k, NULL);
    for (size_t i = 0; i < k; i++) {
        mp_obj_list_store(result, MP_OBJ_NEW_SMALL_INT(i), items[indices[i]]);
    }
    
    m_del(size_t, indices, k);
    
    return result;
}
MPY_FUNC_OBJ_2(random, sample);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(random)
    MPY_MODULE_FUNC(random, seed)
    MPY_MODULE_FUNC(random, random)
    MPY_MODULE_FUNC(random, randint)
    MPY_MODULE_FUNC(random, randrange)
    MPY_MODULE_FUNC(random, getrandbits)
    MPY_MODULE_FUNC(random, uniform)
    MPY_MODULE_FUNC(random, choice)
    MPY_MODULE_FUNC(random, shuffle)
    MPY_MODULE_FUNC(random, sample)
MPY_MODULE_END(random)
