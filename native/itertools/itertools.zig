// itertools.zig - Native itertools implementation for MicroPython
// Provides helper functions for iterator tools

const std = @import("std");

// Note: Most itertools functions are iterator-based and require deep MicroPython
// integration. The C bridge implements the actual iterator types.
// This Zig module provides utility functions for combinatorics.

// Factorial calculation for permutation/combination counts
pub export fn itertools_factorial(n: u64) u64 {
    if (n <= 1) return 1;
    var result: u64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        result *|= i; // Saturating multiply to avoid overflow
    }
    return result;
}

// nPr - number of permutations
pub export fn itertools_permutations_count(n: u64, r: u64) u64 {
    if (r > n) return 0;
    var result: u64 = 1;
    var i: u64 = 0;
    while (i < r) : (i += 1) {
        result *|= (n - i);
    }
    return result;
}

// nCr - number of combinations
pub export fn itertools_combinations_count(n: u64, r: u64) u64 {
    if (r > n) return 0;
    if (r == 0 or r == n) return 1;

    // Use smaller r for efficiency
    var r_adj = r;
    if (r > n - r) {
        r_adj = n - r;
    }

    var result: u64 = 1;
    var i: u64 = 0;
    while (i < r_adj) : (i += 1) {
        result = result * (n - i) / (i + 1);
    }
    return result;
}

// Generate next permutation indices (returns false when done)
// indices should be an array of size n, initialized to 0..n-1
pub export fn itertools_next_permutation(indices: [*]u32, n: usize) bool {
    if (n <= 1) return false;

    // Find largest i such that indices[i] < indices[i+1]
    var i: usize = n - 2;
    while (i < n and indices[i] >= indices[i + 1]) {
        if (i == 0) return false;
        i -= 1;
    }
    if (i >= n) return false;

    // Find largest j such that indices[i] < indices[j]
    var j: usize = n - 1;
    while (indices[i] >= indices[j]) {
        j -= 1;
    }

    // Swap indices[i] and indices[j]
    const tmp = indices[i];
    indices[i] = indices[j];
    indices[j] = tmp;

    // Reverse indices[i+1..n]
    var left = i + 1;
    var right = n - 1;
    while (left < right) {
        const tmp2 = indices[left];
        indices[left] = indices[right];
        indices[right] = tmp2;
        left += 1;
        right -= 1;
    }

    return true;
}

// Generate next combination indices (r elements from n)
// indices should be initialized to 0..r-1
pub export fn itertools_next_combination(indices: [*]u32, n: u32, r: u32) bool {
    if (r == 0 or r > n) return false;

    // Find rightmost element that can be incremented
    var i: i32 = @as(i32, @intCast(r)) - 1;
    while (i >= 0) : (i -= 1) {
        const ui: usize = @intCast(i);
        if (indices[ui] < n - r + @as(u32, @intCast(i))) {
            indices[ui] += 1;
            // Reset all elements to the right
            var j: usize = ui + 1;
            while (j < r) : (j += 1) {
                indices[j] = indices[j - 1] + 1;
            }
            return true;
        }
    }

    return false;
}

// Cycle index helper - wraps around
pub export fn itertools_cycle_index(current: usize, length: usize) usize {
    if (length == 0) return 0;
    return current % length;
}
