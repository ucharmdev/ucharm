// json.zig - Fast JSON parsing and stringification
// Provides C-ABI compatible functions for JSON operations

const std = @import("std");

// ============================================================================
// Allocator for JSON operations
// ============================================================================

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Static buffer for string results
const MAX_RESULT_SIZE = 65536; // 64KB max result
var result_buffer: [MAX_RESULT_SIZE]u8 = undefined;

// ============================================================================
// Helper: Write JSON value to buffer
// ============================================================================

fn writeJsonValue(value: std.json.Value, pretty: bool) ?[*:0]const u8 {
    var out: std.io.Writer = .fixed(&result_buffer);
    const opts: std.json.Stringify.Options = if (pretty) .{ .whitespace = .indent_2 } else .{};

    std.json.Stringify.value(value, opts, &out) catch return null;

    // Find how much was written by checking the buffer position
    const len = out.end;
    if (len < result_buffer.len) {
        result_buffer[len] = 0;
    }
    return @ptrCast(&result_buffer);
}

fn writeStringJson(str: []const u8) ?[*:0]const u8 {
    var out: std.io.Writer = .fixed(&result_buffer);

    std.json.Stringify.value(str, .{}, &out) catch return null;

    const len = out.end;
    if (len < result_buffer.len) {
        result_buffer[len] = 0;
    }
    return @ptrCast(&result_buffer);
}

// ============================================================================
// JSON Parsing
// ============================================================================

/// Parse a JSON string and return the normalized result.
/// Returns null if parsing fails.
pub export fn json_parse(input: [*:0]const u8) ?[*:0]const u8 {
    const slice = std.mem.span(input);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return null;
    };
    defer parsed.deinit();
    return writeJsonValue(parsed.value, false);
}

/// Check if a string is valid JSON.
pub export fn json_is_valid(input: [*:0]const u8) bool {
    const slice = std.mem.span(input);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return false;
    };
    parsed.deinit();
    return true;
}

/// Get the type of a JSON value.
/// Returns: "null", "bool", "number", "string", "array", "object", or "invalid"
pub export fn json_typeof(input: [*:0]const u8) [*:0]const u8 {
    const slice = std.mem.span(input);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return "invalid";
    };
    defer parsed.deinit();

    return switch (parsed.value) {
        .null => "null",
        .bool => "bool",
        .integer, .float => "number",
        .string => "string",
        .array => "array",
        .object => "object",
        else => "invalid",
    };
}

// ============================================================================
// JSON Value Access
// ============================================================================

/// Get a string value from JSON. Returns null if not a string.
pub export fn json_get_string(input: [*:0]const u8) ?[*:0]const u8 {
    const slice = std.mem.span(input);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return null;
    };
    defer parsed.deinit();

    switch (parsed.value) {
        .string => |s| {
            const len = @min(s.len, result_buffer.len - 1);
            @memcpy(result_buffer[0..len], s[0..len]);
            result_buffer[len] = 0;
            return @ptrCast(&result_buffer);
        },
        else => return null,
    }
}

/// Get an integer value from JSON. Returns default_val if not a number.
pub export fn json_get_int(input: [*:0]const u8, default_val: i64) i64 {
    const slice = std.mem.span(input);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return default_val;
    };
    defer parsed.deinit();

    return switch (parsed.value) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => default_val,
    };
}

/// Get a float value from JSON. Returns default_val if not a number.
pub export fn json_get_float(input: [*:0]const u8, default_val: f64) f64 {
    const slice = std.mem.span(input);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return default_val;
    };
    defer parsed.deinit();

    return switch (parsed.value) {
        .float => |f| f,
        .integer => |i| @floatFromInt(i),
        else => default_val,
    };
}

/// Get a boolean value from JSON. Returns default_val if not a bool.
pub export fn json_get_bool(input: [*:0]const u8, default_val: bool) bool {
    const slice = std.mem.span(input);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return default_val;
    };
    defer parsed.deinit();

    return switch (parsed.value) {
        .bool => |b| b,
        else => default_val,
    };
}

