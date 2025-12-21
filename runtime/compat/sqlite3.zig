/// sqlite3.zig - Minimal `sqlite3` module backed by embedded SQLite
///
/// Implements a small subset of Python's DB-API 2.0:
/// - connect(database, ...)
/// - Connection.cursor(), execute(), commit(), close()
/// - Cursor.execute(), fetchone(), fetchall(), close()
///
/// Notes:
/// - Only positional args are supported for methods (PocketPy limitation).
/// - Parameter binding supports `None`, `int`, `float`, `str`, and `bytes` (sequence params only).
/// - This is intended for CLI use cases, not full CPython parity.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

const s = @cImport({
    @cInclude("sqlite3.h");
});

var tp_connection: c.py_Type = 0;
var tp_cursor: c.py_Type = 0;

const ConnObj = struct {
    db: ?*s.sqlite3 = null,
};

const CursorObj = struct {
    conn: *ConnObj,
    stmt: ?*s.sqlite3_stmt = null,
    col_count: c_int = 0,
};

fn getConn(self: c.py_Ref) ?*ConnObj {
    const p = c.py_touserdata(self) orelse return null;
    return @ptrCast(@alignCast(p));
}

fn getCursor(self: c.py_Ref) ?*CursorObj {
    const p = c.py_touserdata(self) orelse return null;
    return @ptrCast(@alignCast(p));
}

fn raiseSqlite(db: ?*s.sqlite3, rc: c_int) bool {
    const msg: [*c]const u8 = if (db) |handle| s.sqlite3_errmsg(handle) else @ptrCast("sqlite3 error");
    return c.py_exception(c.tp_RuntimeError, "sqlite3 error (%d): %s", rc, msg);
}

fn finalizeStmt(cur: *CursorObj) void {
    if (cur.stmt) |stmt| {
        _ = s.sqlite3_finalize(stmt);
        cur.stmt = null;
        cur.col_count = 0;
    }
}

fn sqliteFree(p: ?*anyopaque) callconv(.c) void {
    if (p) |pp| std.c.free(pp);
}

fn mallocCopy(data: []const u8, ensure_nul: bool) ?[*c]u8 {
    const extra: usize = if (ensure_nul) 1 else 0;
    const raw = std.c.malloc(data.len + extra) orelse return null;
    const out: [*c]u8 = @ptrCast(raw);
    if (data.len > 0) @memcpy(out[0..data.len], data);
    if (ensure_nul) out[data.len] = 0;
    return out;
}

fn bindParams(stmt: *s.sqlite3_stmt, params: c.py_Ref) bool {
    if (c.py_isnone(params)) return true;
    if (!(c.py_islist(params) or c.py_istuple(params))) {
        return c.py_exception(c.tp_TypeError, "parameters must be a list or tuple");
    }

    const n: c_int = if (c.py_islist(params)) c.py_list_len(params) else c.py_tuple_len(params);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const item = if (c.py_islist(params)) c.py_list_getitem(params, i) else c.py_tuple_getitem(params, i);
        const idx: c_int = i + 1;

        if (c.py_isnone(item)) {
            const rc = s.sqlite3_bind_null(stmt, idx);
            if (rc != s.SQLITE_OK) return c.py_exception(c.tp_RuntimeError, "sqlite3 bind failed");
            continue;
        }
        if (c.py_isint(item)) {
            const v = c.py_toint(item);
            const rc = s.sqlite3_bind_int64(stmt, idx, @intCast(v));
            if (rc != s.SQLITE_OK) return c.py_exception(c.tp_RuntimeError, "sqlite3 bind failed");
            continue;
        }
        if (c.py_isfloat(item)) {
            const v = c.py_tofloat(item);
            const rc = s.sqlite3_bind_double(stmt, idx, v);
            if (rc != s.SQLITE_OK) return c.py_exception(c.tp_RuntimeError, "sqlite3 bind failed");
            continue;
        }
        if (c.py_isstr(item)) {
            const z = c.py_tostr(item);
            const slice = z[0..std.mem.len(z)];
            const len: c_int = @intCast(slice.len);
            if (len == 0) {
                const rc = s.sqlite3_bind_text(stmt, idx, "", 0, null);
                if (rc != s.SQLITE_OK) return c.py_exception(c.tp_RuntimeError, "sqlite3 bind failed");
                continue;
            }
            const dup = mallocCopy(slice, true) orelse return c.py_exception(c.tp_RuntimeError, "out of memory");
            const rc = s.sqlite3_bind_text(stmt, idx, dup, len, sqliteFree);
            if (rc != s.SQLITE_OK) {
                std.c.free(@ptrCast(dup));
                return c.py_exception(c.tp_RuntimeError, "sqlite3 bind failed");
            }
            continue;
        }
        if (c.py_istype(item, c.tp_bytes)) {
            var nbytes: c_int = 0;
            const ptr = c.py_tobytes(item, &nbytes);
            if (nbytes <= 0) {
                const rc = s.sqlite3_bind_blob(stmt, idx, null, 0, null);
                if (rc != s.SQLITE_OK) return c.py_exception(c.tp_RuntimeError, "sqlite3 bind failed");
                continue;
            }
            const dup = mallocCopy(@as([*]const u8, @ptrCast(ptr))[0..@intCast(nbytes)], false) orelse
                return c.py_exception(c.tp_RuntimeError, "out of memory");
            const rc = s.sqlite3_bind_blob(stmt, idx, dup, nbytes, sqliteFree);
            if (rc != s.SQLITE_OK) {
                std.c.free(@ptrCast(dup));
                return c.py_exception(c.tp_RuntimeError, "sqlite3 bind failed");
            }
            continue;
        }

        return c.py_exception(c.tp_TypeError, "unsupported parameter type");
    }

    return true;
}

