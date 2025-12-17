/*
 * modcsv - Native CSV parsing module for ucharm
 * 
 * This module bridges Zig's CSV implementation to MicroPython.
 * Compatible with Python's csv module API.
 * 
 * Usage in Python:
 *   import csv
 *   
 *   # Parse a line
 *   fields = csv.parse("a,b,c")
 *   
 *   # Format fields to CSV
 *   line = csv.format(["a", "b", "c"])
 *   
 *   # Use reader/writer
 *   reader = csv.reader(file)
 *   for row in reader:
 *       print(row)
 */

#include "../bridge/mpy_bridge.h"

// Zig functions
extern int csv_parse_line(const char *line, size_t line_len, 
                          char delimiter, char quotechar,
                          int doublequote, int skipinitialspace);
extern size_t csv_get_field_count(void);
extern size_t csv_get_field(size_t index, char *out, size_t out_max);
extern const char *csv_get_field_ptr(size_t index);
extern size_t csv_get_field_len(size_t index);
extern int csv_format_field(const char *value, size_t value_len,
                            char *out, size_t out_max,
                            char delimiter, char quotechar);

// Default options
static char current_delimiter = ',';
static char current_quotechar = '"';
static int current_doublequote = 1;
static int current_skipinitialspace = 0;

// ============================================================================
// csv.parse(line, delimiter=',', quotechar='"') -> list
// ============================================================================

MPY_FUNC_VAR(csv, parse, 1, 3) {
    // Get the line string
    size_t line_len;
    const char *line = mpy_str_len(args[0], &line_len);
    
    // Get optional delimiter
    char delimiter = current_delimiter;
    if (n_args > 1 && args[1] != mp_const_none) {
        size_t delim_len;
        const char *delim_str = mpy_str_len(args[1], &delim_len);
        if (delim_len > 0) {
            delimiter = delim_str[0];
        }
    }
    
    // Get optional quotechar
    char quotechar = current_quotechar;
    if (n_args > 2 && args[2] != mp_const_none) {
        size_t quote_len;
        const char *quote_str = mpy_str_len(args[2], &quote_len);
        if (quote_len > 0) {
            quotechar = quote_str[0];
        }
    }
    
    // Strip trailing newline/carriage return
    while (line_len > 0 && (line[line_len - 1] == '\n' || line[line_len - 1] == '\r')) {
        line_len--;
    }
    
    // Parse the line
    int result = csv_parse_line(line, line_len, delimiter, quotechar, 
                                current_doublequote, current_skipinitialspace);
    
    if (result < 0) {
        mpy_raise_value_error("CSV parse error: too many fields");
    }
    
    // Build result list
    size_t field_count = csv_get_field_count();
    mp_obj_t list = mpy_new_list();
    
    for (size_t i = 0; i < field_count; i++) {
        const char *field_ptr = csv_get_field_ptr(i);
        size_t field_len = csv_get_field_len(i);
        mpy_list_append(list, mpy_new_str_len(field_ptr, field_len));
    }
    
    return list;
}
MPY_FUNC_OBJ_VAR(csv, parse, 1, 3);

// ============================================================================
// csv.format(fields, delimiter=',', quotechar='"') -> str
// ============================================================================

MPY_FUNC_VAR(csv, format, 1, 3) {
    // Get the fields list
    mp_obj_t fields_obj = args[0];
    size_t num_fields;
    mp_obj_t *fields;
    mp_obj_get_array(fields_obj, &num_fields, &fields);
    
    // Get optional delimiter
    char delimiter = current_delimiter;
    if (n_args > 1 && args[1] != mp_const_none) {
        size_t delim_len;
        const char *delim_str = mpy_str_len(args[1], &delim_len);
        if (delim_len > 0) {
            delimiter = delim_str[0];
        }
    }
    
    // Get optional quotechar
    char quotechar = current_quotechar;
    if (n_args > 2 && args[2] != mp_const_none) {
        size_t quote_len;
        const char *quote_str = mpy_str_len(args[2], &quote_len);
        if (quote_len > 0) {
            quotechar = quote_str[0];
        }
    }
    
    // Calculate max output size
    size_t max_size = num_fields * 3; // delimiters and padding
    for (size_t i = 0; i < num_fields; i++) {
        size_t field_len;
        mpy_str_len(fields[i], &field_len);
        max_size += field_len * 2 + 2;
    }
    
    char *output = mpy_alloc(max_size);
    size_t out_idx = 0;
    
    for (size_t i = 0; i < num_fields; i++) {
        if (i > 0) {
            output[out_idx++] = delimiter;
        }
        
        size_t field_len;
        const char *field = mpy_str_len(fields[i], &field_len);
        
        int result = csv_format_field(field, field_len, 
                                      output + out_idx, max_size - out_idx,
                                      delimiter, quotechar);
        
        if (result < 0) {
            mpy_free(output, max_size);
            mpy_raise_value_error("CSV format error: buffer overflow");
        }
        
        out_idx += result;
    }
    
    mp_obj_t result = mpy_new_str_len(output, out_idx);
    mpy_free(output, max_size);
    return result;
}
MPY_FUNC_OBJ_VAR(csv, format, 1, 3);

