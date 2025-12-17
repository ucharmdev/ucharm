const std = @import("std");
const posix = std.posix;

// Subprocess module - provides process spawning and output capture
// Compatible with Python's subprocess module API

const MAX_OUTPUT: usize = 1024 * 1024; // 1MB max output
const MAX_ARGS: usize = 256;
const MAX_ENV: usize = 256;

/// Result of a subprocess run
pub const RunResult = extern struct {
    returncode: i32,
    stdout_len: usize,
    stderr_len: usize,
};

// Global buffers for output (thread-local would be better but keep it simple)
var stdout_buffer: [MAX_OUTPUT]u8 = undefined;
var stderr_buffer: [MAX_OUTPUT]u8 = undefined;

/// Run a command and capture output
/// cmd: null-terminated command string (space-separated args)
/// capture_output: 1 to capture stdout/stderr, 0 to inherit
/// Returns RunResult with return code and output lengths
pub export fn subprocess_run(
    cmd: [*]const u8,
    cmd_len: usize,
    capture_output: i32,
) RunResult {
    const command = cmd[0..cmd_len];

    // Parse command into args (need space for null terminator)
    var args_buf: [MAX_ARGS + 1]?[*:0]const u8 = undefined;
    var args_storage: [MAX_ARGS][4096]u8 = undefined;
    var arg_count: usize = 0;

    var iter = std.mem.splitScalar(u8, command, ' ');
    while (iter.next()) |arg| {
        if (arg.len == 0) continue;
        if (arg_count >= MAX_ARGS) break;

        // Copy arg and null-terminate
        if (arg.len >= 4095) continue;
        @memcpy(args_storage[arg_count][0..arg.len], arg);
        args_storage[arg_count][arg.len] = 0;
        args_buf[arg_count] = @ptrCast(&args_storage[arg_count]);
        arg_count += 1;
    }

    if (arg_count == 0) {
        return RunResult{ .returncode = -1, .stdout_len = 0, .stderr_len = 0 };
    }

    // Null-terminate the args array
    args_buf[arg_count] = null;
    const args = args_buf[0 .. arg_count + 1];

    // Create pipes for stdout/stderr if capturing
    var stdout_pipe: ?[2]posix.fd_t = null;
    var stderr_pipe: ?[2]posix.fd_t = null;

    if (capture_output != 0) {
        stdout_pipe = posix.pipe() catch {
            return RunResult{ .returncode = -1, .stdout_len = 0, .stderr_len = 0 };
        };
        stderr_pipe = posix.pipe() catch {
            if (stdout_pipe) |p| {
                posix.close(p[0]);
                posix.close(p[1]);
            }
            return RunResult{ .returncode = -1, .stdout_len = 0, .stderr_len = 0 };
        };
    }

    // Fork
    const pid = posix.fork() catch {
        if (stdout_pipe) |p| {
            posix.close(p[0]);
            posix.close(p[1]);
        }
        if (stderr_pipe) |p| {
            posix.close(p[0]);
            posix.close(p[1]);
        }
        return RunResult{ .returncode = -1, .stdout_len = 0, .stderr_len = 0 };
    };

    if (pid == 0) {
        // Child process
        if (capture_output != 0) {
            if (stdout_pipe) |p| {
                posix.close(p[0]); // Close read end
                posix.dup2(p[1], posix.STDOUT_FILENO) catch {};
                posix.close(p[1]);
            }
            if (stderr_pipe) |p| {
                posix.close(p[0]); // Close read end
                posix.dup2(p[1], posix.STDERR_FILENO) catch {};
                posix.close(p[1]);
            }
        }

        // Execute - if this returns, it failed
        const argv: [*:null]const ?[*:0]const u8 = @ptrCast(args.ptr);
        _ = posix.execvpeZ(args[0].?, argv, @ptrCast(std.c.environ)) catch {};
        posix.exit(127);
    }

    // Parent process
    var stdout_len: usize = 0;
    var stderr_len: usize = 0;

    if (capture_output != 0) {
        if (stdout_pipe) |p| {
            posix.close(p[1]); // Close write end
            stdout_len = readAll(p[0], &stdout_buffer) catch 0;
            posix.close(p[0]);
        }
        if (stderr_pipe) |p| {
            posix.close(p[1]); // Close write end
            stderr_len = readAll(p[0], &stderr_buffer) catch 0;
            posix.close(p[0]);
        }
    }

    // Wait for child
    const wait_result = posix.waitpid(pid, 0);
    var returncode: i32 = -1;

    if (posix.W.IFEXITED(wait_result.status)) {
        returncode = @intCast(posix.W.EXITSTATUS(wait_result.status));
    } else if (posix.W.IFSIGNALED(wait_result.status)) {
        returncode = -@as(i32, @intCast(posix.W.TERMSIG(wait_result.status)));
    }

    return RunResult{
        .returncode = returncode,
        .stdout_len = stdout_len,
        .stderr_len = stderr_len,
    };
}

/// Get stdout from last run
pub export fn subprocess_get_stdout(buf: [*]u8, buf_len: usize) usize {
    const copy_len = @min(buf_len, stdout_buffer.len);
    @memcpy(buf[0..copy_len], stdout_buffer[0..copy_len]);
    return copy_len;
}

/// Get stderr from last run
pub export fn subprocess_get_stderr(buf: [*]u8, buf_len: usize) usize {
    const copy_len = @min(buf_len, stderr_buffer.len);
    @memcpy(buf[0..copy_len], stderr_buffer[0..copy_len]);
    return copy_len;
}

