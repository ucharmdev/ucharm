#!/usr/bin/env python3
"""Fibonacci benchmark - tests compute performance."""


def fib(n):
    if n <= 1:
        return n
    return fib(n - 1) + fib(n - 2)


result = fib(30)
print(f"fib(30) = {result}")
