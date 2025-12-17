/*
 * modstatistics - Native statistics module for microcharm
 * 
 * This module bridges Zig's statistics implementation to MicroPython.
 * 
 * Usage in Python:
 *   import statistics
 *   statistics.mean([1, 2, 3, 4, 5])
 *   statistics.stdev([1, 2, 3, 4, 5])
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>
#include <stdlib.h>

// External Zig functions
extern double stats_mean(const double *data, size_t len);
extern double stats_median(const double *data, size_t len, double *scratch);
extern double stats_variance(const double *data, size_t len);
extern double stats_pvariance(const double *data, size_t len);
extern double stats_stdev(const double *data, size_t len);
extern double stats_pstdev(const double *data, size_t len);
extern double stats_sum(const double *data, size_t len);
extern double stats_min(const double *data, size_t len);
extern double stats_max(const double *data, size_t len);
extern double stats_harmonic_mean(const double *data, size_t len);
extern double stats_geometric_mean(const double *data, size_t len);
extern double stats_quantile(const double *data, size_t len, double *scratch, double q);
extern int stats_linear_regression(const double *x, const double *y, size_t len,
                                   double *slope, double *intercept);
extern double stats_correlation(const double *x, const double *y, size_t len);

// Helper: convert Python list to double array
static double *list_to_doubles(mp_obj_t list, size_t *out_len) {
    size_t len;
    mp_obj_t *items;
    mp_obj_get_array(list, &len, &items);
    
    double *data = mpy_alloc_doubles(len);
    for (size_t i = 0; i < len; i++) {
        data[i] = mp_obj_get_float(items[i]);
    }
    
    *out_len = len;
    return data;
}

// ============================================================================
// Basic statistics
// ============================================================================

// statistics.mean(data) -> float
MPY_FUNC_1(statistics, mean) {
    size_t len;
    double *data = list_to_doubles(arg0, &len);
    if (len == 0) {
        mpy_free_doubles(data, len);
        mp_raise_ValueError(MP_ERROR_TEXT("mean requires at least one data point"));
    }
    double result = stats_mean(data, len);
    mpy_free_doubles(data, len);
    return mp_obj_new_float(result);
}
MPY_FUNC_OBJ_1(statistics, mean);

// statistics.fmean(data) -> float (same as mean for us)
MPY_FUNC_1(statistics, fmean) {
    return mod_statistics_mean(arg0);
}
MPY_FUNC_OBJ_1(statistics, fmean);

// statistics.median(data) -> float
MPY_FUNC_1(statistics, median) {
    size_t len;
    double *data = list_to_doubles(arg0, &len);
    if (len == 0) {
        mpy_free_doubles(data, len);
        mp_raise_ValueError(MP_ERROR_TEXT("median requires at least one data point"));
    }
    double *scratch = mpy_alloc_doubles(len);
    double result = stats_median(data, len, scratch);
    mpy_free_doubles(scratch, len);
    mpy_free_doubles(data, len);
    return mp_obj_new_float(result);
}
MPY_FUNC_OBJ_1(statistics, median);

// statistics.median_low(data) -> float
MPY_FUNC_1(statistics, median_low) {
    // For simplicity, same as median
    return mod_statistics_median(arg0);
}
MPY_FUNC_OBJ_1(statistics, median_low);

// statistics.median_high(data) -> float
MPY_FUNC_1(statistics, median_high) {
    // For simplicity, same as median
    return mod_statistics_median(arg0);
}
MPY_FUNC_OBJ_1(statistics, median_high);

// ============================================================================
// Variance and standard deviation
// ============================================================================

// statistics.variance(data) -> float (sample variance)
MPY_FUNC_1(statistics, variance) {
    size_t len;
    double *data = list_to_doubles(arg0, &len);
    if (len < 2) {
        mpy_free_doubles(data, len);
        mp_raise_ValueError(MP_ERROR_TEXT("variance requires at least two data points"));
    }
    double result = stats_variance(data, len);
    mpy_free_doubles(data, len);
    return mp_obj_new_float(result);
}
MPY_FUNC_OBJ_1(statistics, variance);

// statistics.pvariance(data) -> float (population variance)
MPY_FUNC_1(statistics, pvariance) {
    size_t len;
    double *data = list_to_doubles(arg0, &len);
    if (len == 0) {
        mpy_free_doubles(data, len);
        mp_raise_ValueError(MP_ERROR_TEXT("pvariance requires at least one data point"));
    }
    double result = stats_pvariance(data, len);
    mpy_free_doubles(data, len);
    return mp_obj_new_float(result);
}
MPY_FUNC_OBJ_1(statistics, pvariance);

// statistics.stdev(data) -> float (sample standard deviation)
MPY_FUNC_1(statistics, stdev) {
    size_t len;
    double *data = list_to_doubles(arg0, &len);
    if (len < 2) {
        mpy_free_doubles(data, len);
        mp_raise_ValueError(MP_ERROR_TEXT("stdev requires at least two data points"));
    }
    double result = stats_stdev(data, len);
    mpy_free_doubles(data, len);
    return mp_obj_new_float(result);
}
MPY_FUNC_OBJ_1(statistics, stdev);

// statistics.pstdev(data) -> float (population standard deviation)
MPY_FUNC_1(statistics, pstdev) {
    size_t len;
    double *data = list_to_doubles(arg0, &len);
    if (len == 0) {
        mpy_free_doubles(data, len);
        mp_raise_ValueError(MP_ERROR_TEXT("pstdev requires at least one data point"));
    }
    double result = stats_pstdev(data, len);
    mpy_free_doubles(data, len);
    return mp_obj_new_float(result);
}
MPY_FUNC_OBJ_1(statistics, pstdev);

// ============================================================================
// Other means
// ============================================================================

// statistics.harmonic_mean(data) -> float
MPY_FUNC_1(statistics, harmonic_mean) {
    size_t len;
    double *data = list_to_doubles(arg0, &len);
    if (len == 0) {
        mpy_free_doubles(data, len);
        mp_raise_ValueError(MP_ERROR_TEXT("harmonic_mean requires at least one data point"));
    }
    double result = stats_harmonic_mean(data, len);
    mpy_free_doubles(data, len);
    if (result == 0.0) {
        mp_raise_ValueError(MP_ERROR_TEXT("harmonic_mean requires positive values"));
    }
    return mp_obj_new_float(result);
}
MPY_FUNC_OBJ_1(statistics, harmonic_mean);

// statistics.geometric_mean(data) -> float
MPY_FUNC_1(statistics, geometric_mean) {
    size_t len;
    double *data = list_to_doubles(arg0, &len);
    if (len == 0) {
        mpy_free_doubles(data, len);
        mp_raise_ValueError(MP_ERROR_TEXT("geometric_mean requires at least one data point"));
    }
    double result = stats_geometric_mean(data, len);
    mpy_free_doubles(data, len);
    if (result == 0.0) {
        mp_raise_ValueError(MP_ERROR_TEXT("geometric_mean requires positive values"));
    }
    return mp_obj_new_float(result);
}
MPY_FUNC_OBJ_1(statistics, geometric_mean);

// ============================================================================
// Quantiles
// ============================================================================

// statistics.quantiles(data, n=4) -> list of cut points
MPY_FUNC_VAR(statistics, quantiles, 1, 2) {
    size_t len;
    double *data = list_to_doubles(args[0], &len);
    if (len < 2) {
        mpy_free_doubles(data, len);
        mp_raise_ValueError(MP_ERROR_TEXT("quantiles requires at least two data points"));
    }
    
    int n = 4;  // Default quartiles
    if (n_args >= 2) {
        n = mpy_int(args[1]);
    }
    
    double *scratch = mpy_alloc_doubles(len);
    
    // Create result list with n-1 cut points
    mp_obj_t result = mp_obj_new_list(0, NULL);
    for (int i = 1; i < n; i++) {
        double q = (double)i / n;
        double val = stats_quantile(data, len, scratch, q);
        mp_obj_list_append(result, mp_obj_new_float(val));
    }
    
    mpy_free_doubles(scratch, len);
    mpy_free_doubles(data, len);
    return result;
}
MPY_FUNC_OBJ_VAR(statistics, quantiles, 1, 2);

// ============================================================================
// Linear regression
// ============================================================================

// statistics.linear_regression(x, y) -> (slope, intercept)
MPY_FUNC_2(statistics, linear_regression) {
    size_t x_len, y_len;
    double *x = list_to_doubles(arg0, &x_len);
    double *y = list_to_doubles(arg1, &y_len);
    
    if (x_len != y_len) {
        mpy_free_doubles(x, x_len);
        mpy_free_doubles(y, y_len);
        mp_raise_ValueError(MP_ERROR_TEXT("x and y must have the same length"));
    }
    
    if (x_len < 2) {
        mpy_free_doubles(x, x_len);
        mpy_free_doubles(y, y_len);
        mp_raise_ValueError(MP_ERROR_TEXT("linear_regression requires at least two data points"));
    }
    
    double slope, intercept;
    int result = stats_linear_regression(x, y, x_len, &slope, &intercept);
    
    mpy_free_doubles(x, x_len);
    mpy_free_doubles(y, y_len);
    
    if (result < 0) {
        mp_raise_ValueError(MP_ERROR_TEXT("cannot compute linear regression"));
    }
    
    mp_obj_t items[2];
    items[0] = mp_obj_new_float(slope);
    items[1] = mp_obj_new_float(intercept);
    return mp_obj_new_tuple(2, items);
}
MPY_FUNC_OBJ_2(statistics, linear_regression);

// statistics.correlation(x, y) -> float
MPY_FUNC_2(statistics, correlation) {
    size_t x_len, y_len;
    double *x = list_to_doubles(arg0, &x_len);
    double *y = list_to_doubles(arg1, &y_len);
    
    if (x_len != y_len) {
        mpy_free_doubles(x, x_len);
        mpy_free_doubles(y, y_len);
        mp_raise_ValueError(MP_ERROR_TEXT("x and y must have the same length"));
    }
    
    double result = stats_correlation(x, y, x_len);
    
    mpy_free_doubles(x, x_len);
    mpy_free_doubles(y, y_len);
    
    return mp_obj_new_float(result);
}
MPY_FUNC_OBJ_2(statistics, correlation);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(statistics)
    MPY_MODULE_FUNC(statistics, mean)
    MPY_MODULE_FUNC(statistics, fmean)
    MPY_MODULE_FUNC(statistics, median)
    MPY_MODULE_FUNC(statistics, median_low)
    MPY_MODULE_FUNC(statistics, median_high)
    MPY_MODULE_FUNC(statistics, variance)
    MPY_MODULE_FUNC(statistics, pvariance)
    MPY_MODULE_FUNC(statistics, stdev)
    MPY_MODULE_FUNC(statistics, pstdev)
    MPY_MODULE_FUNC(statistics, harmonic_mean)
    MPY_MODULE_FUNC(statistics, geometric_mean)
    MPY_MODULE_FUNC(statistics, quantiles)
    MPY_MODULE_FUNC(statistics, linear_regression)
    MPY_MODULE_FUNC(statistics, correlation)
MPY_MODULE_END(statistics)
