const std = @import("std");
const pk = @import("pk");
const c = pk.c;

// CSV quoting constants (matching Python's csv module)
const QUOTE_MINIMAL: i64 = 0;
const QUOTE_ALL: i64 = 1;
const QUOTE_NONNUMERIC: i64 = 2;
const QUOTE_NONE: i64 = 3;

// Type handles for custom classes
var tp_writer: c.py_Type = 0;
var tp_dictreader: c.py_Type = 0;
var tp_dictwriter: c.py_Type = 0;

fn seqLen(seq: c.py_Ref) c_int {
    if (c.py_islist(seq)) return c.py_list_len(seq);
    if (c.py_istuple(seq)) return c.py_tuple_len(seq);
    return -1;
}

fn seqItem(seq: c.py_Ref, idx: c_int) c.py_Ref {
    if (c.py_islist(seq)) return c.py_list_getitem(seq, idx);
    return c.py_tuple_getitem(seq, idx);
}

// Parse a single CSV field, handling quotes
fn parseField(line: []const u8, start: *usize, trailing_comma: *bool) ?[]const u8 {
    if (start.* >= line.len) {
        if (trailing_comma.*) {
            trailing_comma.* = false;
            return "";
        }
        return null;
    }

    var pos = start.*;

    if (pos < line.len and line[pos] == '"') {
        pos += 1;
        const field_start = pos;

        while (pos < line.len) {
            if (line[pos] == '"') {
                if (pos + 1 < line.len and line[pos + 1] == '"') {
                    pos += 2;
                } else {
                    const field = line[field_start..pos];
                    pos += 1;
                    if (pos < line.len and line[pos] == ',') {
                        pos += 1;
                        if (pos >= line.len) {
                            trailing_comma.* = true;
                        }
                    }
                    start.* = pos;
                    return field;
                }
            } else {
                pos += 1;
            }
        }
        start.* = line.len;
        return line[field_start..];
    } else {
        const field_start = pos;
        while (pos < line.len and line[pos] != ',') {
            pos += 1;
        }
        const field = line[field_start..pos];
        if (pos < line.len and line[pos] == ',') {
            pos += 1;
            if (pos >= line.len) {
                trailing_comma.* = true;
            }
        }
        start.* = pos;
        return field;
    }
}

fn unescapeField(allocator: std.mem.Allocator, field: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, field.len);
    var out_pos: usize = 0;
    var in_pos: usize = 0;

    while (in_pos < field.len) {
        if (in_pos + 1 < field.len and field[in_pos] == '"' and field[in_pos + 1] == '"') {
            result[out_pos] = '"';
            out_pos += 1;
            in_pos += 2;
        } else {
            result[out_pos] = field[in_pos];
            out_pos += 1;
            in_pos += 1;
        }
    }

    return result[0..out_pos];
}

fn parseRow(line_val: c.py_Ref, row: c.py_Ref) bool {
    const line_sv = c.py_tosv(line_val);
    const line = line_sv.data[0..@intCast(line_sv.size)];

    var pos: usize = 0;
    var trailing_comma: bool = false;
    while (parseField(line, &pos, &trailing_comma)) |field| {
        var has_escaped = false;
        for (field, 0..) |ch, j| {
            if (ch == '"' and j + 1 < field.len and field[j + 1] == '"') {
                has_escaped = true;
                break;
            }
        }

        // Use a local TValue for the field string to avoid overwriting registers
        var field_val: c.py_TValue = undefined;
        if (has_escaped) {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const unescaped = unescapeField(arena.allocator(), field) catch {
                return c.py_exception(c.tp_RuntimeError, "out of memory");
            };
            const sv = c.c11_sv{ .data = unescaped.ptr, .size = @intCast(unescaped.len) };
            c.py_newstrv(&field_val, sv);
        } else {
            const sv = c.c11_sv{ .data = field.ptr, .size = @intCast(field.len) };
            c.py_newstrv(&field_val, sv);
        }
        c.py_list_append(row, &field_val);
    }
    return true;
}

fn reader(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "reader() requires 1 argument");
    }

    const lines_val = pk.argRef(argv, 0);
    if (!c.py_islist(lines_val) and !c.py_istuple(lines_val)) {
        return c.py_exception(c.tp_TypeError, "lines must be a list or tuple");
    }

    c.py_newlist(c.py_retval());
    const out_list = c.py_retval();

    const count = seqLen(lines_val);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const line_val = seqItem(lines_val, i);
        c.py_newlist(c.py_r0());
        const row = c.py_r0();
        if (!parseRow(line_val, row)) return false;
        c.py_list_append(out_list, row);
    }

    return true;
}

// ============================================================================
// csv.writer implementation
// ============================================================================