fn columnToValue(stmt: *s.sqlite3_stmt, col: c_int) bool {
    const t = s.sqlite3_column_type(stmt, col);
    switch (t) {
        s.SQLITE_NULL => {
            c.py_newnone(c.py_retval());
            return true;
        },
        s.SQLITE_INTEGER => {
            const v = s.sqlite3_column_int64(stmt, col);
            c.py_newint(c.py_retval(), @intCast(v));
            return true;
        },
        s.SQLITE_FLOAT => {
            const v = s.sqlite3_column_double(stmt, col);
            c.py_newfloat(c.py_retval(), v);
            return true;
        },
        s.SQLITE_TEXT => {
            const ptr = s.sqlite3_column_text(stmt, col);
            const n = s.sqlite3_column_bytes(stmt, col);
            if (ptr == null or n <= 0) {
                _ = c.py_newstrn(c.py_retval(), 0);
                return true;
            }
            const out = c.py_newstrn(c.py_retval(), n);
            @memcpy(out[0..@intCast(n)], @as([*]const u8, @ptrCast(ptr))[0..@intCast(n)]);
            return true;
        },
        s.SQLITE_BLOB => {
            const ptr = s.sqlite3_column_blob(stmt, col);
            const n = s.sqlite3_column_bytes(stmt, col);
            if (ptr == null or n <= 0) {
                _ = c.py_newbytes(c.py_retval(), 0);
                return true;
            }
            const out = c.py_newbytes(c.py_retval(), n);
            @memcpy(out[0..@intCast(n)], @as([*]const u8, @ptrCast(ptr))[0..@intCast(n)]);
            return true;
        },
        else => {
            c.py_newnone(c.py_retval());
            return true;
        },
    }
}

fn cursorNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_cursor, -1, @sizeOf(CursorObj));
    return true;
}

