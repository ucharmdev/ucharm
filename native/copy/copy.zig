// copy.zig - Native copy module for ucharm
//
// This module provides Python's copy functionality:
// - copy(obj) - Shallow copy
// - deepcopy(obj) - Deep copy
//
// Note: The actual copy logic is implemented in modcopy.c
// since it requires direct MicroPython type introspection.
// This Zig file provides minimal utility functions.

const std = @import("std");

// ============================================================================
// Module Implementation
// ============================================================================

// The copy module's main logic is in the C bridge (modcopy.c)
// because it needs to work directly with MicroPython object types.
// This Zig file provides utility functions that could be useful
// for performance-critical operations.

/// Simple hash function for object identity tracking in deepcopy
pub fn hash_pointer(ptr: usize) u64 {
    // FNV-1a hash of pointer value
    var hash: u64 = 0xcbf29ce484222325;
    const bytes = @as([*]const u8, @ptrCast(&ptr))[0..@sizeOf(usize)];
    for (bytes) |byte| {
        hash ^= byte;
        hash *%= 0x100000001b3;
    }
    return hash;
}

// ============================================================================
// Exported Functions (C ABI)
// ============================================================================

/// Hash a pointer value (used for memo dict in deepcopy)
pub export fn copy_hash_pointer(ptr: usize) u64 {
    return hash_pointer(ptr);
}

/// Get module version
pub export fn copy_version() u32 {
    return 1;
}

// ============================================================================
// Tests
// ============================================================================

test "hash_pointer" {
    const ptr1: usize = 0x12345678;
    const ptr2: usize = 0x87654321;

    const hash1 = hash_pointer(ptr1);
    const hash2 = hash_pointer(ptr2);

    // Different pointers should have different hashes
    try std.testing.expect(hash1 != hash2);

    // Same pointer should have same hash
    try std.testing.expectEqual(hash1, hash_pointer(ptr1));
}
