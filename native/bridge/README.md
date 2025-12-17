# Zig → C → MicroPython Bridge

This directory contains a reusable bridge framework for creating MicroPython modules with Zig.

## Architecture

```
┌─────────────────────────────────────┐
│  Your Python Code                   │
│  import mymodule                    │
│  mymodule.add(2, 3)                 │
├─────────────────────────────────────┤
│  C Bridge (modmymodule.c)           │
│  - MicroPython API wrappers         │
│  - Type conversions (Python ↔ C)    │
│  - Module registration              │
├─────────────────────────────────────┤
│  Zig Core (mymodule.zig)            │
│  - Pure logic, no allocations       │
│  - Type safe, tested                │
│  - Exported with C ABI              │
└─────────────────────────────────────┘
```

## Quick Start

### 1. Create Module Directory

```bash
mkdir native/mymodule
```

### 2. Copy Templates

```bash
cp native/bridge/template.zig native/mymodule/mymodule.zig
cp native/bridge/template_mod.c native/mymodule/modmymodule.c
cp native/bridge/template_build.zig native/mymodule/build.zig
cp native/bridge/template_micropython.mk native/mymodule/micropython.mk
```

### 3. Rename References

In each file, replace `template` with `mymodule`:

```bash
# On macOS
sed -i '' 's/template/mymodule/g' native/mymodule/*.zig
sed -i '' 's/template/mymodule/g' native/mymodule/*.c
sed -i '' 's/TEMPLATE/MYMODULE/g' native/mymodule/micropython.mk
```

### 4. Implement Your Functions

Edit `mymodule.zig`:

```zig
const bridge = @import("../bridge/bridge.zig");

// Internal implementation
fn calculate(x: i64, y: i64) i64 {
    return x * y + 1;
}

// Exported function (callable from C)
export fn mymodule_calculate(x: i64, y: i64) i64 {
    return calculate(x, y);
}

// Tests
test "calculate" {
    try std.testing.expectEqual(@as(i64, 7), mymodule_calculate(2, 3));
}
```

Edit `modmymodule.c`:

```c
#include "../bridge/mpy_bridge.h"

// Declare Zig function
ZIG_EXTERN int64_t mymodule_calculate(int64_t x, int64_t y);

// Wrap for Python
MPY_FUNC_2(mymodule, calculate) {
    int64_t x = mpy_int(arg0);
    int64_t y = mpy_int(arg1);
    return mpy_new_int64(mymodule_calculate(x, y));
}
MPY_FUNC_OBJ_2(mymodule, calculate);

// Register module
MPY_MODULE_BEGIN(mymodule)
    MPY_MODULE_FUNC(mymodule, calculate)
MPY_MODULE_END(mymodule)
```

### 5. Build & Test

```bash
cd native/mymodule
zig build test   # Run Zig tests
zig build        # Compile to .o file

cd ..
./build.sh       # Rebuild micropython-ucharm
```

### 6. Use in Python

```python
import mymodule
result = mymodule.calculate(2, 3)  # Returns 7
```

## Bridge Components

### mpy_bridge.h

C header with helper macros and functions:

| Macro/Function | Purpose |
|----------------|---------|
| `ZIG_EXTERN` | Declare external Zig function |
| `mpy_str(obj)` | Get C string from Python str |
| `mpy_int(obj)` | Get int from Python int |
| `mpy_bool(val)` | Create Python bool |
| `mpy_new_str(s)` | Create Python str |
| `mpy_new_int(n)` | Create Python int |
| `MPY_FUNC_N(mod, name)` | Define wrapper function |
| `MPY_FUNC_OBJ_N(mod, name)` | Create function object |
| `MPY_MODULE_BEGIN/END` | Define module |

### bridge.zig

Zig utilities for C interop:

| Type/Function | Purpose |
|---------------|---------|
| `CStr` | Null-terminated C string type |
| `cstr_to_slice(s)` | Convert to Zig slice |
| `cstr_len(s)` | String length |
| `cstr_eql(a, b)` | String equality |
| `is_valid_int(s)` | Check if valid integer |
| `parse_int(s)` | Parse integer |
| `is_truthy(s)` | Check truthy value |

## Function Signatures

### Zero Arguments

```zig
// Zig
export fn mymod_get_version() i64 {
    return 1;
}
```

