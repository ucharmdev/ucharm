const std = @import("std");
const mem = std.mem;

// Textwrap module - provides text wrapping and formatting functions

/// Wrap a single paragraph of text, returning wrapped lines via callback
/// Returns number of lines created, or -1 on error
pub export fn textwrap_wrap(
    text: [*]const u8,
    text_len: usize,
    width: usize,
    callback: *const fn (line: [*]const u8, line_len: usize, user_data: ?*anyopaque) callconv(.c) void,
    user_data: ?*anyopaque,
) i32 {
    const input = text[0..text_len];
    var line_count: i32 = 0;

    // Handle empty input
    if (input.len == 0) {
        return 0;
    }

    var start: usize = 0;
    while (start < input.len) {
        // Skip leading whitespace at start of line (except first)
        if (line_count > 0) {
            while (start < input.len and input[start] == ' ') {
                start += 1;
            }
        }

        if (start >= input.len) break;

        // Find end of this line
        var end = start;
        var last_space: ?usize = null;

        while (end < input.len and (end - start) < width) {
            if (input[end] == ' ') {
                last_space = end;
            }
            if (input[end] == '\n') {
                break;
            }
            end += 1;
        }

        // If we're not at the end and didn't hit a newline
        if (end < input.len and input[end] != '\n') {
            // Try to break at last space
            if (last_space) |space| {
                if (space > start) {
                    end = space;
                }
            }
        }

        // Handle newline
        if (end < input.len and input[end] == '\n') {
            callback(input[start..end].ptr, end - start, user_data);
            line_count += 1;
            start = end + 1;
            continue;
        }

        // Output the line
        callback(input[start..end].ptr, end - start, user_data);
        line_count += 1;

        start = end;
        if (start < input.len and input[start] == ' ') {
            start += 1;
        }
    }

    return line_count;
}

/// Find common leading whitespace in text
/// Returns the length of the common prefix
pub export fn textwrap_common_indent(
    text: [*]const u8,
    text_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const input = text[0..text_len];

    if (input.len == 0) return 0;

    // Find common indent across all non-empty lines
    var common_indent: ?[]const u8 = null;

    var line_start: usize = 0;
    while (line_start < input.len) {
        // Find end of line
        var line_end = line_start;
        while (line_end < input.len and input[line_end] != '\n') {
            line_end += 1;
        }

        const line = input[line_start..line_end];

        // Skip empty lines
        var all_space = true;
        for (line) |c| {
            if (c != ' ' and c != '\t') {
                all_space = false;
                break;
            }
        }

        if (!all_space) {
            // Find leading whitespace
            var indent_end: usize = 0;
            while (indent_end < line.len and (line[indent_end] == ' ' or line[indent_end] == '\t')) {
                indent_end += 1;
            }

            const line_indent = line[0..indent_end];

            if (common_indent) |ci| {
                // Find common prefix
                var common_len: usize = 0;
                while (common_len < ci.len and common_len < line_indent.len and
                    ci[common_len] == line_indent[common_len])
                {
                    common_len += 1;
                }
                common_indent = ci[0..common_len];
            } else {
                common_indent = line_indent;
            }
        }

        line_start = line_end + 1;
    }

    if (common_indent) |ci| {
        if (ci.len <= output_len) {
            @memcpy(output[0..ci.len], ci);
            return @intCast(ci.len);
        }
    }

    return 0;
}

