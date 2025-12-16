// env.zig - Environment variable operations
// Provides C-ABI compatible functions for environment variable access

const std = @import("std");

// ============================================================================
// Environment Variable Access
// ============================================================================

/// Get an environment variable value.
/// Returns null if the variable is not set.
pub export fn env_get(name: [*:0]const u8) ?[*:0]const u8 {
    const result = std.posix.getenv(std.mem.span(name));
    if (result) |val| {
        return val.ptr;
    }
    return null;
}

/// Check if an environment variable is set.
pub export fn env_has(name: [*:0]const u8) bool {
    return std.posix.getenv(std.mem.span(name)) != null;
}

/// Get an environment variable with a default value.
/// Returns the default if the variable is not set.
pub export fn env_get_or(name: [*:0]const u8, default: [*:0]const u8) [*:0]const u8 {
    const result = std.posix.getenv(std.mem.span(name));
    if (result) |val| {
        return val.ptr;
    }
    return default;
}

/// Check if an environment variable is truthy (1, true, yes, on - case insensitive).
pub export fn env_is_truthy(name: [*:0]const u8) bool {
    const result = std.posix.getenv(std.mem.span(name));
    if (result) |val| {
        return isTruthyValue(val);
    }
    return false;
}

/// Check if an environment variable is falsy (0, false, no, off - case insensitive).
pub export fn env_is_falsy(name: [*:0]const u8) bool {
    const result = std.posix.getenv(std.mem.span(name));
    if (result) |val| {
        return isFalsyValue(val);
    }
    return false;
}

/// Get environment variable as integer.
/// Returns default_val if not set or not a valid integer.
pub export fn env_get_int(name: [*:0]const u8, default_val: i64) i64 {
    const result = std.posix.getenv(std.mem.span(name));
    if (result) |val| {
        return std.fmt.parseInt(i64, val, 10) catch default_val;
    }
    return default_val;
}

// ============================================================================
// Common Environment Checks
// ============================================================================

/// Check if running in CI environment.
pub export fn env_is_ci() bool {
    // Check common CI environment variables
    const ci_vars = [_][]const u8{
        "CI",
        "CONTINUOUS_INTEGRATION",
        "GITHUB_ACTIONS",
        "GITLAB_CI",
        "CIRCLECI",
        "TRAVIS",
        "JENKINS_URL",
        "BUILDKITE",
        "DRONE",
        "TEAMCITY_VERSION",
    };

    for (ci_vars) |var_name| {
        if (std.posix.getenv(var_name)) |_| {
            return true;
        }
    }
    return false;
}

/// Check if running in debug mode (DEBUG=1 or similar).
pub export fn env_is_debug() bool {
    if (std.posix.getenv("DEBUG")) |val| {
        return isTruthyValue(val);
    }
    return false;
}

/// Check if colors should be disabled (NO_COLOR is set).
pub export fn env_no_color() bool {
    // NO_COLOR spec: presence of the variable disables color, regardless of value
    return std.posix.getenv("NO_COLOR") != null;
}

/// Check if colors are forced (FORCE_COLOR is set and truthy).
pub export fn env_force_color() bool {
    if (std.posix.getenv("FORCE_COLOR")) |val| {
        // FORCE_COLOR=0 means don't force, any other value means force
        if (val.len == 0) return true; // Empty string still forces
        if (val.len == 1 and val[0] == '0') return false;
        return true;
    }
    return false;
}

/// Get the TERM environment variable.
/// Returns null if not set.
pub export fn env_get_term() ?[*:0]const u8 {
    const result = std.posix.getenv("TERM");
    if (result) |val| {
        return val.ptr;
    }
    return null;
}

/// Check if TERM indicates a dumb terminal.
pub export fn env_is_dumb_term() bool {
    if (std.posix.getenv("TERM")) |val| {
        return std.mem.eql(u8, val, "dumb");
    }
    return false;
}

/// Get HOME directory.
pub export fn env_get_home() ?[*:0]const u8 {
    const result = std.posix.getenv("HOME");
    if (result) |val| {
        return val.ptr;
    }
    return null;
}

/// Get current user name.
pub export fn env_get_user() ?[*:0]const u8 {
    // Try USER first (most common), then LOGNAME
    if (std.posix.getenv("USER")) |val| {
        return val.ptr;
    }
    if (std.posix.getenv("LOGNAME")) |val| {
        return val.ptr;
    }
    return null;
}

/// Get shell path.
pub export fn env_get_shell() ?[*:0]const u8 {
    const result = std.posix.getenv("SHELL");
    if (result) |val| {
        return val.ptr;
    }
    return null;
}

/// Get current working directory from PWD.
/// Note: This returns the PWD env var, not the actual cwd.
pub export fn env_get_pwd() ?[*:0]const u8 {
    const result = std.posix.getenv("PWD");
    if (result) |val| {
        return val.ptr;
    }
    return null;
}

/// Get PATH environment variable.
pub export fn env_get_path() ?[*:0]const u8 {
    const result = std.posix.getenv("PATH");
    if (result) |val| {
        return val.ptr;
    }
    return null;
}

/// Get EDITOR environment variable.
pub export fn env_get_editor() ?[*:0]const u8 {
    // Try VISUAL first (for full-screen editors), then EDITOR
    if (std.posix.getenv("VISUAL")) |val| {
        return val.ptr;
    }
    if (std.posix.getenv("EDITOR")) |val| {
        return val.ptr;
    }
    return null;
}

// ============================================================================
// Helper Functions
// ============================================================================

fn isTruthyValue(val: []const u8) bool {
    if (val.len == 0) return false;

    // Single character checks
    if (val.len == 1) {
        return val[0] == '1' or val[0] == 'y' or val[0] == 'Y';
    }

    // Case-insensitive comparison for common truthy values
    const lower = toLowerBuf(val);
    return std.mem.eql(u8, lower, "true") or
        std.mem.eql(u8, lower, "yes") or
        std.mem.eql(u8, lower, "on");
}

fn isFalsyValue(val: []const u8) bool {
    if (val.len == 0) return true; // Empty is falsy

    // Single character checks
    if (val.len == 1) {
        return val[0] == '0' or val[0] == 'n' or val[0] == 'N';
    }

    // Case-insensitive comparison for common falsy values
    const lower = toLowerBuf(val);
    return std.mem.eql(u8, lower, "false") or
        std.mem.eql(u8, lower, "no") or
        std.mem.eql(u8, lower, "off");
}

fn toLowerBuf(s: []const u8) []const u8 {
    // Use a static buffer for case conversion (max 8 chars for our use case)
    const S = struct {
        var buf: [16]u8 = undefined;
    };

    const len = @min(s.len, S.buf.len);
    for (s[0..len], 0..) |c, i| {
        S.buf[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    return S.buf[0..len];
}