fn writerNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "writer() requires 1 argument");
    }

    _ = c.py_newobject(c.py_retval(), tp_writer, -1, 0);
    c.py_setdict(c.py_retval(), c.py_name("_file"), pk.argRef(argv, 1));

    return true;
}

fn needsQuoting(s: []const u8) bool {
    for (s) |ch| {
        if (ch == ',' or ch == '"' or ch == '\n' or ch == '\r') {
            return true;
        }
    }
    return false;
}

fn writerWriterow(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "writerow() requires 1 argument");
    }

    const self = pk.argRef(argv, 0);
    const row = pk.argRef(argv, 1);

    const file_ptr = c.py_getdict(self, c.py_name("_file"));
    if (file_ptr == null) return c.py_exception(c.tp_RuntimeError, "writer has no file");
    const file = file_ptr.?;

    const n_fields = seqLen(row);
    if (n_fields < 0) {
        return c.py_exception(c.tp_TypeError, "expected sequence");
    }

    // Build the CSV line
    var buf: [4096]u8 = undefined;
    var buf_pos: usize = 0;

    var i: c_int = 0;
    while (i < n_fields) : (i += 1) {
        if (i > 0) {
            if (buf_pos < buf.len) {
                buf[buf_pos] = ',';
                buf_pos += 1;
            }
        }

        const field = seqItem(row, i);
        const field_sv = c.py_tosv(field);
        const field_str = field_sv.data[0..@intCast(field_sv.size)];

        if (needsQuoting(field_str)) {
            // Quote the field
            if (buf_pos < buf.len) {
                buf[buf_pos] = '"';
                buf_pos += 1;
            }
            for (field_str) |ch| {
                if (ch == '"') {
                    // Escape quote
                    if (buf_pos + 1 < buf.len) {
                        buf[buf_pos] = '"';
                        buf[buf_pos + 1] = '"';
                        buf_pos += 2;
                    }
                } else {
                    if (buf_pos < buf.len) {
                        buf[buf_pos] = ch;
                        buf_pos += 1;
                    }
                }
            }
            if (buf_pos < buf.len) {
                buf[buf_pos] = '"';
                buf_pos += 1;
            }
        } else {
            // No quoting needed
            const copy_len = @min(field_str.len, buf.len - buf_pos);
            @memcpy(buf[buf_pos .. buf_pos + copy_len], field_str[0..copy_len]);
            buf_pos += copy_len;
        }
    }

    // Add newline
    if (buf_pos < buf.len) {
        buf[buf_pos] = '\n';
        buf_pos += 1;
    }

    // Write to file using file.write()
    const sv = c.c11_sv{ .data = &buf, .size = @intCast(buf_pos) };
    c.py_newstrv(c.py_r0(), sv);

    // Call file.write(line)
    if (!c.py_getattr(file, c.py_name("write"))) return false;
    var write_method = c.py_retval().*;
    var write_args: [1]c.py_TValue = .{c.py_r0().*};
    if (!c.py_call(&write_method, 1, @ptrCast(&write_args))) return false;

    c.py_newnone(c.py_retval());
    return true;
}

// ============================================================================
// csv.DictReader implementation
// ============================================================================

fn dictReaderNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) {
        return c.py_exception(c.tp_TypeError, "DictReader() requires at least 1 argument");
    }

    _ = c.py_newobject(c.py_retval(), tp_dictreader, -1, 0);

    // Store the input data
    c.py_setdict(c.py_retval(), c.py_name("_data"), pk.argRef(argv, 1));

    // Check for fieldnames kwarg (argc >= 3 means kwarg was passed)
    // For simplicity, we'll check if there's a third positional arg
    if (argc >= 3) {
        c.py_setdict(c.py_retval(), c.py_name("_fieldnames"), pk.argRef(argv, 2));
        // Custom fieldnames provided - start from row 0
        c.py_newint(c.py_r0(), 0);
        c.py_setdict(c.py_retval(), c.py_name("_start_row"), c.py_r0());
    } else {
        c.py_newnone(c.py_r0());
        c.py_setdict(c.py_retval(), c.py_name("_fieldnames"), c.py_r0());
        // First row is header - start from row 1
        c.py_newint(c.py_r0(), 1);
        c.py_setdict(c.py_retval(), c.py_name("_start_row"), c.py_r0());
    }

    // Initialize index to 0
    c.py_newint(c.py_r0(), 0);
    c.py_setdict(c.py_retval(), c.py_name("_index"), c.py_r0());

    return true;
}

fn dictReaderIter(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "__iter__() takes no arguments");
    }
    c.py_retval().* = pk.argRef(argv, 0).*;
    return true;
}