// ============================================================================
// csv.get_dialect() -> dict
// ============================================================================

MPY_FUNC_0(csv, get_dialect) {
    mp_obj_t dict = mpy_new_dict();
    
    char delim_str[2] = {current_delimiter, 0};
    char quote_str[2] = {current_quotechar, 0};
    
    mpy_dict_store_str(dict, "delimiter", mpy_new_str(delim_str));
    mpy_dict_store_str(dict, "quotechar", mpy_new_str(quote_str));
    mpy_dict_store_str(dict, "doublequote", mpy_bool(current_doublequote));
    mpy_dict_store_str(dict, "skipinitialspace", mpy_bool(current_skipinitialspace));
    
    return dict;
}
MPY_FUNC_OBJ_0(csv, get_dialect);

// ============================================================================
// Reader class
// ============================================================================

typedef struct _csv_reader_obj_t {
    mp_obj_base_t base;
    mp_obj_t iter;
    char delimiter;
    char quotechar;
} csv_reader_obj_t;

static mp_obj_t csv_reader_iternext(mp_obj_t self_in) {
    csv_reader_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    mp_obj_t line = mp_iternext(self->iter);
    if (line == MP_OBJ_STOP_ITERATION) {
        return MP_OBJ_STOP_ITERATION;
    }
    
    // Parse the line
    size_t line_len;
    const char *line_str = mpy_str_len(line, &line_len);
    
    // Strip trailing newline
    while (line_len > 0 && (line_str[line_len - 1] == '\n' || line_str[line_len - 1] == '\r')) {
        line_len--;
    }
    
    int result = csv_parse_line(line_str, line_len, self->delimiter, self->quotechar,
                                current_doublequote, current_skipinitialspace);
    
    if (result < 0) {
        mpy_raise_value_error("CSV parse error");
    }
    
    // Build result list
    size_t field_count = csv_get_field_count();
    mp_obj_t list = mpy_new_list();
    
    for (size_t i = 0; i < field_count; i++) {
        const char *field_ptr = csv_get_field_ptr(i);
        size_t field_len = csv_get_field_len(i);
        mpy_list_append(list, mpy_new_str_len(field_ptr, field_len));
    }
    
    return list;
}

static mp_obj_t csv_reader_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 1, 3, false);
    
    csv_reader_obj_t *self = mp_obj_malloc(csv_reader_obj_t, type);
    self->iter = mp_getiter(args[0], NULL);
    self->delimiter = ',';
    self->quotechar = '"';
    
    if (n_args > 1 && args[1] != mp_const_none) {
        size_t len;
        const char *str = mpy_str_len(args[1], &len);
        if (len > 0) self->delimiter = str[0];
    }
    
    if (n_args > 2 && args[2] != mp_const_none) {
        size_t len;
        const char *str = mpy_str_len(args[2], &len);
        if (len > 0) self->quotechar = str[0];
    }
    
    return MP_OBJ_FROM_PTR(self);
}

MP_DEFINE_CONST_OBJ_TYPE(
    csv_reader_type,
    MP_QSTR_reader,
    MP_TYPE_FLAG_ITER_IS_ITERNEXT,
    make_new, csv_reader_make_new,
    iter, csv_reader_iternext
);

// ============================================================================
// Writer class
// ============================================================================

typedef struct _csv_writer_obj_t {
    mp_obj_base_t base;
    mp_obj_t file;
    char delimiter;
    char quotechar;
} csv_writer_obj_t;