/// Run a shell command (via /bin/sh -c)
pub export fn subprocess_shell(
    cmd: [*]const u8,
    cmd_len: usize,
    capture_output: i32,
) RunResult {
    const command = cmd[0..cmd_len];

    // Build shell command: /bin/sh -c "command"
    // Need 4 elements: "/bin/sh", "-c", command, null
    var shell_args: [4]?[*:0]const u8 = undefined;
    var cmd_storage: [4096]u8 = undefined;

    shell_args[0] = "/bin/sh";
    shell_args[1] = "-c";

    // Copy command and null-terminate
    const copy_len = @min(cmd_len, 4095);
    @memcpy(cmd_storage[0..copy_len], command[0..copy_len]);
    cmd_storage[copy_len] = 0;
    shell_args[2] = @ptrCast(&cmd_storage);
    shell_args[3] = null; // Null-terminate the array

    // Create pipes for stdout/stderr if capturing
    var stdout_pipe: ?[2]posix.fd_t = null;
    var stderr_pipe: ?[2]posix.fd_t = null;

    if (capture_output != 0) {
        stdout_pipe = posix.pipe() catch {
            return RunResult{ .returncode = -1, .stdout_len = 0, .stderr_len = 0 };
        };
        stderr_pipe = posix.pipe() catch {
            if (stdout_pipe) |p| {
                posix.close(p[0]);
                posix.close(p[1]);
            }
            return RunResult{ .returncode = -1, .stdout_len = 0, .stderr_len = 0 };
        };
    }

    // Fork
    const pid = posix.fork() catch {
        if (stdout_pipe) |p| {
            posix.close(p[0]);
            posix.close(p[1]);
        }
        if (stderr_pipe) |p| {
            posix.close(p[0]);
            posix.close(p[1]);
        }
        return RunResult{ .returncode = -1, .stdout_len = 0, .stderr_len = 0 };
    };

    if (pid == 0) {
        // Child process
        if (capture_output != 0) {
            if (stdout_pipe) |p| {
                posix.close(p[0]);
                posix.dup2(p[1], posix.STDOUT_FILENO) catch {};
                posix.close(p[1]);
            }
            if (stderr_pipe) |p| {
                posix.close(p[0]);
                posix.dup2(p[1], posix.STDERR_FILENO) catch {};
                posix.close(p[1]);
            }
        }

        // Execute shell - if this returns, it failed
        const argv: [*:null]const ?[*:0]const u8 = @ptrCast(&shell_args);
        _ = posix.execvpeZ(shell_args[0].?, argv, @ptrCast(std.c.environ)) catch {};
        posix.exit(127);
    }

    // Parent process
    var stdout_len: usize = 0;
    var stderr_len: usize = 0;

    if (capture_output != 0) {
        if (stdout_pipe) |p| {
            posix.close(p[1]);
            stdout_len = readAll(p[0], &stdout_buffer) catch 0;
            posix.close(p[0]);
        }
        if (stderr_pipe) |p| {
            posix.close(p[1]);
            stderr_len = readAll(p[0], &stderr_buffer) catch 0;
            posix.close(p[0]);
        }
    }

    // Wait for child
    const wait_result = posix.waitpid(pid, 0);
    var returncode: i32 = -1;

    if (posix.W.IFEXITED(wait_result.status)) {
        returncode = @intCast(posix.W.EXITSTATUS(wait_result.status));
    } else if (posix.W.IFSIGNALED(wait_result.status)) {
        returncode = -@as(i32, @intCast(posix.W.TERMSIG(wait_result.status)));
    }

    return RunResult{
        .returncode = returncode,
        .stdout_len = stdout_len,
        .stderr_len = stderr_len,
    };
}

/// Call a command and return just the return code (no capture)
pub export fn subprocess_call(
    cmd: [*]const u8,
    cmd_len: usize,
) i32 {
    const result = subprocess_run(cmd, cmd_len, 0);
    return result.returncode;
}

/// Check if a command returns 0 (success)
pub export fn subprocess_check_call(
    cmd: [*]const u8,
    cmd_len: usize,
) i32 {
    const result = subprocess_run(cmd, cmd_len, 0);
    return result.returncode;
}

/// Get output from a command (like check_output)
/// Returns the length of output, or -1 on error
pub export fn subprocess_check_output(
    cmd: [*]const u8,
    cmd_len: usize,
) i32 {
    const result = subprocess_shell(cmd, cmd_len, 1);
    if (result.returncode != 0) {
        return -1;
    }
    return @intCast(result.stdout_len);
}

/// Get the output from the last check_output call
pub export fn subprocess_get_output(buf: [*]u8, buf_len: usize) usize {
    return subprocess_get_stdout(buf, buf_len);
}

// Helper to read all from fd
fn readAll(fd: posix.fd_t, buffer: []u8) !usize {
    var total: usize = 0;
    while (total < buffer.len) {
        const n = posix.read(fd, buffer[total..]) catch |err| {
            if (err == error.WouldBlock) continue;
            return err;
        };
        if (n == 0) break;
        total += n;
    }
    return total;
}

/// Get PID of current process
pub export fn subprocess_getpid() i32 {
    return @intCast(std.c.getpid());
}

/// Get parent PID
pub export fn subprocess_getppid() i32 {
    return @intCast(std.c.getppid());
}