/// Check if JSON value is null.
pub export fn json_is_null(input: [*:0]const u8) bool {
    const slice = std.mem.span(input);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return false;
    };
    defer parsed.deinit();

    return parsed.value == .null;
}

// ============================================================================
// JSON Object Access
// ============================================================================

/// Get a value from a JSON object by key.
/// Returns the JSON string representation of the value, or null if not found.
pub export fn json_get(input: [*:0]const u8, key: [*:0]const u8) ?[*:0]const u8 {
    const slice = std.mem.span(input);
    const key_slice = std.mem.span(key);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return null;
    };
    defer parsed.deinit();

    switch (parsed.value) {
        .object => |obj| {
            if (obj.get(key_slice)) |val| {
                return writeJsonValue(val, false);
            }
        },
        else => {},
    }
    return null;
}

/// Check if a JSON object has a key.
pub export fn json_has_key(input: [*:0]const u8, key: [*:0]const u8) bool {
    const slice = std.mem.span(input);
    const key_slice = std.mem.span(key);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return false;
    };
    defer parsed.deinit();

    switch (parsed.value) {
        .object => |obj| {
            return obj.contains(key_slice);
        },
        else => return false,
    }
}

/// Get the number of keys in a JSON object, or elements in an array.
pub export fn json_len(input: [*:0]const u8) i64 {
    const slice = std.mem.span(input);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return -1;
    };
    defer parsed.deinit();

    return switch (parsed.value) {
        .object => |obj| @intCast(obj.count()),
        .array => |arr| @intCast(arr.items.len),
        .string => |s| @intCast(s.len),
        else => -1,
    };
}

// ============================================================================
// JSON Array Access
// ============================================================================

/// Get an element from a JSON array by index.
/// Returns the JSON string representation of the value, or null if not found.
pub export fn json_get_index(input: [*:0]const u8, index: usize) ?[*:0]const u8 {
    const slice = std.mem.span(input);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return null;
    };
    defer parsed.deinit();

    switch (parsed.value) {
        .array => |arr| {
            if (index < arr.items.len) {
                return writeJsonValue(arr.items[index], false);
            }
        },
        else => {},
    }
    return null;
}

// ============================================================================
// JSON Stringify
// ============================================================================

/// Stringify a string to JSON (adds quotes and escapes).
pub export fn json_stringify_string(input: [*:0]const u8) [*:0]const u8 {
    const slice = std.mem.span(input);
    const result = writeStringJson(slice);
    if (result) |r| {
        return r;
    }
    result_buffer[0] = 0;
    return @ptrCast(&result_buffer);
}

pub export fn json_stringify_int(value: i64) [*:0]const u8 {
    var out: std.io.Writer = .fixed(&result_buffer);
    out.print("{d}", .{value}) catch {
        result_buffer[0] = '0';
        result_buffer[1] = 0;
        return @ptrCast(&result_buffer);
    };
    const len = out.end;
    result_buffer[len] = 0;
    return @ptrCast(&result_buffer);
}

pub export fn json_stringify_float(value: f64) [*:0]const u8 {
    var out: std.io.Writer = .fixed(&result_buffer);
    out.print("{d}", .{value}) catch {
        result_buffer[0] = '0';
        result_buffer[1] = 0;
        return @ptrCast(&result_buffer);
    };
    const len = out.end;
    result_buffer[len] = 0;
    return @ptrCast(&result_buffer);
}

pub export fn json_stringify_bool(value: bool) [*:0]const u8 {
    if (value) {
        return "true";
    } else {
        return "false";
    }
}

pub export fn json_stringify_null() [*:0]const u8 {
    return "null";
}

// ============================================================================
// JSON Pretty Print
// ============================================================================

/// Pretty print JSON with indentation.
pub export fn json_pretty(input: [*:0]const u8) ?[*:0]const u8 {
    const slice = std.mem.span(input);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return null;
    };
    defer parsed.deinit();
    return writeJsonValue(parsed.value, true);
}

/// Minify JSON (remove whitespace).
pub export fn json_minify(input: [*:0]const u8) ?[*:0]const u8 {
    return json_parse(input);
}

