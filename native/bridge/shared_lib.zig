// shared_lib.zig - Build Zig modules as shared library for CPython/development
//
// This allows developers to use native Zig code via ctypes during development
// without needing to compile MicroPython.
//
// The functions are already exported by the ansi and args modules.
// We just need to import them so they get linked into the shared library.

const std = @import("std");

// Import modules - this causes their `export` functions to be included
pub const ansi = @import("ansi");
pub const args = @import("args");
pub const ui = @import("ui");
pub const env = @import("env");
pub const path = @import("path");

// ============================================================================
// Version
// ============================================================================

export fn microcharm_version() [*:0]const u8 {
    return "0.1.0";
}

// Force the modules to be referenced so their exports are included
comptime {
    // Reference ansi exports
    _ = ansi.ansi_color_name_to_index;
    _ = ansi.ansi_parse_hex_color;
    _ = ansi.ansi_is_hex_color;
    _ = ansi.ansi_fg_256;
    _ = ansi.ansi_bg_256;
    _ = ansi.ansi_fg_rgb;
    _ = ansi.ansi_bg_rgb;
    _ = ansi.ansi_fg_standard;
    _ = ansi.ansi_bg_standard;

    // Reference args exports
    _ = args.args_is_valid_int;
    _ = args.args_is_valid_float;
    _ = args.args_parse_int;
    _ = args.args_is_long_flag;
    _ = args.args_is_short_flag;
    _ = args.args_is_dashdash;
    _ = args.args_is_negative_number;
    _ = args.args_get_flag_name;
    _ = args.args_streq;
    _ = args.args_strlen;
    _ = args.args_is_truthy;
    _ = args.args_is_falsy;
    _ = args.args_is_negated_flag;
    _ = args.args_get_negated_base;

    // Reference ui exports
    _ = ui.ui_visible_len;
    _ = ui.ui_byte_len;
    _ = ui.ui_strcpy;
    _ = ui.ui_pad;
    _ = ui.ui_repeat_char;
    _ = ui.ui_repeat_str;
    _ = ui.ui_progress_bar;
    _ = ui.ui_percent_str;
    _ = ui.ui_box_char_tl;
    _ = ui.ui_box_char_tr;
    _ = ui.ui_box_char_bl;
    _ = ui.ui_box_char_br;
    _ = ui.ui_box_char_h;
    _ = ui.ui_box_char_v;
    _ = ui.ui_box_top;
    _ = ui.ui_box_bottom;
    _ = ui.ui_box_middle;
    _ = ui.ui_rule;
    _ = ui.ui_rule_with_title;
    _ = ui.ui_spinner_frame;
    _ = ui.ui_spinner_frame_count;
    _ = ui.ui_symbol_success;
    _ = ui.ui_symbol_error;
    _ = ui.ui_symbol_warning;
    _ = ui.ui_symbol_info;
    _ = ui.ui_symbol_bullet;
    _ = ui.ui_symbol_arrow;
    _ = ui.ui_symbol_checkbox_checked;
    _ = ui.ui_symbol_checkbox_unchecked;
    _ = ui.ui_table_char_h;
    _ = ui.ui_table_char_v;
    _ = ui.ui_table_char_tl;
    _ = ui.ui_table_char_tr;
    _ = ui.ui_table_char_bl;
    _ = ui.ui_table_char_br;
    _ = ui.ui_table_char_t_down;
    _ = ui.ui_table_char_t_up;
    _ = ui.ui_table_char_t_left;
    _ = ui.ui_table_char_t_right;
    _ = ui.ui_table_char_cross;
    _ = ui.ui_table_top;
    _ = ui.ui_table_divider;
    _ = ui.ui_table_bottom;
    _ = ui.ui_table_cell;
    _ = ui.ui_select_indicator;
    _ = ui.ui_checkbox_on;
    _ = ui.ui_checkbox_off;
    _ = ui.ui_prompt_question;
    _ = ui.ui_prompt_success;
    _ = ui.ui_cursor_up;
    _ = ui.ui_cursor_down;
    _ = ui.ui_clear_line;
    _ = ui.ui_hide_cursor;
    _ = ui.ui_show_cursor;

    // Reference env exports
    _ = env.env_get;
    _ = env.env_has;
    _ = env.env_get_or;
    _ = env.env_is_truthy;
    _ = env.env_is_falsy;
    _ = env.env_get_int;
    _ = env.env_is_ci;
    _ = env.env_is_debug;
    _ = env.env_no_color;
    _ = env.env_force_color;
    _ = env.env_get_term;
    _ = env.env_is_dumb_term;
    _ = env.env_get_home;
    _ = env.env_get_user;
    _ = env.env_get_shell;
    _ = env.env_get_pwd;
    _ = env.env_get_path;
    _ = env.env_get_editor;

    // Reference path exports
    _ = path.path_basename;
    _ = path.path_dirname;
    _ = path.path_extname;
    _ = path.path_stem;
    _ = path.path_join;
    _ = path.path_join3;
    _ = path.path_is_absolute;
    _ = path.path_is_relative;
    _ = path.path_has_extension;
    _ = path.path_has_ext;
    _ = path.path_normalize;
    _ = path.path_component_count;
    _ = path.path_component;
    _ = path.path_relative;
}
