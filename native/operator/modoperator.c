/*
 * modoperator - Native operator module for ucharm
 * 
 * Provides Python's operator module functionality:
 * - Arithmetic operators: add, sub, mul, truediv, floordiv, mod, pow, neg, pos, abs
 * - Comparison operators: lt, le, eq, ne, ge, gt
 * - Logical operators: not_, and_, or_, xor
 * - Bitwise operators: lshift, rshift, invert
 * - Sequence operators: concat, contains, countOf, indexOf, getitem, setitem, delitem
 * - Attribute access: attrgetter, itemgetter, methodcaller
 * - Misc: truth, is_, is_not, length_hint, index
 * 
 * Usage in Python:
 *   from operator import add, mul, itemgetter
 *   
 *   result = add(1, 2)  # 3
 *   result = mul(3, 4)  # 12
 *   
 *   getter = itemgetter(0, 2)
 *   getter([1, 2, 3, 4])  # (1, 3)
 */

#include "../bridge/mpy_bridge.h"

// ============================================================================
// Arithmetic Operators
// ============================================================================

// operator.add(a, b)
MPY_FUNC_2(operator, add) {
    return mp_binary_op(MP_BINARY_OP_ADD, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, add);

// operator.sub(a, b)
MPY_FUNC_2(operator, sub) {
    return mp_binary_op(MP_BINARY_OP_SUBTRACT, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, sub);

// operator.mul(a, b)
MPY_FUNC_2(operator, mul) {
    return mp_binary_op(MP_BINARY_OP_MULTIPLY, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, mul);

// operator.truediv(a, b)
MPY_FUNC_2(operator, truediv) {
    return mp_binary_op(MP_BINARY_OP_TRUE_DIVIDE, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, truediv);

// operator.floordiv(a, b)
MPY_FUNC_2(operator, floordiv) {
    return mp_binary_op(MP_BINARY_OP_FLOOR_DIVIDE, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, floordiv);

// operator.mod(a, b)
MPY_FUNC_2(operator, mod) {
    return mp_binary_op(MP_BINARY_OP_MODULO, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, mod);

// operator.pow(a, b)
MPY_FUNC_2(operator, pow) {
    return mp_binary_op(MP_BINARY_OP_POWER, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, pow);

// operator.neg(a)
MPY_FUNC_1(operator, neg) {
    return mp_unary_op(MP_UNARY_OP_NEGATIVE, arg0);
}
MPY_FUNC_OBJ_1(operator, neg);

// operator.pos(a)
MPY_FUNC_1(operator, pos) {
    return mp_unary_op(MP_UNARY_OP_POSITIVE, arg0);
}
MPY_FUNC_OBJ_1(operator, pos);

// operator.abs(a)
MPY_FUNC_1(operator, abs) {
    return mp_unary_op(MP_UNARY_OP_ABS, arg0);
}
MPY_FUNC_OBJ_1(operator, abs);

// operator.index(a)
MPY_FUNC_1(operator, index) {
    return mp_obj_new_int(mp_obj_get_int(arg0));
}
MPY_FUNC_OBJ_1(operator, index);

// ============================================================================
// Comparison Operators
// ============================================================================

// operator.lt(a, b)
MPY_FUNC_2(operator, lt) {
    return mp_binary_op(MP_BINARY_OP_LESS, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, lt);

// operator.le(a, b)
MPY_FUNC_2(operator, le) {
    return mp_binary_op(MP_BINARY_OP_LESS_EQUAL, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, le);

// operator.eq(a, b)
MPY_FUNC_2(operator, eq) {
    return mp_binary_op(MP_BINARY_OP_EQUAL, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, eq);

// operator.ne(a, b)
MPY_FUNC_2(operator, ne) {
    return mp_binary_op(MP_BINARY_OP_NOT_EQUAL, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, ne);

// operator.ge(a, b)
MPY_FUNC_2(operator, ge) {
    return mp_binary_op(MP_BINARY_OP_MORE_EQUAL, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, ge);

// operator.gt(a, b)
MPY_FUNC_2(operator, gt) {
    return mp_binary_op(MP_BINARY_OP_MORE, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, gt);

// ============================================================================
// Logical/Bitwise Operators
// ============================================================================

// operator.not_(a)
MPY_FUNC_1(operator, not_) {
    return mp_obj_new_bool(!mp_obj_is_true(arg0));
}
MPY_FUNC_OBJ_1(operator, not_);

// operator.truth(a)
MPY_FUNC_1(operator, truth) {
    return mp_obj_new_bool(mp_obj_is_true(arg0));
}
MPY_FUNC_OBJ_1(operator, truth);

// operator.and_(a, b)
MPY_FUNC_2(operator, and_) {
    return mp_binary_op(MP_BINARY_OP_AND, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, and_);

// operator.or_(a, b)
MPY_FUNC_2(operator, or_) {
    return mp_binary_op(MP_BINARY_OP_OR, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, or_);

// operator.xor(a, b)
MPY_FUNC_2(operator, xor) {
    return mp_binary_op(MP_BINARY_OP_XOR, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, xor);

// operator.invert(a)
MPY_FUNC_1(operator, invert) {
    return mp_unary_op(MP_UNARY_OP_INVERT, arg0);
}
MPY_FUNC_OBJ_1(operator, invert);

// operator.inv(a) - alias for invert
MPY_FUNC_1(operator, inv) {
    return mp_unary_op(MP_UNARY_OP_INVERT, arg0);
}
MPY_FUNC_OBJ_1(operator, inv);

// operator.lshift(a, b)
MPY_FUNC_2(operator, lshift) {
    return mp_binary_op(MP_BINARY_OP_LSHIFT, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, lshift);

// operator.rshift(a, b)
MPY_FUNC_2(operator, rshift) {
    return mp_binary_op(MP_BINARY_OP_RSHIFT, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, rshift);

// ============================================================================
// Identity Operators
// ============================================================================

// operator.is_(a, b)
MPY_FUNC_2(operator, is_) {
    return mp_obj_new_bool(arg0 == arg1);
}
MPY_FUNC_OBJ_2(operator, is_);

// operator.is_not(a, b)
MPY_FUNC_2(operator, is_not) {
    return mp_obj_new_bool(arg0 != arg1);
}
MPY_FUNC_OBJ_2(operator, is_not);

// operator.is_none(a) - Python 3.11+
MPY_FUNC_1(operator, is_none) {
    return mp_obj_new_bool(arg0 == mp_const_none);
}
MPY_FUNC_OBJ_1(operator, is_none);

// operator.is_not_none(a) - Python 3.11+
MPY_FUNC_1(operator, is_not_none) {
    return mp_obj_new_bool(arg0 != mp_const_none);
}
MPY_FUNC_OBJ_1(operator, is_not_none);

// ============================================================================
// Sequence Operators
// ============================================================================

// operator.concat(a, b)
MPY_FUNC_2(operator, concat) {
    return mp_binary_op(MP_BINARY_OP_ADD, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, concat);

// operator.contains(a, b)
MPY_FUNC_2(operator, contains) {
    return mp_binary_op(MP_BINARY_OP_CONTAINS, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, contains);

// operator.countOf(a, b)
MPY_FUNC_2(operator, countOf) {
    mp_int_t count = 0;
    mp_obj_iter_buf_t iter_buf;
    mp_obj_t iter = mp_getiter(arg0, &iter_buf);
    mp_obj_t item;
    while ((item = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        if (mp_obj_equal(item, arg1)) {
            count++;
        }
    }
    return mp_obj_new_int(count);
}
MPY_FUNC_OBJ_2(operator, countOf);

// operator.indexOf(a, b)
MPY_FUNC_2(operator, indexOf) {
    mp_int_t index = 0;
    mp_obj_iter_buf_t iter_buf;
    mp_obj_t iter = mp_getiter(arg0, &iter_buf);
    mp_obj_t item;
    while ((item = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        if (mp_obj_equal(item, arg1)) {
            return mp_obj_new_int(index);
        }
        index++;
    }
    mp_raise_ValueError(MP_ERROR_TEXT("sequence.index(x): x not in sequence"));
}
MPY_FUNC_OBJ_2(operator, indexOf);

// operator.getitem(a, b)
MPY_FUNC_2(operator, getitem) {
    return mp_obj_subscr(arg0, arg1, MP_OBJ_SENTINEL);
}
MPY_FUNC_OBJ_2(operator, getitem);

// operator.setitem(a, b, c)
MPY_FUNC_3(operator, setitem) {
    mp_obj_subscr(arg0, arg1, arg2);
    return mp_const_none;
}
MPY_FUNC_OBJ_3(operator, setitem);

// operator.delitem(a, b)
MPY_FUNC_2(operator, delitem) {
    mp_obj_subscr(arg0, arg1, MP_OBJ_NULL);
    return mp_const_none;
}
MPY_FUNC_OBJ_2(operator, delitem);

// operator.length_hint(obj, default=0)
MPY_FUNC_VAR(operator, length_hint, 1, 2) {
    mp_int_t default_val = 0;
    if (n_args > 1) {
        default_val = mp_obj_get_int(args[1]);
    }
    
    // Try __len__ first by calling len() builtin
    // This is the most reliable way since len() handles all sequence types
    nlr_buf_t nlr;
    if (nlr_push(&nlr) == 0) {
        mp_obj_t result = mp_obj_len(args[0]);
        nlr_pop();
        return result;
    }
    
    // len() failed, return default
    return mp_obj_new_int(default_val);
}
MPY_FUNC_OBJ_VAR(operator, length_hint, 1, 2);

// ============================================================================
// In-place Operators
// ============================================================================

// operator.iadd(a, b)
MPY_FUNC_2(operator, iadd) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_ADD, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, iadd);

// operator.isub(a, b)
MPY_FUNC_2(operator, isub) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_SUBTRACT, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, isub);

// operator.imul(a, b)
MPY_FUNC_2(operator, imul) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_MULTIPLY, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, imul);

// operator.itruediv(a, b)
MPY_FUNC_2(operator, itruediv) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_TRUE_DIVIDE, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, itruediv);

// operator.ifloordiv(a, b)
MPY_FUNC_2(operator, ifloordiv) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_FLOOR_DIVIDE, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, ifloordiv);

// operator.imod(a, b)
MPY_FUNC_2(operator, imod) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_MODULO, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, imod);

// operator.ipow(a, b)
MPY_FUNC_2(operator, ipow) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_POWER, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, ipow);

// operator.iand(a, b)
MPY_FUNC_2(operator, iand) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_AND, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, iand);

// operator.ior(a, b)
MPY_FUNC_2(operator, ior) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_OR, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, ior);

// operator.ixor(a, b)
MPY_FUNC_2(operator, ixor) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_XOR, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, ixor);

// operator.ilshift(a, b)
MPY_FUNC_2(operator, ilshift) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_LSHIFT, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, ilshift);

// operator.irshift(a, b)
MPY_FUNC_2(operator, irshift) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_RSHIFT, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, irshift);

// operator.iconcat(a, b)
MPY_FUNC_2(operator, iconcat) {
    return mp_binary_op(MP_BINARY_OP_INPLACE_ADD, arg0, arg1);
}
MPY_FUNC_OBJ_2(operator, iconcat);

// ============================================================================
// itemgetter class
// ============================================================================

typedef struct _itemgetter_obj_t {
    mp_obj_base_t base;
    mp_obj_t items;  // Single item or tuple of items
    bool single;     // True if single item (return value, not tuple)
} itemgetter_obj_t;

static mp_obj_t itemgetter_call(mp_obj_t self_in, size_t n_args, size_t n_kw, const mp_obj_t *args);

static void itemgetter_print(const mp_print_t *print, mp_obj_t self_in, mp_print_kind_t kind) {
    (void)kind;
    mp_printf(print, "operator.itemgetter(...)");
}

MP_DEFINE_CONST_OBJ_TYPE(
    itemgetter_type,
    MP_QSTR_itemgetter,
    MP_TYPE_FLAG_NONE,
    print, itemgetter_print,
    call, itemgetter_call
);

static mp_obj_t itemgetter_call(mp_obj_t self_in, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 1, 1, false);
    itemgetter_obj_t *self = MP_OBJ_TO_PTR(self_in);
    mp_obj_t obj = args[0];
    
    if (self->single) {
        // Return single item
        return mp_obj_subscr(obj, self->items, MP_OBJ_SENTINEL);
    } else {
        // Return tuple of items
        size_t len;
        mp_obj_t *item_keys;
        mp_obj_tuple_get(self->items, &len, &item_keys);
        
        mp_obj_t *results = m_new(mp_obj_t, len);
        for (size_t i = 0; i < len; i++) {
            results[i] = mp_obj_subscr(obj, item_keys[i], MP_OBJ_SENTINEL);
        }
        mp_obj_t tuple = mp_obj_new_tuple(len, results);
        m_del(mp_obj_t, results, len);
        return tuple;
    }
}

// operator.itemgetter(item, ...) or operator.itemgetter(*items)
static mp_obj_t operator_itemgetter(size_t n_args, const mp_obj_t *args) {
    if (n_args == 0) {
        mp_raise_TypeError(MP_ERROR_TEXT("itemgetter expected at least 1 argument"));
    }
    
    itemgetter_obj_t *self = mp_obj_malloc(itemgetter_obj_t, &itemgetter_type);
    
    if (n_args == 1) {
        self->items = args[0];
        self->single = true;
    } else {
        self->items = mp_obj_new_tuple(n_args, args);
        self->single = false;
    }
    
    return MP_OBJ_FROM_PTR(self);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR(mod_operator_itemgetter_obj, 1, operator_itemgetter);

// ============================================================================
// attrgetter class
// ============================================================================

typedef struct _attrgetter_obj_t {
    mp_obj_base_t base;
    mp_obj_t attrs;  // Single attr name or tuple of attr names
    bool single;     // True if single attr (return value, not tuple)
} attrgetter_obj_t;

static mp_obj_t attrgetter_call(mp_obj_t self_in, size_t n_args, size_t n_kw, const mp_obj_t *args);

static void attrgetter_print(const mp_print_t *print, mp_obj_t self_in, mp_print_kind_t kind) {
    (void)kind;
    mp_printf(print, "operator.attrgetter(...)");
}

// Helper to get nested attribute (e.g., "a.b.c")
static mp_obj_t get_nested_attr(mp_obj_t obj, const char *name, size_t len) {
    const char *start = name;
    const char *end = name;
    
    while (end < name + len) {
        // Find next dot or end
        while (end < name + len && *end != '.') {
            end++;
        }
        
        // Get this attribute
        qstr attr = qstr_from_strn(start, end - start);
        obj = mp_load_attr(obj, attr);
        
        // Skip dot
        if (end < name + len) {
            end++;
        }
        start = end;
    }
    
    return obj;
}

MP_DEFINE_CONST_OBJ_TYPE(
    attrgetter_type,
    MP_QSTR_attrgetter,
    MP_TYPE_FLAG_NONE,
    print, attrgetter_print,
    call, attrgetter_call
);

static mp_obj_t attrgetter_call(mp_obj_t self_in, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 1, 1, false);
    attrgetter_obj_t *self = MP_OBJ_TO_PTR(self_in);
    mp_obj_t obj = args[0];
    
    if (self->single) {
        // Return single attr
        size_t len;
        const char *name = mp_obj_str_get_data(self->attrs, &len);
        return get_nested_attr(obj, name, len);
    } else {
        // Return tuple of attrs
        size_t n_attrs;
        mp_obj_t *attr_names;
        mp_obj_tuple_get(self->attrs, &n_attrs, &attr_names);
        
        mp_obj_t *results = m_new(mp_obj_t, n_attrs);
        for (size_t i = 0; i < n_attrs; i++) {
            size_t len;
            const char *name = mp_obj_str_get_data(attr_names[i], &len);
            results[i] = get_nested_attr(obj, name, len);
        }
        mp_obj_t tuple = mp_obj_new_tuple(n_attrs, results);
        m_del(mp_obj_t, results, n_attrs);
        return tuple;
    }
}

// operator.attrgetter(attr, ...) or operator.attrgetter(*attrs)
static mp_obj_t operator_attrgetter(size_t n_args, const mp_obj_t *args) {
    if (n_args == 0) {
        mp_raise_TypeError(MP_ERROR_TEXT("attrgetter expected at least 1 argument"));
    }
    
    attrgetter_obj_t *self = mp_obj_malloc(attrgetter_obj_t, &attrgetter_type);
    
    if (n_args == 1) {
        self->attrs = args[0];
        self->single = true;
    } else {
        self->attrs = mp_obj_new_tuple(n_args, args);
        self->single = false;
    }
    
    return MP_OBJ_FROM_PTR(self);
}
static MP_DEFINE_CONST_FUN_OBJ_VAR(mod_operator_attrgetter_obj, 1, operator_attrgetter);

// ============================================================================
// methodcaller class
// ============================================================================

typedef struct _methodcaller_obj_t {
    mp_obj_base_t base;
    mp_obj_t method_name;
    mp_obj_t args;    // tuple of positional args
    mp_obj_t kwargs;  // dict of keyword args
} methodcaller_obj_t;

static mp_obj_t methodcaller_call(mp_obj_t self_in, size_t n_args, size_t n_kw, const mp_obj_t *args);

static void methodcaller_print(const mp_print_t *print, mp_obj_t self_in, mp_print_kind_t kind) {
    (void)kind;
    methodcaller_obj_t *self = MP_OBJ_TO_PTR(self_in);
    mp_printf(print, "operator.methodcaller(%O, ...)", self->method_name);
}

MP_DEFINE_CONST_OBJ_TYPE(
    methodcaller_type,
    MP_QSTR_methodcaller,
    MP_TYPE_FLAG_NONE,
    print, methodcaller_print,
    call, methodcaller_call
);

static mp_obj_t methodcaller_call(mp_obj_t self_in, size_t n_args, size_t n_kw, const mp_obj_t *call_args) {
    mp_arg_check_num(n_args, n_kw, 1, 1, false);
    methodcaller_obj_t *self = MP_OBJ_TO_PTR(self_in);
    mp_obj_t obj = call_args[0];
    
    // Get method name as qstr
    size_t len;
    const char *name = mp_obj_str_get_data(self->method_name, &len);
    qstr method_qstr = qstr_from_strn(name, len);
    
    // Get the method
    mp_obj_t method = mp_load_attr(obj, method_qstr);
    
    // Get stored args
    size_t stored_n_args;
    mp_obj_t *stored_args;
    mp_obj_tuple_get(self->args, &stored_n_args, &stored_args);
    
    // Get stored kwargs count
    size_t stored_n_kw = 0;
    mp_map_t *stored_kwargs_map = NULL;
    if (self->kwargs != mp_const_none && mp_obj_is_type(self->kwargs, &mp_type_dict)) {
        mp_obj_dict_t *stored_dict = MP_OBJ_TO_PTR(self->kwargs);
        stored_kwargs_map = &stored_dict->map;
        stored_n_kw = stored_kwargs_map->used;
    }
    
    // Build combined args array
    mp_obj_t *combined_args = m_new(mp_obj_t, stored_n_args + 2 * stored_n_kw);
    
    // Copy positional args
    for (size_t i = 0; i < stored_n_args; i++) {
        combined_args[i] = stored_args[i];
    }
    
    // Copy kwargs
    size_t kw_idx = 0;
    if (stored_kwargs_map != NULL) {
        for (size_t i = 0; i < stored_kwargs_map->alloc; i++) {
            if (mp_map_slot_is_filled(stored_kwargs_map, i)) {
                combined_args[stored_n_args + kw_idx * 2] = stored_kwargs_map->table[i].key;
                combined_args[stored_n_args + kw_idx * 2 + 1] = stored_kwargs_map->table[i].value;
                kw_idx++;
            }
        }
    }
    
    mp_obj_t result = mp_call_function_n_kw(method, stored_n_args, stored_n_kw, combined_args);
    m_del(mp_obj_t, combined_args, stored_n_args + 2 * stored_n_kw);
    
    return result;
}

// operator.methodcaller(name, *args, **kwargs)
static mp_obj_t operator_methodcaller(size_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    if (n_args < 1) {
        mp_raise_TypeError(MP_ERROR_TEXT("methodcaller expected at least 1 argument"));
    }
    
    methodcaller_obj_t *self = mp_obj_malloc(methodcaller_obj_t, &methodcaller_type);
    self->method_name = args[0];
    
    // Store positional args (skip first which is the method name)
    if (n_args > 1) {
        self->args = mp_obj_new_tuple(n_args - 1, args + 1);
    } else {
        self->args = mp_const_empty_tuple;
    }
    
    // Store keyword args
    if (kwargs != NULL && kwargs->used > 0) {
        self->kwargs = mp_obj_new_dict(kwargs->used);
        for (size_t i = 0; i < kwargs->alloc; i++) {
            if (mp_map_slot_is_filled(kwargs, i)) {
                mp_obj_dict_store(self->kwargs, kwargs->table[i].key, kwargs->table[i].value);
            }
        }
    } else {
        self->kwargs = mp_const_none;
    }
    
    return MP_OBJ_FROM_PTR(self);
}
static MP_DEFINE_CONST_FUN_OBJ_KW(mod_operator_methodcaller_obj, 1, operator_methodcaller);

// ============================================================================
// operator.call(obj, /, *args, **kwargs) - Python 3.11+
// ============================================================================

static mp_obj_t operator_call(size_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    if (n_args < 1) {
        mp_raise_TypeError(MP_ERROR_TEXT("call() requires at least 1 argument"));
    }
    
    mp_obj_t func = args[0];
    size_t n_kw = kwargs ? kwargs->used : 0;
    
    // Build args array for call
    mp_obj_t *call_args = m_new(mp_obj_t, n_args - 1 + 2 * n_kw);
    
    // Copy positional args (skip first which is the callable)
    for (size_t i = 1; i < n_args; i++) {
        call_args[i - 1] = args[i];
    }
    
    // Copy kwargs
    size_t kw_idx = 0;
    if (kwargs != NULL) {
        for (size_t i = 0; i < kwargs->alloc; i++) {
            if (mp_map_slot_is_filled(kwargs, i)) {
                call_args[n_args - 1 + kw_idx * 2] = kwargs->table[i].key;
                call_args[n_args - 1 + kw_idx * 2 + 1] = kwargs->table[i].value;
                kw_idx++;
            }
        }
    }
    
    mp_obj_t result = mp_call_function_n_kw(func, n_args - 1, n_kw, call_args);
    m_del(mp_obj_t, call_args, n_args - 1 + 2 * n_kw);
    
    return result;
}
static MP_DEFINE_CONST_FUN_OBJ_KW(mod_operator_call_obj, 1, operator_call);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(operator)
    // Arithmetic operators
    MPY_MODULE_FUNC(operator, add)
    MPY_MODULE_FUNC(operator, sub)
    MPY_MODULE_FUNC(operator, mul)
    MPY_MODULE_FUNC(operator, truediv)
    MPY_MODULE_FUNC(operator, floordiv)
    MPY_MODULE_FUNC(operator, mod)
    MPY_MODULE_FUNC(operator, pow)
    MPY_MODULE_FUNC(operator, neg)
    MPY_MODULE_FUNC(operator, pos)
    MPY_MODULE_FUNC(operator, abs)
    MPY_MODULE_FUNC(operator, index)
    
    // Comparison operators
    MPY_MODULE_FUNC(operator, lt)
    MPY_MODULE_FUNC(operator, le)
    MPY_MODULE_FUNC(operator, eq)
    MPY_MODULE_FUNC(operator, ne)
    MPY_MODULE_FUNC(operator, ge)
    MPY_MODULE_FUNC(operator, gt)
    
    // Logical/bitwise operators
    MPY_MODULE_FUNC(operator, not_)
    MPY_MODULE_FUNC(operator, truth)
    MPY_MODULE_FUNC(operator, and_)
    MPY_MODULE_FUNC(operator, or_)
    MPY_MODULE_FUNC(operator, xor)
    MPY_MODULE_FUNC(operator, invert)
    MPY_MODULE_FUNC(operator, inv)
    MPY_MODULE_FUNC(operator, lshift)
    MPY_MODULE_FUNC(operator, rshift)
    
    // Identity operators
    MPY_MODULE_FUNC(operator, is_)
    MPY_MODULE_FUNC(operator, is_not)
    MPY_MODULE_FUNC(operator, is_none)
    MPY_MODULE_FUNC(operator, is_not_none)
    
    // Sequence operators
    MPY_MODULE_FUNC(operator, concat)
    MPY_MODULE_FUNC(operator, contains)
    MPY_MODULE_FUNC(operator, countOf)
    MPY_MODULE_FUNC(operator, indexOf)
    MPY_MODULE_FUNC(operator, getitem)
    MPY_MODULE_FUNC(operator, setitem)
    MPY_MODULE_FUNC(operator, delitem)
    MPY_MODULE_FUNC(operator, length_hint)
    
    // In-place operators
    MPY_MODULE_FUNC(operator, iadd)
    MPY_MODULE_FUNC(operator, isub)
    MPY_MODULE_FUNC(operator, imul)
    MPY_MODULE_FUNC(operator, itruediv)
    MPY_MODULE_FUNC(operator, ifloordiv)
    MPY_MODULE_FUNC(operator, imod)
    MPY_MODULE_FUNC(operator, ipow)
    MPY_MODULE_FUNC(operator, iand)
    MPY_MODULE_FUNC(operator, ior)
    MPY_MODULE_FUNC(operator, ixor)
    MPY_MODULE_FUNC(operator, ilshift)
    MPY_MODULE_FUNC(operator, irshift)
    MPY_MODULE_FUNC(operator, iconcat)
    
    // Callable classes
    { MP_ROM_QSTR(MP_QSTR_itemgetter), MP_ROM_PTR(&mod_operator_itemgetter_obj) },
    { MP_ROM_QSTR(MP_QSTR_attrgetter), MP_ROM_PTR(&mod_operator_attrgetter_obj) },
    { MP_ROM_QSTR(MP_QSTR_methodcaller), MP_ROM_PTR(&mod_operator_methodcaller_obj) },
    { MP_ROM_QSTR(MP_QSTR_call), MP_ROM_PTR(&mod_operator_call_obj) },
MPY_MODULE_END(operator)