// ============================================================================
// JSON Path Access (simple dot notation)
// ============================================================================

/// Get a nested value using dot notation path.
/// Example: json_path('{"a":{"b":1}}', "a.b") returns "1"
pub export fn json_path(input: [*:0]const u8, path_str: [*:0]const u8) ?[*:0]const u8 {
    const slice = std.mem.span(input);
    const path = std.mem.span(path_str);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, slice, .{}) catch {
        return null;
    };
    defer parsed.deinit();

    var current = parsed.value;

    // Split path by dots and traverse
    var iter = std.mem.splitScalar(u8, path, '.');
    while (iter.next()) |key| {
        switch (current) {
            .object => |obj| {
                if (obj.get(key)) |val| {
                    current = val;
                } else {
                    return null;
                }
            },
            .array => |arr| {
                const index = std.fmt.parseInt(usize, key, 10) catch {
                    return null;
                };
                if (index < arr.items.len) {
                    current = arr.items[index];
                } else {
                    return null;
                }
            },
            else => return null,
        }
    }

    return writeJsonValue(current, false);
}

// ============================================================================
// Tests
// ============================================================================

test "json_is_valid" {
    try std.testing.expect(json_is_valid("{}"));
    try std.testing.expect(json_is_valid("[]"));
    try std.testing.expect(json_is_valid("null"));
    try std.testing.expect(json_is_valid("true"));
    try std.testing.expect(json_is_valid("false"));
    try std.testing.expect(json_is_valid("123"));
    try std.testing.expect(json_is_valid("\"hello\""));
    try std.testing.expect(json_is_valid("{\"key\": \"value\"}"));
    try std.testing.expect(!json_is_valid("{invalid}"));
    try std.testing.expect(!json_is_valid(""));
    try std.testing.expect(!json_is_valid("{"));
}

test "json_typeof" {
    try std.testing.expectEqualStrings("null", std.mem.span(json_typeof("null")));
    try std.testing.expectEqualStrings("bool", std.mem.span(json_typeof("true")));
    try std.testing.expectEqualStrings("bool", std.mem.span(json_typeof("false")));
    try std.testing.expectEqualStrings("number", std.mem.span(json_typeof("123")));
    try std.testing.expectEqualStrings("number", std.mem.span(json_typeof("3.14")));
    try std.testing.expectEqualStrings("string", std.mem.span(json_typeof("\"hello\"")));
    try std.testing.expectEqualStrings("array", std.mem.span(json_typeof("[1,2,3]")));
    try std.testing.expectEqualStrings("object", std.mem.span(json_typeof("{\"a\":1}")));
    try std.testing.expectEqualStrings("invalid", std.mem.span(json_typeof("{")));
}

test "json_get_int" {
    try std.testing.expectEqual(@as(i64, 42), json_get_int("42", 0));
    try std.testing.expectEqual(@as(i64, -10), json_get_int("-10", 0));
    try std.testing.expectEqual(@as(i64, 3), json_get_int("3.7", 0));
    try std.testing.expectEqual(@as(i64, 99), json_get_int("\"not a number\"", 99));
}

test "json_get_float" {
    try std.testing.expectEqual(@as(f64, 3.14), json_get_float("3.14", 0));
    try std.testing.expectEqual(@as(f64, 42.0), json_get_float("42", 0));
    try std.testing.expectEqual(@as(f64, 99.9), json_get_float("\"not a number\"", 99.9));
}

test "json_get_bool" {
    try std.testing.expectEqual(true, json_get_bool("true", false));
    try std.testing.expectEqual(false, json_get_bool("false", true));
    try std.testing.expectEqual(true, json_get_bool("123", true)); // not a bool, use default
}

test "json_is_null" {
    try std.testing.expect(json_is_null("null"));
    try std.testing.expect(!json_is_null("false"));
    try std.testing.expect(!json_is_null("0"));
    try std.testing.expect(!json_is_null("\"null\""));
}

test "json_get_string" {
    const result = json_get_string("\"hello world\"");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("hello world", std.mem.span(result.?));

    try std.testing.expect(json_get_string("123") == null);
    try std.testing.expect(json_get_string("null") == null);
}