static mp_obj_t csv_writer_writerow(mp_obj_t self_in, mp_obj_t row) {
    csv_writer_obj_t *self = MP_OBJ_TO_PTR(self_in);
    
    // Get fields
    size_t num_fields;
    mp_obj_t *fields;
    mp_obj_get_array(row, &num_fields, &fields);
    
    // Calculate max size
    size_t max_size = num_fields * 3;
    for (size_t i = 0; i < num_fields; i++) {
        size_t field_len;
        mpy_str_len(fields[i], &field_len);
        max_size += field_len * 2 + 2;
    }
    max_size += 2; // For newline
    
    char *output = mpy_alloc(max_size);
    size_t out_idx = 0;
    
    for (size_t i = 0; i < num_fields; i++) {
        if (i > 0) {
            output[out_idx++] = self->delimiter;
        }
        
        size_t field_len;
        const char *field = mpy_str_len(fields[i], &field_len);
        
        int result = csv_format_field(field, field_len,
                                      output + out_idx, max_size - out_idx,
                                      self->delimiter, self->quotechar);
        
        if (result < 0) {
            mpy_free(output, max_size);
            mpy_raise_value_error("CSV format error");
        }
        
        out_idx += result;
    }
    
    output[out_idx++] = '\n';
    
    // Write to file
    mp_obj_t write_method = mp_load_attr(self->file, MP_QSTR_write);
    mp_obj_t str = mpy_new_str_len(output, out_idx);
    mp_call_function_1(write_method, str);
    
    mpy_free(output, max_size);
    return mpy_none();
}
static MP_DEFINE_CONST_FUN_OBJ_2(csv_writer_writerow_obj, csv_writer_writerow);

static mp_obj_t csv_writer_writerows(mp_obj_t self_in, mp_obj_t rows) {
    mp_obj_iter_buf_t iter_buf;
    mp_obj_t iter = mp_getiter(rows, &iter_buf);
    mp_obj_t row;
    
    while ((row = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        csv_writer_writerow(self_in, row);
    }
    
    return mpy_none();
}
static MP_DEFINE_CONST_FUN_OBJ_2(csv_writer_writerows_obj, csv_writer_writerows);

static const mp_rom_map_elem_t csv_writer_locals_dict_table[] = {
    { MP_ROM_QSTR(MP_QSTR_writerow), MP_ROM_PTR(&csv_writer_writerow_obj) },
    { MP_ROM_QSTR(MP_QSTR_writerows), MP_ROM_PTR(&csv_writer_writerows_obj) },
};
static MP_DEFINE_CONST_DICT(csv_writer_locals_dict, csv_writer_locals_dict_table);

static mp_obj_t csv_writer_make_new(const mp_obj_type_t *type, size_t n_args, size_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 1, 3, false);
    
    csv_writer_obj_t *self = mp_obj_malloc(csv_writer_obj_t, type);
    self->file = args[0];
    self->delimiter = ',';
    self->quotechar = '"';
    
    if (n_args > 1 && args[1] != mp_const_none) {
        size_t len;
        const char *str = mpy_str_len(args[1], &len);
        if (len > 0) self->delimiter = str[0];
    }
    
    if (n_args > 2 && args[2] != mp_const_none) {
        size_t len;
        const char *str = mpy_str_len(args[2], &len);
        if (len > 0) self->quotechar = str[0];
    }
    
    return MP_OBJ_FROM_PTR(self);
}

MP_DEFINE_CONST_OBJ_TYPE(
    csv_writer_type,
    MP_QSTR_writer,
    MP_TYPE_FLAG_NONE,
    make_new, csv_writer_make_new,
    locals_dict, &csv_writer_locals_dict
);

// ============================================================================
// csv.reader(iterable, delimiter, quotechar) -> Reader
// ============================================================================

MPY_FUNC_VAR(csv, reader, 1, 3) {
    return csv_reader_make_new(&csv_reader_type, n_args, 0, args);
}
MPY_FUNC_OBJ_VAR(csv, reader, 1, 3);

// ============================================================================
// csv.writer(file, delimiter, quotechar) -> Writer
// ============================================================================

MPY_FUNC_VAR(csv, writer, 1, 3) {
    return csv_writer_make_new(&csv_writer_type, n_args, 0, args);
}
MPY_FUNC_OBJ_VAR(csv, writer, 1, 3);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(csv)
    // Functions
    MPY_MODULE_FUNC(csv, parse)
    MPY_MODULE_FUNC(csv, format)
    MPY_MODULE_FUNC(csv, reader)
    MPY_MODULE_FUNC(csv, writer)
    MPY_MODULE_FUNC(csv, get_dialect)
    
    // Types
    { MP_ROM_QSTR(MP_QSTR_Reader), MP_ROM_PTR(&csv_reader_type) },
    { MP_ROM_QSTR(MP_QSTR_Writer), MP_ROM_PTR(&csv_writer_type) },
    
    // Constants
    MPY_MODULE_INT(QUOTE_MINIMAL, 0)
    MPY_MODULE_INT(QUOTE_ALL, 1)
    MPY_MODULE_INT(QUOTE_NONNUMERIC, 2)
    MPY_MODULE_INT(QUOTE_NONE, 3)
MPY_MODULE_END(csv)