```c
// C
ZIG_EXTERN int64_t mymod_get_version(void);

MPY_FUNC_0(mymod, get_version) {
    return mpy_new_int64(mymod_get_version());
}
MPY_FUNC_OBJ_0(mymod, get_version);
```

### One Argument

```zig
// Zig
export fn mymod_double(n: i64) i64 {
    return n * 2;
}
```

```c
// C
ZIG_EXTERN int64_t mymod_double(int64_t n);

MPY_FUNC_1(mymod, double) {
    return mpy_new_int64(mymod_double(mpy_int(arg0)));
}
MPY_FUNC_OBJ_1(mymod, double);
```

### Two Arguments

```zig
// Zig
export fn mymod_add(a: i64, b: i64) i64 {
    return a + b;
}
```

```c
// C
ZIG_EXTERN int64_t mymod_add(int64_t a, int64_t b);

MPY_FUNC_2(mymod, add) {
    return mpy_new_int64(mymod_add(mpy_int(arg0), mpy_int(arg1)));
}
MPY_FUNC_OBJ_2(mymod, add);
```

### Variable Arguments

```c
// C - 1 to 3 arguments
MPY_FUNC_VAR(mymod, range, 1, 3) {
    int64_t start = 0, stop, step = 1;
    if (n_args == 1) {
        stop = mpy_int(args[0]);
    } else {
        start = mpy_int(args[0]);
        stop = mpy_int(args[1]);
        if (n_args == 3) step = mpy_int(args[2]);
    }
    // ...
}
MPY_FUNC_OBJ_VAR(mymod, range, 1, 3);
```

### Returning Strings

```zig
// Zig - return pointer into existing string
export fn mymod_skip_prefix(s: bridge.CStr, n: usize) bridge.CStr {
    return bridge.cstr_skip(s, n);
}
```

```c
// C
ZIG_EXTERN const char *mymod_skip_prefix(const char *s, size_t n);

MPY_FUNC_2(mymod, skip_prefix) {
    const char *result = mymod_skip_prefix(mpy_str(arg0), mpy_int(arg1));
    return mpy_new_str(result);
}
```

### Returning Tuples

```c
MPY_FUNC_0(mymod, get_pair) {
    return mpy_tuple2(mpy_new_int(1), mpy_new_int(2));
}
```

### Returning Lists

```c
MPY_FUNC_1(mymod, to_list) {
    mp_obj_t list = mpy_new_list();
    mpy_list_append(list, mpy_new_int(1));
    mpy_list_append(list, mpy_new_int(2));
    return list;
}
```

### Returning Dicts

```c
MPY_FUNC_0(mymod, get_info) {
    mp_obj_t dict = mpy_new_dict();
    mpy_dict_store_str(dict, "version", mpy_new_int(1));
    mpy_dict_store_str(dict, "name", mpy_new_str("mymod"));
    return dict;
}
```

## Best Practices

### Zig Side

1. **Keep functions pure** - No side effects when possible
2. **No allocations** - Return pointers into input strings
3. **Use `export`** - Required for C visibility
4. **Prefix exports** - Use `modulename_` prefix
5. **Add tests** - Test in Zig before C integration

### C Side

1. **Use helper macros** - Less boilerplate, fewer bugs
2. **Validate inputs** - Check for None, wrong types
3. **Handle errors** - Use `mpy_raise_*` functions
4. **Match Python conventions** - snake_case names

## File Structure

```
native/mymodule/
├── mymodule.zig      # Zig implementation
├── modmymodule.c     # C bridge
├── build.zig         # Zig build config
├── micropython.mk    # MicroPython integration
└── zig-out/
    └── mymodule.o    # Compiled object (generated)
```

## Troubleshooting

### "undefined reference to mymod_func"

- Check function is exported with `export fn`
- Check function name matches in C `extern` declaration
- Rebuild Zig: `zig build`

### "module not found"

- Check `micropython.mk` is in module directory
- Check module is registered with `MP_REGISTER_MODULE`
- Rebuild MicroPython: `./build.sh`

### Segfault in module

- Check string null-termination
- Check pointer lifetimes
- Add bounds checking in Zig

### Tests fail

- Run `zig build test` for Zig-side issues
- Check type conversions in C bridge