test "json_get" {
    const result = json_get("{\"name\": \"Alice\", \"age\": 30}", "name");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("\"Alice\"", std.mem.span(result.?));

    const age = json_get("{\"name\": \"Alice\", \"age\": 30}", "age");
    try std.testing.expect(age != null);
    try std.testing.expectEqualStrings("30", std.mem.span(age.?));

    try std.testing.expect(json_get("{\"name\": \"Alice\"}", "missing") == null);
}

test "json_has_key" {
    try std.testing.expect(json_has_key("{\"name\": \"Alice\"}", "name"));
    try std.testing.expect(!json_has_key("{\"name\": \"Alice\"}", "age"));
    try std.testing.expect(!json_has_key("[]", "name"));
}

test "json_len" {
    try std.testing.expectEqual(@as(i64, 3), json_len("[1,2,3]"));
    try std.testing.expectEqual(@as(i64, 2), json_len("{\"a\":1,\"b\":2}"));
    try std.testing.expectEqual(@as(i64, 5), json_len("\"hello\""));
    try std.testing.expectEqual(@as(i64, -1), json_len("123"));
}

test "json_get_index" {
    const first = json_get_index("[\"a\",\"b\",\"c\"]", 0);
    try std.testing.expect(first != null);
    try std.testing.expectEqualStrings("\"a\"", std.mem.span(first.?));

    const second = json_get_index("[1, 2, 3]", 1);
    try std.testing.expect(second != null);
    try std.testing.expectEqualStrings("2", std.mem.span(second.?));

    try std.testing.expect(json_get_index("[1,2,3]", 10) == null);
}

test "json_stringify_string" {
    const result = json_stringify_string("hello");
    try std.testing.expectEqualStrings("\"hello\"", std.mem.span(result));

    const escaped = json_stringify_string("say \"hi\"");
    try std.testing.expectEqualStrings("\"say \\\"hi\\\"\"", std.mem.span(escaped));
}

test "json_stringify_int" {
    try std.testing.expectEqualStrings("42", std.mem.span(json_stringify_int(42)));
    try std.testing.expectEqualStrings("-10", std.mem.span(json_stringify_int(-10)));
}

test "json_stringify_bool" {
    try std.testing.expectEqualStrings("true", std.mem.span(json_stringify_bool(true)));
    try std.testing.expectEqualStrings("false", std.mem.span(json_stringify_bool(false)));
}

test "json_stringify_null" {
    try std.testing.expectEqualStrings("null", std.mem.span(json_stringify_null()));
}

test "json_path" {
    const nested = "{\"user\": {\"name\": \"Alice\", \"address\": {\"city\": \"NYC\"}}}";

    const name = json_path(nested, "user.name");
    try std.testing.expect(name != null);
    try std.testing.expectEqualStrings("\"Alice\"", std.mem.span(name.?));

    const city = json_path(nested, "user.address.city");
    try std.testing.expect(city != null);
    try std.testing.expectEqualStrings("\"NYC\"", std.mem.span(city.?));

    try std.testing.expect(json_path(nested, "user.missing") == null);
}

test "json_path with array" {
    const data = "{\"items\": [\"a\", \"b\", \"c\"]}";

    const first = json_path(data, "items.0");
    try std.testing.expect(first != null);
    try std.testing.expectEqualStrings("\"a\"", std.mem.span(first.?));

    const third = json_path(data, "items.2");
    try std.testing.expect(third != null);
    try std.testing.expectEqualStrings("\"c\"", std.mem.span(third.?));
}

test "json_pretty" {
    const input = "{\"a\":1}";
    const result = json_pretty(input);
    try std.testing.expect(result != null);
    // Pretty print should add newlines/indentation
    try std.testing.expect(std.mem.indexOf(u8, std.mem.span(result.?), "\n") != null);
}

test "json_minify" {
    const input = "{ \"a\" : 1 , \"b\" : 2 }";
    const result = json_minify(input);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("{\"a\":1,\"b\":2}", std.mem.span(result.?));
}