fn cursorInit(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const ud = getCursor(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid cursor");
    ud.stmt = null;
    ud.col_count = 0;
    c.py_newnone(c.py_retval());
    return true;
}

fn cursorClose(ctx: *pk.Context) bool {
    var self_val = ctx.arg(0) orelse return ctx.typeError("expected cursor");
    const ud = getCursor(self_val.refConst()) orelse return ctx.runtimeError("invalid cursor");
    finalizeStmt(ud);
    return ctx.returnNone();
}

fn cursorExecute(ctx: *pk.Context) bool {
    var self_val = ctx.arg(0) orelse return ctx.typeError("expected cursor");
    const sql = ctx.argStr(1) orelse return ctx.typeError("expected sql string");
    const params = (ctx.argOptional(2) orelse pk.Value.from(c.py_None())).refConst();

    const ud = getCursor(self_val.refConst()) orelse return ctx.runtimeError("invalid cursor");
    finalizeStmt(ud);

    const db = ud.conn.db orelse return ctx.runtimeError("connection is closed");
    var stmt: ?*s.sqlite3_stmt = null;
    const rc_prep = s.sqlite3_prepare_v2(db, sql.ptr, @intCast(sql.len), &stmt, null);
    if (rc_prep != s.SQLITE_OK) return raiseSqlite(db, rc_prep);
    if (stmt == null) return ctx.runtimeError("sqlite3 prepare failed");

    if (!bindParams(stmt.?, params)) {
        _ = s.sqlite3_finalize(stmt.?);
        return false;
    }

    const col_count = s.sqlite3_column_count(stmt.?);
    if (col_count <= 0) {
        // Execute immediately for statements without result rows.
        while (true) {
            const rc_step = s.sqlite3_step(stmt.?);
            if (rc_step == s.SQLITE_DONE) break;
            if (rc_step == s.SQLITE_ROW) continue;
            _ = s.sqlite3_finalize(stmt.?);
            return raiseSqlite(db, rc_step);
        }
        _ = s.sqlite3_finalize(stmt.?);
        ud.stmt = null;
        ud.col_count = 0;
        _ = ctx.returnValue(self_val);
        return true;
    }

    ud.stmt = stmt.?;
    ud.col_count = col_count;
    _ = ctx.returnValue(self_val);
    return true;
}

fn cursorFetchone(ctx: *pk.Context) bool {
    var self_val = ctx.arg(0) orelse return ctx.typeError("expected cursor");
    const ud = getCursor(self_val.refConst()) orelse return ctx.runtimeError("invalid cursor");
    const stmt = ud.stmt orelse return ctx.returnNone();
    const db = ud.conn.db orelse return ctx.runtimeError("connection is closed");

    const rc = s.sqlite3_step(stmt);
    if (rc == s.SQLITE_DONE) {
        finalizeStmt(ud);
        return ctx.returnNone();
    }
    if (rc != s.SQLITE_ROW) {
        finalizeStmt(ud);
        return raiseSqlite(db, rc);
    }

    const n = ud.col_count;
    _ = c.py_newtuple(c.py_r0(), n);
    const tup = c.py_r0();
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        if (!columnToValue(stmt, i)) return false;
        c.py_tuple_setitem(tup, i, c.py_retval());
    }
    c.py_retval().* = tup.*;
    return true;
}

fn cursorFetchall(ctx: *pk.Context) bool {
    var self_val = ctx.arg(0) orelse return ctx.typeError("expected cursor");
    const ud = getCursor(self_val.refConst()) orelse return ctx.runtimeError("invalid cursor");
    _ = ud;

    c.py_newlist(c.py_retval());
    var out_tv: c.py_TValue = c.py_retval().*;
    const out: c.py_Ref = &out_tv;

    while (true) {
        if (!cursorFetchone(ctx)) return false;
        if (c.py_isnone(c.py_retval())) break;
        c.py_list_append(out, c.py_retval());
    }
    c.py_retval().* = out_tv;
    return true;
}

fn connectionNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_connection, -1, @sizeOf(ConnObj));
    return true;
}

fn connectionInit(_: c_int, argv: c.py_StackRef) callconv(.c) bool {
    const self = pk.argRef(argv, 0);
    const ud = getConn(self) orelse return c.py_exception(c.tp_RuntimeError, "invalid connection");
    ud.db = null;
    c.py_newnone(c.py_retval());
    return true;
}

fn connectionClose(ctx: *pk.Context) bool {
    var self_val = ctx.arg(0) orelse return ctx.typeError("expected connection");
    const ud = getConn(self_val.refConst()) orelse return ctx.runtimeError("invalid connection");
    if (ud.db) |db| {
        _ = s.sqlite3_close_v2(db);
        ud.db = null;
    }
    return ctx.returnNone();
}

fn connectionCursor(ctx: *pk.Context) bool {
    var self_val = ctx.arg(0) orelse return ctx.typeError("expected connection");
    const ud = getConn(self_val.refConst()) orelse return ctx.runtimeError("invalid connection");
    if (ud.db == null) return ctx.runtimeError("connection is closed");

    _ = c.py_newobject(c.py_retval(), tp_cursor, -1, @sizeOf(CursorObj));
    const cur_py = c.py_retval();
    const cur_ud = getCursor(cur_py) orelse return ctx.runtimeError("invalid cursor");
    cur_ud.conn = ud;
    cur_ud.stmt = null;
    cur_ud.col_count = 0;

    // Keep the connection alive via a Python reference.
    c.py_setdict(cur_py, c.py_name("connection"), self_val.refConst());

    return true;
}

