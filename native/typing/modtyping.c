/*
 * modtyping.c - Native typing module for ucharm
 *
 * Provides no-op stubs for Python's typing module to allow
 * type-annotated code to run without errors.
 *
 * At runtime, type hints are erased. We just need to provide names
 * that can be imported without errors.
 *
 * Usage in Python:
 *   from typing import Any, Optional, List, Dict
 *   from typing import TypeVar, Generic, cast
 *
 *   def greet(name: str) -> str:
 *       return f"Hello, {name}"
 *
 *   T = TypeVar('T')
 *   x: Optional[int] = None
 */

#include "../bridge/mpy_bridge.h"

// ============================================================================
// TypeVar - Returns None (placeholder for type variables)
// ============================================================================

MPY_FUNC_VAR(typing, TypeVar, 1, 10) {
    (void)n_args;
    (void)args;
    return mpy_none();
}
MPY_FUNC_OBJ_VAR(typing, TypeVar, 1, 10);

// ============================================================================
// cast(typ, val) -> val (identity function)
// ============================================================================

MPY_FUNC_2(typing, cast) {
    (void)arg0;
    return arg1;
}
MPY_FUNC_OBJ_2(typing, cast);

// ============================================================================
// get_type_hints(obj) -> {} (empty dict)
// ============================================================================

MPY_FUNC_VAR(typing, get_type_hints, 1, 3) {
    (void)n_args;
    (void)args;
    return mpy_new_dict();
}
MPY_FUNC_OBJ_VAR(typing, get_type_hints, 1, 3);

// ============================================================================
// get_origin(tp) -> None
// ============================================================================

MPY_FUNC_1(typing, get_origin) {
    (void)arg0;
    return mpy_none();
}
MPY_FUNC_OBJ_1(typing, get_origin);

// ============================================================================
// get_args(tp) -> () (empty tuple)
// ============================================================================

MPY_FUNC_1(typing, get_args) {
    (void)arg0;
    return mp_const_empty_tuple;
}
MPY_FUNC_OBJ_1(typing, get_args);

// ============================================================================
// NewType(name, tp) -> None
// ============================================================================

MPY_FUNC_2(typing, NewType) {
    (void)arg0;
    (void)arg1;
    return mpy_none();
}
MPY_FUNC_OBJ_2(typing, NewType);

// ============================================================================
// Decorator functions - return argument unchanged
// ============================================================================

MPY_FUNC_1(typing, overload) {
    return arg0;
}
MPY_FUNC_OBJ_1(typing, overload);

MPY_FUNC_1(typing, no_type_check) {
    return arg0;
}
MPY_FUNC_OBJ_1(typing, no_type_check);

MPY_FUNC_1(typing, no_type_check_decorator) {
    return arg0;
}
MPY_FUNC_OBJ_1(typing, no_type_check_decorator);

MPY_FUNC_1(typing, runtime_checkable) {
    return arg0;
}
MPY_FUNC_OBJ_1(typing, runtime_checkable);

MPY_FUNC_1(typing, final) {
    return arg0;
}
MPY_FUNC_OBJ_1(typing, final);

MPY_FUNC_1(typing, dataclass_transform) {
    return arg0;
}
MPY_FUNC_OBJ_1(typing, dataclass_transform);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(typing)
    // Functions
    MPY_MODULE_FUNC(typing, TypeVar)
    MPY_MODULE_FUNC(typing, cast)
    MPY_MODULE_FUNC(typing, get_type_hints)
    MPY_MODULE_FUNC(typing, get_origin)
    MPY_MODULE_FUNC(typing, get_args)
    MPY_MODULE_FUNC(typing, NewType)
    MPY_MODULE_FUNC(typing, overload)
    MPY_MODULE_FUNC(typing, no_type_check)
    MPY_MODULE_FUNC(typing, no_type_check_decorator)
    MPY_MODULE_FUNC(typing, runtime_checkable)
    MPY_MODULE_FUNC(typing, final)
    MPY_MODULE_FUNC(typing, dataclass_transform)

    // Type aliases - all are None (no-op placeholders)
    { MP_ROM_QSTR(MP_QSTR_Any), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Union), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Optional), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_List), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Dict), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Set), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_FrozenSet), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Tuple), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Callable), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Type), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Generic), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_ClassVar), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Final), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Literal), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Annotated), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Protocol), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Iterable), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Iterator), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Generator), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Sequence), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Mapping), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_MutableMapping), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_MutableSequence), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_MutableSet), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_IO), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_TextIO), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_BinaryIO), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_TypeGuard), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Concatenate), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_ParamSpec), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_TypeVarTuple), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Unpack), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Self), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Never), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_NoReturn), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_AnyStr), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_SupportsInt), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_SupportsFloat), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_SupportsComplex), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_SupportsBytes), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_SupportsAbs), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_SupportsRound), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Reversible), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Hashable), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Sized), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Collection), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Container), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Awaitable), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Coroutine), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_AsyncIterable), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_AsyncIterator), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_AsyncGenerator), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_ContextManager), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_AsyncContextManager), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_Required), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_NotRequired), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_TypeAlias), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_TypedDict), MP_ROM_NONE },
    { MP_ROM_QSTR(MP_QSTR_NamedTuple), MP_ROM_NONE },

    // TYPE_CHECKING constant - always False at runtime
    { MP_ROM_QSTR(MP_QSTR_TYPE_CHECKING), MP_ROM_FALSE },
MPY_MODULE_END(typing)
