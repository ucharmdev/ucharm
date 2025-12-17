// csv.zig - Native CSV parsing for MicroPython
// Provides RFC 4180 compliant CSV parsing with high performance

const std = @import("std");

// CSV parser state
const ParseState = enum {
    field_start,
    in_field,
    in_quoted_field,
    quote_in_quoted,
};

// CSV parsing options
pub const CsvOptions = extern struct {
    delimiter: u8 = ',',
    quotechar: u8 = '"',
    doublequote: bool = true,
    skipinitialspace: bool = false,
    strict: bool = false,
};

// Result buffer for parsed fields
const MAX_FIELDS = 256;
const MAX_FIELD_LEN = 8192;

var field_buffer: [MAX_FIELDS][MAX_FIELD_LEN]u8 = undefined;
var field_lengths: [MAX_FIELDS]usize = undefined;
var field_count: usize = 0;

// Parse a single CSV line into fields
pub export fn csv_parse_line(
    line_ptr: [*]const u8,
    line_len: usize,
    delimiter: u8,
    quotechar: u8,
    doublequote: bool,
    skipinitialspace: bool,
) i32 {
    if (line_len == 0) {
        field_count = 0;
        return 0;
    }

    const line = line_ptr[0..line_len];
    var state = ParseState.field_start;
    var field_idx: usize = 0;
    var char_idx: usize = 0;

    var i: usize = 0;
    while (i < line.len) : (i += 1) {
        const c = line[i];

        switch (state) {
            .field_start => {
                if (c == quotechar) {
                    state = .in_quoted_field;
                } else if (c == delimiter) {
                    // Empty field
                    field_lengths[field_idx] = 0;
                    field_idx += 1;
                    if (field_idx >= MAX_FIELDS) {
                        return -1; // Too many fields
                    }
                    char_idx = 0;
                } else if (skipinitialspace and c == ' ') {
                    // Skip leading space
                } else {
                    // Regular character, start unquoted field
                    if (char_idx < MAX_FIELD_LEN) {
                        field_buffer[field_idx][char_idx] = c;
                        char_idx += 1;
                    }
                    state = .in_field;
                }
            },
            .in_field => {
                if (c == delimiter) {
                    // End of field
                    field_lengths[field_idx] = char_idx;
                    field_idx += 1;
                    if (field_idx >= MAX_FIELDS) {
                        return -1; // Too many fields
                    }
                    char_idx = 0;
                    state = .field_start;
                } else {
                    // Regular character
                    if (char_idx < MAX_FIELD_LEN) {
                        field_buffer[field_idx][char_idx] = c;
                        char_idx += 1;
                    }
                }
            },
            .in_quoted_field => {
                if (c == quotechar) {
                    state = .quote_in_quoted;
                } else {
                    // Regular character in quoted field
                    if (char_idx < MAX_FIELD_LEN) {
                        field_buffer[field_idx][char_idx] = c;
                        char_idx += 1;
                    }
                }
            },
            .quote_in_quoted => {
                if (c == quotechar and doublequote) {
                    // Escaped quote
                    if (char_idx < MAX_FIELD_LEN) {
                        field_buffer[field_idx][char_idx] = quotechar;
                        char_idx += 1;
                    }
                    state = .in_quoted_field;
                } else if (c == delimiter) {
                    // End of quoted field
                    field_lengths[field_idx] = char_idx;
                    field_idx += 1;
                    if (field_idx >= MAX_FIELDS) {
                        return -1; // Too many fields
                    }
                    char_idx = 0;
                    state = .field_start;
                } else {
                    // Character after closing quote (not delimiter)
                    // In non-strict mode, treat as part of field
                    if (char_idx < MAX_FIELD_LEN) {
                        field_buffer[field_idx][char_idx] = c;
                        char_idx += 1;
                    }
                    state = .in_field;
                }
            },
        }
    }

    // Handle last field
    if (state == .in_quoted_field) {
        // Unterminated quoted field - still save what we have
        field_lengths[field_idx] = char_idx;
        field_idx += 1;
    } else {
        field_lengths[field_idx] = char_idx;
        field_idx += 1;
    }

    field_count = field_idx;
    return @intCast(field_idx);
}

// Get the number of fields from last parse
pub export fn csv_get_field_count() usize {
    return field_count;
}

// Get a field from last parse
pub export fn csv_get_field(index: usize, out_ptr: [*]u8, out_max: usize) usize {
    if (index >= field_count) {
        return 0;
    }

    const len = field_lengths[index];
    const copy_len = @min(len, out_max);

    @memcpy(out_ptr[0..copy_len], field_buffer[index][0..copy_len]);

    return len;
}

// Get field pointer directly (for zero-copy access)
pub export fn csv_get_field_ptr(index: usize) ?[*]const u8 {
    if (index >= field_count) {
        return null;
    }
    return &field_buffer[index];
}

// Get field length
pub export fn csv_get_field_len(index: usize) usize {
    if (index >= field_count) {
        return 0;
    }
    return field_lengths[index];
}

// Format a value for CSV output (quote if necessary)
// Returns length of formatted output, or -1 if buffer too small
pub export fn csv_format_field(
    value_ptr: [*]const u8,
    value_len: usize,
    out_ptr: [*]u8,
    out_max: usize,
    delimiter: u8,
    quotechar: u8,
) i32 {
    if (value_len == 0) {
        return 0;
    }

    const value = value_ptr[0..value_len];

    // Check if quoting is needed
    var needs_quote = false;
    var quote_count: usize = 0;

    for (value) |c| {
        if (c == delimiter or c == '\n' or c == '\r') {
            needs_quote = true;
        } else if (c == quotechar) {
            needs_quote = true;
            quote_count += 1;
        }
    }

    if (!needs_quote) {
        // No quoting needed, just copy
        if (value_len > out_max) {
            return -1;
        }
        @memcpy(out_ptr[0..value_len], value);
        return @intCast(value_len);
    }

    // Need to quote: 2 for quotes + value_len + quote_count for escaped quotes
    const needed = 2 + value_len + quote_count;
    if (needed > out_max) {
        return -1;
    }

    var out_idx: usize = 0;
    out_ptr[out_idx] = quotechar;
    out_idx += 1;

    for (value) |c| {
        if (c == quotechar) {
            out_ptr[out_idx] = quotechar;
            out_idx += 1;
        }
        out_ptr[out_idx] = c;
        out_idx += 1;
    }

    out_ptr[out_idx] = quotechar;
    out_idx += 1;

    return @intCast(out_idx);
}

// Join fields into a CSV line
pub export fn csv_join_fields(
    field_ptrs: [*]const [*]const u8,
    field_lens: [*]const usize,
    num_fields: usize,
    out_ptr: [*]u8,
    out_max: usize,
    delimiter: u8,
    quotechar: u8,
) i32 {
    var out_idx: usize = 0;

    var i: usize = 0;
    while (i < num_fields) : (i += 1) {
        if (i > 0) {
            if (out_idx >= out_max) {
                return -1;
            }
            out_ptr[out_idx] = delimiter;
            out_idx += 1;
        }

        const result = csv_format_field(
            field_ptrs[i],
            field_lens[i],
            out_ptr + out_idx,
            out_max - out_idx,
            delimiter,
            quotechar,
        );

        if (result < 0) {
            return -1;
        }

        out_idx += @intCast(result);
    }

    return @intCast(out_idx);
}