/// Remove common leading whitespace from text (dedent)
/// Returns length written to output
pub export fn textwrap_dedent(
    text: [*]const u8,
    text_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const input = text[0..text_len];

    if (input.len == 0) return 0;

    // First find the common indent
    var indent_buf: [256]u8 = undefined;
    const indent_len = textwrap_common_indent(text, text_len, &indent_buf, indent_buf.len);
    if (indent_len <= 0) {
        // No common indent, copy as-is
        const copy_len = @min(input.len, output_len);
        @memcpy(output[0..copy_len], input[0..copy_len]);
        return @intCast(copy_len);
    }

    const indent = indent_buf[0..@intCast(indent_len)];

    // Remove indent from each line
    var out_pos: usize = 0;
    var line_start: usize = 0;

    while (line_start < input.len) {
        // Find end of line
        var line_end = line_start;
        while (line_end < input.len and input[line_end] != '\n') {
            line_end += 1;
        }

        const line = input[line_start..line_end];

        // Check if line starts with indent
        var content_start: usize = 0;
        if (line.len >= indent.len and mem.eql(u8, line[0..indent.len], indent)) {
            content_start = indent.len;
        }

        // Copy content
        const content = line[content_start..];
        if (out_pos + content.len < output_len) {
            @memcpy(output[out_pos..][0..content.len], content);
            out_pos += content.len;
        }

        // Add newline if there was one
        if (line_end < input.len) {
            if (out_pos < output_len) {
                output[out_pos] = '\n';
                out_pos += 1;
            }
        }

        line_start = line_end + 1;
    }

    return @intCast(out_pos);
}

/// Add prefix to each line (indent)
/// Returns length written to output
pub export fn textwrap_indent(
    text: [*]const u8,
    text_len: usize,
    prefix: [*]const u8,
    prefix_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const input = text[0..text_len];
    const pfx = prefix[0..prefix_len];

    if (input.len == 0) return 0;

    var out_pos: usize = 0;
    var line_start: usize = 0;

    while (line_start < input.len) {
        // Find end of line
        var line_end = line_start;
        while (line_end < input.len and input[line_end] != '\n') {
            line_end += 1;
        }

        const line = input[line_start..line_end];

        // Add prefix (only to non-empty lines)
        if (line.len > 0) {
            if (out_pos + pfx.len < output_len) {
                @memcpy(output[out_pos..][0..pfx.len], pfx);
                out_pos += pfx.len;
            }
        }

        // Copy line content
        if (out_pos + line.len < output_len) {
            @memcpy(output[out_pos..][0..line.len], line);
            out_pos += line.len;
        }

        // Add newline if there was one
        if (line_end < input.len) {
            if (out_pos < output_len) {
                output[out_pos] = '\n';
                out_pos += 1;
            }
        }

        line_start = line_end + 1;
    }

    return @intCast(out_pos);
}

/// Shorten text to fit in width, adding placeholder at end
/// Returns length written to output
pub export fn textwrap_shorten(
    text: [*]const u8,
    text_len: usize,
    width: usize,
    placeholder: [*]const u8,
    placeholder_len: usize,
    output: [*]u8,
    output_len: usize,
) i32 {
    const input = text[0..text_len];
    const ph = placeholder[0..placeholder_len];

    if (input.len <= width) {
        // Text fits, copy as-is
        const copy_len = @min(input.len, output_len);
        @memcpy(output[0..copy_len], input[0..copy_len]);
        return @intCast(copy_len);
    }

    if (width <= ph.len) {
        // Width too small even for placeholder
        const copy_len = @min(width, output_len);
        @memcpy(output[0..copy_len], ph[0..copy_len]);
        return @intCast(copy_len);
    }

    // Find last word boundary before width - placeholder
    const target_len = width - ph.len;
    var cut_pos = target_len;

    // Try to break at word boundary
    while (cut_pos > 0 and input[cut_pos] != ' ') {
        cut_pos -= 1;
    }

    if (cut_pos == 0) {
        cut_pos = target_len;
    }

    // Remove trailing space
    while (cut_pos > 0 and input[cut_pos - 1] == ' ') {
        cut_pos -= 1;
    }

    // Copy text + placeholder
    var out_pos: usize = 0;
    if (cut_pos <= output_len) {
        @memcpy(output[0..cut_pos], input[0..cut_pos]);
        out_pos = cut_pos;
    }

    if (out_pos + ph.len <= output_len) {
        @memcpy(output[out_pos..][0..ph.len], ph);
        out_pos += ph.len;
    }

    return @intCast(out_pos);
}
