// typing.zig - Minimal Zig implementation for typing module stubs
//
// The typing module provides no-op stubs for Python's type hints.
// At runtime, type hints are erased - we just need names that can be imported.
// All actual logic is in the C bridge (modtyping.c).

const std = @import("std");

// ============================================================================
// Placeholder Functions
// ============================================================================

// The typing module doesn't need any actual Zig logic.
// All type stubs are implemented directly in C as MicroPython objects.
// This file exists only to satisfy the build system.

/// Version identifier for the typing module
pub export fn typing_version() u32 {
    return 1;
}

// ============================================================================
// Tests
// ============================================================================

test "version" {
    try std.testing.expectEqual(@as(u32, 1), typing_version());
}
