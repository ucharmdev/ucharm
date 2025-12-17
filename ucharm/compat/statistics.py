# ucharm/compat/statistics.py
"""
Pure Python implementation of statistics for MicroPython.

Provides basic statistical functions:
- mean: Arithmetic mean
- median: Median (middle value)
- median_low, median_high: Low/high median for even-length data
- mode: Most common value
- stdev: Sample standard deviation
- variance: Sample variance
- pstdev: Population standard deviation
- pvariance: Population variance
- geometric_mean: Geometric mean
- harmonic_mean: Harmonic mean
- fmean: Fast floating-point mean
- quantiles: Divide data into intervals
"""

import math


class StatisticsError(ValueError):
    """Statistics error."""

    pass


def _check_data(data):
    """Ensure data is non-empty."""
    data = list(data)
    if not data:
        raise StatisticsError("no data")
    return data


def mean(data):
    """
    Return the arithmetic mean of data.

    mean([1, 2, 3, 4]) -> 2.5

    Raises StatisticsError if data is empty.
    """
    data = _check_data(data)
    return sum(data) / len(data)


def fmean(data, weights=None):
    """
    Return the fast floating-point arithmetic mean of data.

    If weights are provided, compute a weighted average.
    """
    data = list(data)
    if not data:
        raise StatisticsError("fmean requires at least one data point")

    if weights is None:
        return sum(data) / len(data)

    weights = list(weights)
    if len(weights) != len(data):
        raise StatisticsError("weights and data must have the same length")

    total = sum(d * w for d, w in zip(data, weights))
    return total / sum(weights)


def geometric_mean(data):
    """
    Return the geometric mean of data.

    geometric_mean([1, 2, 4]) -> 2.0

    All values must be positive.
    """
    data = _check_data(data)

    # Use logarithms to avoid overflow
    log_sum = sum(math.log(x) for x in data)
    return math.exp(log_sum / len(data))


def harmonic_mean(data, weights=None):
    """
    Return the harmonic mean of data.

    harmonic_mean([1, 2, 4]) -> 1.714...

    All values must be positive.
    """
    data = _check_data(data)

    if weights is None:
        return len(data) / sum(1 / x for x in data)

    weights = list(weights)
    if len(weights) != len(data):
        raise StatisticsError("weights and data must have the same length")

    return sum(weights) / sum(w / x for x, w in zip(data, weights))