fn dictReaderNext(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "__next__() takes no arguments");
    }

    const self = pk.argRef(argv, 0);

    // Get all attributes first before any other operations
    const data_ptr = c.py_getdict(self, c.py_name("_data"));
    if (data_ptr == null) return c.py_exception(c.tp_RuntimeError, "DictReader has no data");

    const index_ptr = c.py_getdict(self, c.py_name("_index"));
    if (index_ptr == null) return c.py_exception(c.tp_RuntimeError, "DictReader has no index");

    const start_row_ptr = c.py_getdict(self, c.py_name("_start_row"));
    if (start_row_ptr == null) return c.py_exception(c.tp_RuntimeError, "DictReader has no start_row");

    const fieldnames_ptr = c.py_getdict(self, c.py_name("_fieldnames"));

    // Extract values
    const index: c_int = @intCast(c.py_toint(index_ptr.?));
    const start_row: c_int = @intCast(c.py_toint(start_row_ptr.?));
    const data_len = seqLen(data_ptr.?);

    // Check if we need to parse fieldnames from first row
    var fieldnames: c.py_Ref = undefined;
    var fieldnames_storage: c.py_TValue = undefined;
    var need_to_store_fieldnames = false;

    if (fieldnames_ptr != null and !c.py_isnone(fieldnames_ptr.?)) {
        fieldnames = fieldnames_ptr.?;
    } else {
        // First row is fieldnames - parse it
        if (data_len < 1) {
            return c.py_exception(c.tp_StopIteration, "");
        }
        const first_line = seqItem(data_ptr.?, 0);
        c.py_newlist(c.py_r0());
        if (!parseRow(first_line, c.py_r0())) return false;
        fieldnames_storage = c.py_r0().*;
        fieldnames = &fieldnames_storage;
        need_to_store_fieldnames = true;
    }

    const actual_index = index + start_row;
    if (actual_index >= data_len) {
        // Store fieldnames if we parsed them, before returning
        if (need_to_store_fieldnames) {
            c.py_setdict(self, c.py_name("_fieldnames"), fieldnames);
        }
        return c.py_exception(c.tp_StopIteration, "");
    }

    // Parse current row
    const line = seqItem(data_ptr.?, actual_index);
    c.py_newlist(c.py_r1());
    if (!parseRow(line, c.py_r1())) return false;
    const row = c.py_r1();

    // Build dict from fieldnames and row values
    c.py_newdict(c.py_retval());
    const result = c.py_retval();

    const n_fields = seqLen(fieldnames);
    const n_values = c.py_list_len(row);
    var i: c_int = 0;
    while (i < n_fields) : (i += 1) {
        const key = seqItem(fieldnames, i);
        var value: c.py_Ref = undefined;
        if (i < n_values) {
            value = c.py_list_getitem(row, i);
        } else {
            c.py_newstr(c.py_r0(), "");
            value = c.py_r0();
        }
        _ = c.py_dict_setitem(result, key, value);
    }

    // Store fieldnames if we parsed them
    if (need_to_store_fieldnames) {
        c.py_setdict(self, c.py_name("_fieldnames"), fieldnames);
    }

    // Increment index
    c.py_newint(c.py_r0(), index + 1);
    c.py_setdict(self, c.py_name("_index"), c.py_r0());

    return true;
}

// ============================================================================
// csv.DictWriter implementation
// ============================================================================

fn dictWriterNew(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 3) {
        return c.py_exception(c.tp_TypeError, "DictWriter() requires file and fieldnames");
    }

    _ = c.py_newobject(c.py_retval(), tp_dictwriter, -1, 0);
    c.py_setdict(c.py_retval(), c.py_name("_file"), pk.argRef(argv, 1));
    c.py_setdict(c.py_retval(), c.py_name("_fieldnames"), pk.argRef(argv, 2));

    return true;
}

fn dictWriterWriteheader(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) {
        return c.py_exception(c.tp_TypeError, "writeheader() takes no arguments");
    }

    const self = pk.argRef(argv, 0);

    const fieldnames_ptr = c.py_getdict(self, c.py_name("_fieldnames"));
    if (fieldnames_ptr == null) return c.py_exception(c.tp_RuntimeError, "DictWriter has no fieldnames");

    // Create args for writerow call
    var args: [2]c.py_TValue = .{ self.*, fieldnames_ptr.?.* };
    return dictWriterWriterow(2, @ptrCast(&args));
}