fn connectionExecute(ctx: *pk.Context) bool {
    const sql = ctx.argStr(1) orelse return ctx.typeError("expected sql string");
    const params_opt = ctx.argOptional(2);

    if (!connectionCursor(ctx)) return false;
    const cur = c.py_retval();

    // Call cursor.execute(cur, sql, params?)
    if (!c.py_getattr(cur, c.py_name("execute"))) return false;
    var exec_fn: c.py_TValue = c.py_retval().*;
    c.py_newstrv(c.py_r0(), .{ .data = sql.ptr, .size = @intCast(sql.len) });
    if (params_opt) |pv| {
        var args: [2]c.py_TValue = .{ c.py_r0().*, pv.refConst().* };
        if (!c.py_call(&exec_fn, 2, @ptrCast(&args))) return false;
    } else {
        var args: [1]c.py_TValue = .{c.py_r0().*};
        if (!c.py_call(&exec_fn, 1, @ptrCast(&args))) return false;
    }

    c.py_retval().* = cur.*;
    return true;
}

fn connectionCommit(ctx: *pk.Context) bool {
    var self_val = ctx.arg(0) orelse return ctx.typeError("expected connection");
    const ud = getConn(self_val.refConst()) orelse return ctx.runtimeError("invalid connection");
    const db = ud.db orelse return ctx.runtimeError("connection is closed");

    // In autocommit mode, COMMIT would error ("no transaction is active").
    // Treat commit as a no-op in that case (matches CPython behavior).
    if (s.sqlite3_get_autocommit(db) != 0) {
        return ctx.returnNone();
    }

    var stmt: ?*s.sqlite3_stmt = null;
    const rc_prep = s.sqlite3_prepare_v2(db, "COMMIT", -1, &stmt, null);
    if (rc_prep != s.SQLITE_OK) return raiseSqlite(db, rc_prep);
    if (stmt == null) return ctx.runtimeError("sqlite3 prepare failed");
    defer _ = s.sqlite3_finalize(stmt.?);

    while (true) {
        const rc_step = s.sqlite3_step(stmt.?);
        if (rc_step == s.SQLITE_DONE) break;
        if (rc_step == s.SQLITE_ROW) continue;
        return raiseSqlite(db, rc_step);
    }
    return ctx.returnNone();
}

fn connectFn(ctx: *pk.Context) bool {
    const database = ctx.argStr(0) orelse return ctx.typeError("database must be str");
    _ = ctx.argOptional(1); // timeout
    _ = ctx.argOptional(2); // detect_types
    _ = ctx.argOptional(3); // isolation_level
    _ = ctx.argOptional(4); // check_same_thread
    _ = ctx.argOptional(5); // factory
    _ = ctx.argOptional(6); // cached_statements
    _ = ctx.argOptional(7); // uri

    _ = c.py_newobject(c.py_retval(), tp_connection, -1, @sizeOf(ConnObj));
    const conn_py = c.py_retval();
    const ud = getConn(conn_py) orelse return ctx.runtimeError("invalid connection");
    ud.db = null;

    var db: ?*s.sqlite3 = null;
    const flags: c_int = s.SQLITE_OPEN_READWRITE | s.SQLITE_OPEN_CREATE;
    const rc = s.sqlite3_open_v2(database.ptr, &db, flags, null);
    if (rc != s.SQLITE_OK) {
        if (db) |handle| _ = s.sqlite3_close_v2(handle);
        return raiseSqlite(db, rc);
    }
    ud.db = db;
    c.py_retval().* = conn_py.*;
    return true;
}

pub fn register() void {
    var builder = pk.ModuleBuilder.new("sqlite3");

    var conn_builder = pk.TypeBuilder.new("Connection", c.tp_object, builder.module, null);
    tp_connection = conn_builder
        .magic("__new__", connectionNew)
        .magic("__init__", connectionInit)
        .methodWrapped("cursor", 1, 1, connectionCursor)
        .methodWrapped("execute", 2, 3, connectionExecute)
        .methodWrapped("commit", 1, 1, connectionCommit)
        .methodWrapped("close", 1, 1, connectionClose)
        .build();

    var cursor_builder = pk.TypeBuilder.new("Cursor", c.tp_object, builder.module, null);
    tp_cursor = cursor_builder
        .magic("__new__", cursorNew)
        .magic("__init__", cursorInit)
        .methodWrapped("execute", 2, 3, cursorExecute)
        .methodWrapped("fetchone", 1, 1, cursorFetchone)
        .methodWrapped("fetchall", 1, 1, cursorFetchall)
        .methodWrapped("close", 1, 1, cursorClose)
        .build();

    _ = builder.funcSigWrapped(
        "connect(database, timeout=5.0, detect_types=0, isolation_level=None, check_same_thread=True, factory=None, cached_statements=128, uri=False)",
        1,
        8,
        connectFn,
    );

    // Version info
    const ver = s.sqlite3_libversion();
    c.py_newstr(c.py_r0(), ver);
    c.py_setdict(builder.module, c.py_name("sqlite_version"), c.py_r0());
}
