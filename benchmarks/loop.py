#!/usr/bin/env python3
"""Loop benchmark - tests interpreter overhead."""

total = 0
for i in range(1000000):
    total += i

print(f"sum(0..999999) = {total}")
