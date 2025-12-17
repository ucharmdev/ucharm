#!/usr/bin/env python3
"""JSON parsing benchmark."""

import json

data = (
    '{"users": [{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}], "count": 2}'
)

for _ in range(10000):
    parsed = json.loads(data)
    _ = parsed["users"][0]["name"]

print("JSON parsed 10000 times")
