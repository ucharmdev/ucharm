const std = @import("std");
const math = std.math;

// Statistics module - provides statistical functions
// mean, median, mode, stdev, variance, etc.

/// Calculate the arithmetic mean of an array of floats
pub export fn stats_mean(data: [*]const f64, len: usize) f64 {
    if (len == 0) return 0.0;

    var sum: f64 = 0.0;
    for (data[0..len]) |v| {
        sum += v;
    }
    return sum / @as(f64, @floatFromInt(len));
}

/// Calculate the median (middle value) of an array
/// Note: This sorts a copy of the data
pub export fn stats_median(data: [*]const f64, len: usize, scratch: [*]f64) f64 {
    if (len == 0) return 0.0;

    // Copy to scratch buffer
    @memcpy(scratch[0..len], data[0..len]);

    // Sort the scratch buffer
    std.mem.sort(f64, scratch[0..len], {}, struct {
        fn cmp(_: void, a: f64, b: f64) bool {
            return a < b;
        }
    }.cmp);

    // Find median
    if (len % 2 == 1) {
        return scratch[len / 2];
    } else {
        return (scratch[len / 2 - 1] + scratch[len / 2]) / 2.0;
    }
}

/// Calculate population variance
pub export fn stats_pvariance(data: [*]const f64, len: usize) f64 {
    if (len == 0) return 0.0;

    const m = stats_mean(data, len);
    var sum_sq: f64 = 0.0;

    for (data[0..len]) |v| {
        const diff = v - m;
        sum_sq += diff * diff;
    }

    return sum_sq / @as(f64, @floatFromInt(len));
}

/// Calculate sample variance (with Bessel's correction)
pub export fn stats_variance(data: [*]const f64, len: usize) f64 {
    if (len < 2) return 0.0;

    const m = stats_mean(data, len);
    var sum_sq: f64 = 0.0;

    for (data[0..len]) |v| {
        const diff = v - m;
        sum_sq += diff * diff;
    }

    return sum_sq / @as(f64, @floatFromInt(len - 1));
}

/// Calculate population standard deviation
pub export fn stats_pstdev(data: [*]const f64, len: usize) f64 {
    return @sqrt(stats_pvariance(data, len));
}

/// Calculate sample standard deviation
pub export fn stats_stdev(data: [*]const f64, len: usize) f64 {
    return @sqrt(stats_variance(data, len));
}

/// Calculate the sum of values
pub export fn stats_sum(data: [*]const f64, len: usize) f64 {
    var sum: f64 = 0.0;
    for (data[0..len]) |v| {
        sum += v;
    }
    return sum;
}

/// Find minimum value
pub export fn stats_min(data: [*]const f64, len: usize) f64 {
    if (len == 0) return 0.0;

    var min_val = data[0];
    for (data[1..len]) |v| {
        if (v < min_val) min_val = v;
    }
    return min_val;
}

/// Find maximum value
pub export fn stats_max(data: [*]const f64, len: usize) f64 {
    if (len == 0) return 0.0;

    var max_val = data[0];
    for (data[1..len]) |v| {
        if (v > max_val) max_val = v;
    }
    return max_val;
}

/// Calculate harmonic mean
pub export fn stats_harmonic_mean(data: [*]const f64, len: usize) f64 {
    if (len == 0) return 0.0;

    var sum_reciprocals: f64 = 0.0;
    for (data[0..len]) |v| {
        if (v <= 0.0) return 0.0; // Harmonic mean undefined for non-positive
        sum_reciprocals += 1.0 / v;
    }

    return @as(f64, @floatFromInt(len)) / sum_reciprocals;
}

/// Calculate geometric mean
pub export fn stats_geometric_mean(data: [*]const f64, len: usize) f64 {
    if (len == 0) return 0.0;

    var log_sum: f64 = 0.0;
    for (data[0..len]) |v| {
        if (v <= 0.0) return 0.0; // Geometric mean undefined for non-positive
        log_sum += @log(v);
    }

    return @exp(log_sum / @as(f64, @floatFromInt(len)));
}

/// Calculate quantile (0.0 to 1.0)
pub export fn stats_quantile(data: [*]const f64, len: usize, scratch: [*]f64, q: f64) f64 {
    if (len == 0) return 0.0;
    if (q <= 0.0) return stats_min(data, len);
    if (q >= 1.0) return stats_max(data, len);

    // Copy and sort
    @memcpy(scratch[0..len], data[0..len]);
    std.mem.sort(f64, scratch[0..len], {}, struct {
        fn cmp(_: void, a: f64, b: f64) bool {
            return a < b;
        }
    }.cmp);

    // Linear interpolation
    const idx = q * @as(f64, @floatFromInt(len - 1));
    const lower = @as(usize, @intFromFloat(@floor(idx)));
    const upper = @min(lower + 1, len - 1);
    const frac = idx - @floor(idx);

    return scratch[lower] * (1.0 - frac) + scratch[upper] * frac;
}

/// Linear regression: returns slope and intercept
/// y = slope * x + intercept
pub export fn stats_linear_regression(
    x: [*]const f64,
    y: [*]const f64,
    len: usize,
    slope: *f64,
    intercept: *f64,
) i32 {
    if (len < 2) return -1;

    const mean_x = stats_mean(x, len);
    const mean_y = stats_mean(y, len);

    var numerator: f64 = 0.0;
    var denominator: f64 = 0.0;

    for (0..len) |i| {
        const dx = x[i] - mean_x;
        const dy = y[i] - mean_y;
        numerator += dx * dy;
        denominator += dx * dx;
    }

    if (denominator == 0.0) return -1;

    slope.* = numerator / denominator;
    intercept.* = mean_y - slope.* * mean_x;

    return 0;
}

/// Calculate correlation coefficient (Pearson's r)
pub export fn stats_correlation(
    x: [*]const f64,
    y: [*]const f64,
    len: usize,
) f64 {
    if (len < 2) return 0.0;

    const mean_x = stats_mean(x, len);
    const mean_y = stats_mean(y, len);

    var sum_xy: f64 = 0.0;
    var sum_x2: f64 = 0.0;
    var sum_y2: f64 = 0.0;

    for (0..len) |i| {
        const dx = x[i] - mean_x;
        const dy = y[i] - mean_y;
        sum_xy += dx * dy;
        sum_x2 += dx * dx;
        sum_y2 += dy * dy;
    }

    const denom = @sqrt(sum_x2 * sum_y2);
    if (denom == 0.0) return 0.0;

    return sum_xy / denom;
}