def median(data):
    """
    Return the median (middle value) of data.

    For odd-length data, returns the middle value.
    For even-length data, returns the average of the two middle values.

    median([1, 3, 5]) -> 3
    median([1, 3, 5, 7]) -> 4.0
    """
    data = _check_data(data)
    data = sorted(data)
    n = len(data)

    if n % 2 == 1:
        return data[n // 2]
    else:
        i = n // 2
        return (data[i - 1] + data[i]) / 2


def median_low(data):
    """
    Return the low median of data.

    For odd-length data, returns the middle value.
    For even-length data, returns the lower of the two middle values.

    median_low([1, 3, 5, 7]) -> 3
    """
    data = _check_data(data)
    data = sorted(data)
    n = len(data)

    if n % 2 == 1:
        return data[n // 2]
    else:
        return data[n // 2 - 1]


def median_high(data):
    """
    Return the high median of data.

    For odd-length data, returns the middle value.
    For even-length data, returns the higher of the two middle values.

    median_high([1, 3, 5, 7]) -> 5
    """
    data = _check_data(data)
    data = sorted(data)
    n = len(data)

    return data[n // 2]


def median_grouped(data, interval=1):
    """
    Return the median of grouped continuous data.

    Uses interpolation assuming data is grouped in intervals.
    """
    data = _check_data(data)
    data = sorted(data)
    n = len(data)

    if n == 1:
        return data[0]

    # Find the median interval
    x = data[n // 2]

    # Count values in the median interval
    L = x - interval / 2  # Lower boundary

    # Count values below L and in the interval
    cf = sum(1 for d in data if d < L)
    f = sum(1 for d in data if L <= d < L + interval)

    if f == 0:
        return x

    return L + interval * (n / 2 - cf) / f


def mode(data):
    """
    Return the most common value in data.

    mode([1, 1, 2, 3, 3, 3]) -> 3

    Raises StatisticsError if there is no unique mode.
    """
    data = _check_data(data)

    # Count occurrences
    counts = {}
    for x in data:
        counts[x] = counts.get(x, 0) + 1

    # Find maximum count
    max_count = max(counts.values())

    # Find all values with max count
    modes = [k for k, v in counts.items() if v == max_count]

    if len(modes) > 1:
        # Return the first mode (as of Python 3.8+)
        return min(modes)

    return modes[0]


def multimode(data):
    """
    Return a list of the most common values.

    multimode([1, 1, 2, 2, 3]) -> [1, 2]
    """
    data = _check_data(data)

    counts = {}
    for x in data:
        counts[x] = counts.get(x, 0) + 1

    max_count = max(counts.values())
    return [k for k, v in counts.items() if v == max_count]


def _ss(data, c=None):
    """Return sum of squared deviations from c (or mean if c is None)."""
    data = list(data)
    if c is None:
        c = mean(data)
    return sum((x - c) ** 2 for x in data)


def variance(data, xbar=None):
    """
    Return the sample variance of data.

    variance([1, 2, 3, 4, 5]) -> 2.5

    Uses N-1 in the denominator (Bessel's correction).
    """
    data = _check_data(data)
    n = len(data)

    if n < 2:
        raise StatisticsError("variance requires at least two data points")

    return _ss(data, xbar) / (n - 1)


def pvariance(data, mu=None):
    """
    Return the population variance of data.

    pvariance([1, 2, 3, 4, 5]) -> 2.0

    Uses N in the denominator.
    """
    data = _check_data(data)
    return _ss(data, mu) / len(data)


def stdev(data, xbar=None):
    """
    Return the sample standard deviation of data.

    stdev([1, 2, 3, 4, 5]) -> 1.5811...
    """
    return math.sqrt(variance(data, xbar))


def pstdev(data, mu=None):
    """
    Return the population standard deviation of data.

    pstdev([1, 2, 3, 4, 5]) -> 1.4142...
    """
    return math.sqrt(pvariance(data, mu))


def quantiles(data, n=4, method="exclusive"):
    """
    Divide data into n equal intervals and return the cut points.

    quantiles([1, 2, 3, 4, 5], n=4) -> [1.5, 3.0, 4.5]

    Args:
        data: Numeric data
        n: Number of quantiles (default 4 for quartiles)
        method: 'exclusive' (default) or 'inclusive'
    """
    data = sorted(_check_data(data))
    m = len(data)

    if m < 2:
        raise StatisticsError("quantiles requires at least two data points")

    if n < 1:
        raise StatisticsError("n must be at least 1")

    result = []

    for i in range(1, n):
        if method == "inclusive":
            # R-7 method
            j = i * (m - 1) / n
            idx = int(j)
            delta = j - idx

            if idx + 1 < m:
                q = data[idx] + delta * (data[idx + 1] - data[idx])
            else:
                q = data[idx]
        else:
            # R-6 method (exclusive)
            j = i * (m + 1) / n
            idx = int(j)
            delta = j - idx

            if idx < 1:
                q = data[0]
            elif idx >= m:
                q = data[m - 1]
            else:
                q = data[idx - 1] + delta * (data[idx] - data[idx - 1])

        result.append(q)

    return result


def covariance(x, y):
    """
    Return the sample covariance of two inputs.
    """
    x = list(x)
    y = list(y)

    if len(x) != len(y):
        raise StatisticsError("covariance requires equal-length inputs")

    n = len(x)
    if n < 2:
        raise StatisticsError("covariance requires at least two data points")

    xbar = mean(x)
    ybar = mean(y)

    return sum((xi - xbar) * (yi - ybar) for xi, yi in zip(x, y)) / (n - 1)


def correlation(x, y):
    """
    Return the Pearson correlation coefficient of two inputs.

    Returns a value between -1 and 1.
    """
    x = list(x)
    y = list(y)

    if len(x) != len(y):
        raise StatisticsError("correlation requires equal-length inputs")

    n = len(x)
    if n < 2:
        raise StatisticsError("correlation requires at least two data points")

    xbar = mean(x)
    ybar = mean(y)

    cov = sum((xi - xbar) * (yi - ybar) for xi, yi in zip(x, y))
    sx = math.sqrt(sum((xi - xbar) ** 2 for xi in x))
    sy = math.sqrt(sum((yi - ybar) ** 2 for yi in y))

    if sx == 0 or sy == 0:
        raise StatisticsError("correlation requires non-zero standard deviation")

    return cov / (sx * sy)


def linear_regression(x, y):
    """
    Return the slope and intercept of simple linear regression.

    slope, intercept = linear_regression(x, y)
    """
    x = list(x)
    y = list(y)

    if len(x) != len(y):
        raise StatisticsError("linear_regression requires equal-length inputs")

    n = len(x)
    if n < 2:
        raise StatisticsError("linear_regression requires at least two data points")

    xbar = mean(x)
    ybar = mean(y)

    numerator = sum((xi - xbar) * (yi - ybar) for xi, yi in zip(x, y))
    denominator = sum((xi - xbar) ** 2 for xi in x)

    if denominator == 0:
        raise StatisticsError("x has zero variance")

    slope = numerator / denominator
    intercept = ybar - slope * xbar

    # Return as a simple class with slope and intercept attributes
    class LinearRegression:
        pass

    result = LinearRegression()
    result.slope = slope
    result.intercept = intercept

    return result
