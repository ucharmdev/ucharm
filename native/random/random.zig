const std = @import("std");

// Random module - provides random number generation functions
// This replaces MicroPython's built-in random with a native Zig implementation
// that adds shuffle and sample functions.

// We use a simple xorshift PRNG for deterministic results when seeded
var prng_state: u64 = 0x853c49e6748fea9b; // Default seed

/// Seed the random number generator
pub export fn random_seed(seed: u64) void {
    prng_state = if (seed == 0) 0x853c49e6748fea9b else seed;
}

/// Generate a random u64
fn next_u64() u64 {
    // xorshift64*
    var x = prng_state;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    prng_state = x;
    return x *% 0x2545F4914F6CDD1D;
}

/// Generate a random float in [0.0, 1.0)
pub export fn random_random() f64 {
    const bits = next_u64();
    // Use upper 53 bits for double precision
    const frac: f64 = @floatFromInt(bits >> 11);
    return frac / 9007199254740992.0; // 2^53
}

/// Generate a random integer in [a, b] inclusive
pub export fn random_randint(a: i64, b: i64) i64 {
    if (a > b) return a;
    const range: u64 = @intCast(b - a + 1);
    const rand = next_u64() % range;
    return a + @as(i64, @intCast(rand));
}

/// Generate a random integer in [0, n)
pub export fn random_randrange(n: i64) i64 {
    if (n <= 0) return 0;
    return @intCast(next_u64() % @as(u64, @intCast(n)));
}

/// Generate random bits
pub export fn random_getrandbits(k: u32) u64 {
    if (k == 0) return 0;
    if (k >= 64) return next_u64();
    const mask: u64 = (@as(u64, 1) << @intCast(k)) - 1;
    return next_u64() & mask;
}

/// Generate a random float in [a, b]
pub export fn random_uniform(a: f64, b: f64) f64 {
    return a + (b - a) * random_random();
}

/// Fisher-Yates shuffle - shuffle array in place
/// indices is an array of indices [0, 1, 2, ..., n-1] that will be shuffled
pub export fn random_shuffle_indices(indices: [*]usize, len: usize) void {
    if (len <= 1) return;

    var i: usize = len - 1;
    while (i > 0) : (i -= 1) {
        const j = next_u64() % (i + 1);
        // Swap indices[i] and indices[j]
        const tmp = indices[i];
        indices[i] = indices[@intCast(j)];
        indices[@intCast(j)] = tmp;
    }
}

/// Generate k unique random indices from range [0, n)
/// Used for sample() - returns indices in the order they were selected
pub export fn random_sample_indices(indices: [*]usize, k: usize, n: usize) void {
    if (k == 0 or n == 0) return;

    const actual_k = if (k > n) n else k;

    // Use reservoir sampling for efficiency when k is small relative to n
    // For simplicity, we'll use selection sampling

    // Initialize with first k indices
    for (0..actual_k) |i| {
        indices[i] = i;
    }

    // Reservoir sampling: for each element after k, maybe replace one
    var i: usize = actual_k;
    while (i < n) : (i += 1) {
        const j = next_u64() % (i + 1);
        if (j < actual_k) {
            indices[@intCast(j)] = i;
        }
    }

    // Shuffle to randomize order
    random_shuffle_indices(indices, actual_k);
}

// Tests
test "random in range" {
    random_seed(12345);
    for (0..100) |_| {
        const r = random_random();
        try std.testing.expect(r >= 0.0 and r < 1.0);
    }
}

test "randint in range" {
    random_seed(12345);
    for (0..100) |_| {
        const r = random_randint(5, 10);
        try std.testing.expect(r >= 5 and r <= 10);
    }
}

test "shuffle" {
    random_seed(12345);
    var indices = [_]usize{ 0, 1, 2, 3, 4 };
    random_shuffle_indices(&indices, 5);

    // Check all indices are still present (just reordered)
    var seen = [_]bool{ false, false, false, false, false };
    for (indices) |idx| {
        seen[idx] = true;
    }
    for (seen) |s| {
        try std.testing.expect(s);
    }
}

test "sample" {
    random_seed(12345);
    var indices: [3]usize = undefined;
    random_sample_indices(&indices, 3, 10);

    // Check all indices are in range and unique
    for (indices) |idx| {
        try std.testing.expect(idx < 10);
    }
    try std.testing.expect(indices[0] != indices[1]);
    try std.testing.expect(indices[1] != indices[2]);
    try std.testing.expect(indices[0] != indices[2]);
}