fn dictWriterWriterow(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 2) {
        return c.py_exception(c.tp_TypeError, "writerow() requires 1 argument");
    }

    const self = pk.argRef(argv, 0);
    const rowdict = pk.argRef(argv, 1);

    const file_ptr = c.py_getdict(self, c.py_name("_file"));
    if (file_ptr == null) return c.py_exception(c.tp_RuntimeError, "DictWriter has no file");
    const file = file_ptr.?;

    const fieldnames_ptr = c.py_getdict(self, c.py_name("_fieldnames"));
    if (fieldnames_ptr == null) return c.py_exception(c.tp_RuntimeError, "DictWriter has no fieldnames");
    const fieldnames = fieldnames_ptr.?;

    // If rowdict is a list/tuple (for writeheader), use directly
    // Otherwise it's a dict
    const is_dict = !c.py_islist(rowdict) and !c.py_istuple(rowdict);

    var buf: [4096]u8 = undefined;
    var buf_pos: usize = 0;

    const n_fields = seqLen(fieldnames);
    var i: c_int = 0;
    while (i < n_fields) : (i += 1) {
        if (i > 0) {
            if (buf_pos < buf.len) {
                buf[buf_pos] = ',';
                buf_pos += 1;
            }
        }

        var field_sv: c.c11_sv = undefined;

        if (is_dict) {
            const key = seqItem(fieldnames, i);
            if (!c.py_getitem(rowdict, key)) {
                // Key not found - use empty string
                c.py_clearexc(null);
                field_sv = c.c11_sv{ .data = "", .size = 0 };
            } else {
                field_sv = c.py_tosv(c.py_retval());
            }
        } else {
            // It's a list/tuple (header row)
            const field = seqItem(fieldnames, i);
            field_sv = c.py_tosv(field);
        }

        const field_str = field_sv.data[0..@intCast(field_sv.size)];

        if (needsQuoting(field_str)) {
            if (buf_pos < buf.len) {
                buf[buf_pos] = '"';
                buf_pos += 1;
            }
            for (field_str) |ch| {
                if (ch == '"') {
                    if (buf_pos + 1 < buf.len) {
                        buf[buf_pos] = '"';
                        buf[buf_pos + 1] = '"';
                        buf_pos += 2;
                    }
                } else {
                    if (buf_pos < buf.len) {
                        buf[buf_pos] = ch;
                        buf_pos += 1;
                    }
                }
            }
            if (buf_pos < buf.len) {
                buf[buf_pos] = '"';
                buf_pos += 1;
            }
        } else {
            const copy_len = @min(field_str.len, buf.len - buf_pos);
            @memcpy(buf[buf_pos .. buf_pos + copy_len], field_str[0..copy_len]);
            buf_pos += copy_len;
        }
    }

    if (buf_pos < buf.len) {
        buf[buf_pos] = '\n';
        buf_pos += 1;
    }

    const sv = c.c11_sv{ .data = &buf, .size = @intCast(buf_pos) };
    c.py_newstrv(c.py_r0(), sv);

    if (!c.py_getattr(file, c.py_name("write"))) return false;
    var write_method = c.py_retval().*;
    var write_args: [1]c.py_TValue = .{c.py_r0().*};
    if (!c.py_call(&write_method, 1, @ptrCast(&write_args))) return false;

    c.py_newnone(c.py_retval());
    return true;
}

pub fn register() void {
    const name: [:0]const u8 = "csv";
    const module = c.py_getmodule(name) orelse c.py_newmodule(name);

    // Quoting constants
    c.py_newint(c.py_r0(), QUOTE_MINIMAL);
    c.py_setdict(module, c.py_name("QUOTE_MINIMAL"), c.py_r0());
    c.py_newint(c.py_r0(), QUOTE_ALL);
    c.py_setdict(module, c.py_name("QUOTE_ALL"), c.py_r0());
    c.py_newint(c.py_r0(), QUOTE_NONNUMERIC);
    c.py_setdict(module, c.py_name("QUOTE_NONNUMERIC"), c.py_r0());
    c.py_newint(c.py_r0(), QUOTE_NONE);
    c.py_setdict(module, c.py_name("QUOTE_NONE"), c.py_r0());

    // Functions
    c.py_bind(module, "reader(csvfile)", reader);

    // csv.writer type
    tp_writer = c.py_newtype("writer", c.tp_object, module, null);
    c.py_bindmagic(tp_writer, c.py_name("__new__"), writerNew);
    c.py_bindmethod(tp_writer, "writerow", writerWriterow);

    // csv.DictReader type
    tp_dictreader = c.py_newtype("DictReader", c.tp_object, module, null);
    c.py_bindmagic(tp_dictreader, c.py_name("__new__"), dictReaderNew);
    c.py_bindmagic(tp_dictreader, c.py_name("__iter__"), dictReaderIter);
    c.py_bindmagic(tp_dictreader, c.py_name("__next__"), dictReaderNext);

    // csv.DictWriter type
    tp_dictwriter = c.py_newtype("DictWriter", c.tp_object, module, null);
    c.py_bindmagic(tp_dictwriter, c.py_name("__new__"), dictWriterNew);
    c.py_bindmethod(tp_dictwriter, "writeheader", dictWriterWriteheader);
    c.py_bindmethod(tp_dictwriter, "writerow", dictWriterWriterow);
}
