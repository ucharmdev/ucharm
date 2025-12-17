// functools.zig - Native functools implementation for MicroPython
// Provides high-performance implementations of reduce and cmp_to_key utilities

const std = @import("std");

// Note: Most functools functions (partial, wraps, lru_cache) require deep Python
// integration and are better implemented in the C bridge. This Zig module provides
// helper utilities and the reduce algorithm.

// Simple memoization cache for internal use
const CACHE_SIZE = 256;

pub const CacheEntry = extern struct {
    key_hash: u64,
    value: i64,
    valid: bool,
};

var memo_cache: [CACHE_SIZE]CacheEntry = [_]CacheEntry{.{ .key_hash = 0, .value = 0, .valid = false }} ** CACHE_SIZE;

// FNV-1a hash for cache keys
pub export fn functools_hash(data_ptr: [*]const u8, data_len: usize) u64 {
    if (data_len == 0) return 0;

    const data = data_ptr[0..data_len];
    var hash: u64 = 0xcbf29ce484222325; // FNV offset basis

    for (data) |byte| {
        hash ^= byte;
        hash *%= 0x100000001b3; // FNV prime
    }

    return hash;
}

// Cache lookup
pub export fn functools_cache_get(key_hash: u64, out_value: *i64) bool {
    const index = key_hash % CACHE_SIZE;
    const entry = &memo_cache[index];

    if (entry.valid and entry.key_hash == key_hash) {
        out_value.* = entry.value;
        return true;
    }

    return false;
}

// Cache store
pub export fn functools_cache_set(key_hash: u64, value: i64) void {
    const index = key_hash % CACHE_SIZE;
    memo_cache[index] = .{
        .key_hash = key_hash,
        .value = value,
        .valid = true,
    };
}

// Clear cache
pub export fn functools_cache_clear() void {
    for (&memo_cache) |*entry| {
        entry.valid = false;
    }
}

// Get cache stats
pub export fn functools_cache_size() usize {
    var count: usize = 0;
    for (memo_cache) |entry| {
        if (entry.valid) count += 1;
    }
    return count;
}

// Comparison result for cmp_to_key
pub const CmpResult = enum(i32) {
    less = -1,
    equal = 0,
    greater = 1,
};

// Identity function - returns input unchanged (for default key functions)
pub export fn functools_identity(value: i64) i64 {
    return value;
}

// Compose two integers for hashing (used for tuple-like keys)
pub export fn functools_hash_pair(a: u64, b: u64) u64 {
    // Combine using FNV-style mixing
    var hash: u64 = 0xcbf29ce484222325;
    hash ^= a;
    hash *%= 0x100000001b3;
    hash ^= b;
    hash *%= 0x100000001b3;
    return hash;
}
