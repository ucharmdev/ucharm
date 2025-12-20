/// http.client - Minimal HTTP client (HTTP/1.1, plain TCP)
///
/// This is a small subset intended for CLI use cases (no TLS yet).
/// Implements:
/// - HTTPConnection(host, port=80, timeout=None)
///   - request(method, url, body=None, headers=None)
///   - getresponse() -> HTTPResponse
/// - HTTPResponse
///   - status (int), reason (str), headers (dict)
///   - read() -> bytes
///   - getheader(name, default=None)
///
/// Limitations:
/// - http:// only (no HTTPS)
/// - no connection reuse; each request opens a new connection
/// - limited handling for chunked transfer encoding
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

var tp_conn: c.py_Type = 0;
var tp_resp: c.py_Type = 0;

fn bytesLikeToSlice(v: c.py_Ref, out_len: *usize) ?[]const u8 {
    if (c.py_isnone(v)) return null;
    if (c.py_isstr(v)) {
        const s = c.py_tostr(v);
        const sl = s[0..std.mem.len(s)];
        out_len.* = sl.len;
        return sl;
    }
    if (c.py_istype(v, c.tp_bytes)) {
        var n: c_int = 0;
        const p = c.py_tobytes(v, &n);
        out_len.* = @intCast(n);
        return p[0..out_len.*];
    }
    return null;
}

fn connNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_conn, -1, 0);
    return true;
}

fn connInit(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "HTTPConnection(host, port=80, timeout=None)");
    const self = pk.argRef(argv, 0);
    const host = pk.argRef(argv, 1);
    if (!c.py_isstr(host)) return c.py_exception(c.tp_TypeError, "host must be str");
    const port = if (argc >= 3 and c.py_isint(pk.argRef(argv, 2))) pk.argRef(argv, 2) else blk: {
        c.py_newint(c.py_r0(), 80);
        break :blk c.py_r0();
    };
    c.py_setdict(self, c.py_name("host"), host);
    c.py_setdict(self, c.py_name("port"), port);
    c.py_newnone(c.py_r0());
    c.py_setdict(self, c.py_name("_last_response"), c.py_r0());
    c.py_newnone(c.py_retval());
    return true;
}

fn respNew(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    _ = c.py_newobject(c.py_retval(), tp_resp, -1, 0);
    return true;
}

fn respInit(_: c_int, _: c.py_StackRef) callconv(.c) bool {
    c.py_newnone(c.py_retval());
    return true;
}

fn respRead(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "read(self)");
    const self = pk.argRef(argv, 0);
    const body_ptr = c.py_getdict(self, c.py_name("body")) orelse {
        _ = c.py_newbytes(c.py_retval(), 0);
        return true;
    };
    c.py_retval().* = body_ptr.*;
    return true;
}

fn lowerAsciiInPlace(buf: []u8) void {
    for (buf) |*ch| {
        if (ch.* >= 'A' and ch.* <= 'Z') ch.* = ch.* - 'A' + 'a';
    }
}

fn respGetHeader(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 2) return c.py_exception(c.tp_TypeError, "getheader(self, name, default=None)");
    const self = pk.argRef(argv, 0);
    const name = pk.argRef(argv, 1);
    if (!c.py_isstr(name)) return c.py_exception(c.tp_TypeError, "name must be str");
    const headers_ptr = c.py_getdict(self, c.py_name("headers")) orelse {
        if (argc >= 3) {
            c.py_retval().* = pk.argRef(argv, 2).*;
            return true;
        }
        c.py_newnone(c.py_retval());
        return true;
    };
    if (!c.py_isdict(headers_ptr)) return c.py_exception(c.tp_RuntimeError, "invalid response");
    const name_c = c.py_tostr(name);
    var key_buf: [256]u8 = undefined;
    const n = std.mem.len(name_c);
    if (n + 1 > key_buf.len) return c.py_exception(c.tp_ValueError, "header name too long");
    @memcpy(key_buf[0..n], name_c[0..n]);
    lowerAsciiInPlace(key_buf[0..n]);
    key_buf[n] = 0;
    const found = c.py_dict_getitem_by_str(headers_ptr, key_buf[0..n :0].ptr);
    if (found < 0) return false;
    if (found == 1) return true;
    if (argc >= 3) {
        c.py_retval().* = pk.argRef(argv, 2).*;
        return true;
    }
    c.py_newnone(c.py_retval());
    return true;
}

fn parseUrlPath(url: []const u8) []const u8 {
    // Accept either a path ("/x") or a full URL ("http://host/x").
    if (std.mem.startsWith(u8, url, "http://")) {
        const rest = url["http://".len..];
        if (std.mem.indexOfScalar(u8, rest, '/')) |i| return rest[i..];
        return "/";
    }
    return if (url.len == 0) "/" else url;
}

fn parseHeadersIntoDict(hdrs: []const u8) ?c.py_TValue {
    c.py_newdict(c.py_r0());
    const dict = c.py_r0();

    var it = std.mem.splitSequence(u8, hdrs, "\r\n");
    while (it.next()) |line| {
        if (line.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const k_raw = std.mem.trim(u8, line[0..colon], " \t");
        const v_raw = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (k_raw.len == 0) continue;

        var k_buf: [256]u8 = undefined;
        if (k_raw.len + 1 > k_buf.len) continue;
        @memcpy(k_buf[0..k_raw.len], k_raw);
        lowerAsciiInPlace(k_buf[0..k_raw.len]);
        k_buf[k_raw.len] = 0;

        c.py_newstrv(c.py_r1(), .{ .data = v_raw.ptr, .size = @intCast(v_raw.len) });
        _ = c.py_dict_setitem_by_str(dict, k_buf[0..k_raw.len :0].ptr, c.py_r1());
    }
    return dict.*;
}

fn connRequest(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc < 3) return c.py_exception(c.tp_TypeError, "request(self, method, url, body=None, headers=None)");
    const self = pk.argRef(argv, 0);
    const method = pk.argRef(argv, 1);
    const url_obj = pk.argRef(argv, 2);
    const body_obj = if (argc >= 4) pk.argRef(argv, 3) else c.py_None();
    const headers_obj = if (argc >= 5) pk.argRef(argv, 4) else c.py_None();

    const host_ptr = c.py_getdict(self, c.py_name("host")) orelse return c.py_exception(c.tp_RuntimeError, "invalid connection");
    const port_ptr = c.py_getdict(self, c.py_name("port")) orelse return c.py_exception(c.tp_RuntimeError, "invalid connection");
    if (!c.py_isstr(host_ptr)) return c.py_exception(c.tp_RuntimeError, "invalid connection");
    if (!c.py_isint(port_ptr)) return c.py_exception(c.tp_RuntimeError, "invalid connection");

    const host_c = c.py_tostr(host_ptr);
    const host = host_c[0..std.mem.len(host_c)];
    const port: u16 = @intCast(c.py_toint(port_ptr));

    if (!c.py_isstr(method)) return c.py_exception(c.tp_TypeError, "method must be str");
    if (!c.py_isstr(url_obj)) return c.py_exception(c.tp_TypeError, "url must be str");
    const method_c = c.py_tostr(method);
    const method_s = method_c[0..std.mem.len(method_c)];
    const url_c = c.py_tostr(url_obj);
    const url_s = url_c[0..std.mem.len(url_c)];
    const path = parseUrlPath(url_s);

    var body_len: usize = 0;
    const body = bytesLikeToSlice(body_obj, &body_len) orelse &.{};

    // Build request in memory.
    var req_buf = std.ArrayList(u8).empty;
    defer req_buf.deinit(std.heap.c_allocator);

    req_buf.writer(std.heap.c_allocator).print("{s} {s} HTTP/1.1\r\n", .{ method_s, path }) catch return c.py_exception(c.tp_RuntimeError, "request too large");
    req_buf.writer(std.heap.c_allocator).print("Host: {s}\r\n", .{host}) catch return c.py_exception(c.tp_RuntimeError, "request too large");
    req_buf.writer(std.heap.c_allocator).writeAll("Connection: close\r\n") catch return c.py_exception(c.tp_RuntimeError, "request too large");
    if (body.len > 0) {
        req_buf.writer(std.heap.c_allocator).print("Content-Length: {}\r\n", .{body.len}) catch return c.py_exception(c.tp_RuntimeError, "request too large");
    }

    if (!c.py_isnone(headers_obj)) {
        if (!c.py_isdict(headers_obj)) return c.py_exception(c.tp_TypeError, "headers must be dict");
        const apply_ctx = struct {
            buf: *std.ArrayList(u8),
        };
        var ctx_local = apply_ctx{ .buf = &req_buf };
        const cb = struct {
            fn f(key: c.py_Ref, val: c.py_Ref, p: ?*anyopaque) callconv(.c) bool {
                const ctxp: *apply_ctx = @ptrCast(@alignCast(p));
                if (!c.py_isstr(key) or !(c.py_isstr(val) or c.py_isint(val) or c.py_isfloat(val) or c.py_isbool(val))) return true;
                const k = c.py_tostr(key);
                const k_s = k[0..std.mem.len(k)];
                // stringify value
                if (!c.py_str(val)) return false;
                const v = c.py_tostr(c.py_retval());
                const v_s = v[0..std.mem.len(v)];
                ctxp.buf.writer(std.heap.c_allocator).print("{s}: {s}\r\n", .{ k_s, v_s }) catch return false;
                return true;
            }
        }.f;
        if (!c.py_dict_apply(headers_obj, cb, &ctx_local)) return false;
    }

    req_buf.writer(std.heap.c_allocator).writeAll("\r\n") catch return c.py_exception(c.tp_RuntimeError, "request too large");
    if (body.len > 0) req_buf.appendSlice(std.heap.c_allocator, body) catch return c.py_exception(c.tp_RuntimeError, "request too large");

    // Connect + send
    var stream = std.net.tcpConnectToHost(std.heap.c_allocator, host, port) catch {
        return c.py_exception(c.tp_OSError, "failed to connect");
    };
    defer stream.close();
    stream.writeAll(req_buf.items) catch return c.py_exception(c.tp_OSError, "failed to send request");

    // Read response (connection is `close`, so read until EOF).
    var resp_list = std.ArrayList(u8).empty;
    defer resp_list.deinit(std.heap.c_allocator);
    var tmp: [4096]u8 = undefined;
    while (true) {
        const nread = stream.read(&tmp) catch return c.py_exception(c.tp_OSError, "failed to read response");
        if (nread == 0) break;
        resp_list.appendSlice(std.heap.c_allocator, tmp[0..nread]) catch return c.py_exception(c.tp_OSError, "response too large");
        if (resp_list.items.len > 8 * 1024 * 1024) return c.py_exception(c.tp_OSError, "response too large");
    }
    const resp_bytes = resp_list.items;

    const header_end = std.mem.indexOf(u8, resp_bytes, "\r\n\r\n") orelse {
        return c.py_exception(c.tp_ValueError, "invalid HTTP response");
    };
    const head = resp_bytes[0..header_end];
    const body_all = resp_bytes[header_end + 4 ..];

    const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return c.py_exception(c.tp_ValueError, "invalid HTTP response");
    const status_line = head[0..line_end];
    var parts = std.mem.splitScalar(u8, status_line, ' ');
    _ = parts.next(); // HTTP/1.1
    const status_part = parts.next() orelse return c.py_exception(c.tp_ValueError, "invalid status line");
    const status_code = std.fmt.parseInt(i64, status_part, 10) catch return c.py_exception(c.tp_ValueError, "invalid status code");
    const reason_part = parts.rest();

    const headers_text = head[line_end + 2 ..];
    var headers_tv = parseHeadersIntoDict(headers_text) orelse return c.py_exception(c.tp_RuntimeError, "failed to parse headers");

    // Build response object
    if (!c.py_tpcall(tp_resp, 0, null)) return false;
    var resp_tv: c.py_TValue = c.py_retval().*;
    const resp = &resp_tv;

    c.py_newint(c.py_r0(), status_code);
    c.py_setdict(resp, c.py_name("status"), c.py_r0());
    c.py_newstrv(c.py_r0(), .{ .data = reason_part.ptr, .size = @intCast(reason_part.len) });
    c.py_setdict(resp, c.py_name("reason"), c.py_r0());
    c.py_setdict(resp, c.py_name("headers"), &headers_tv);
    const body_out = c.py_newbytes(c.py_r0(), @intCast(body_all.len));
    @memcpy(body_out[0..body_all.len], body_all);
    c.py_setdict(resp, c.py_name("body"), c.py_r0());

    // Save on connection for getresponse()
    c.py_setdict(self, c.py_name("_last_response"), resp);

    c.py_newnone(c.py_retval());
    return true;
}

fn connGetResponse(argc: c_int, argv: c.py_StackRef) callconv(.c) bool {
    if (argc != 1) return c.py_exception(c.tp_TypeError, "getresponse(self)");
    const self = pk.argRef(argv, 0);
    const resp_ptr = c.py_getdict(self, c.py_name("_last_response")) orelse {
        return c.py_exception(c.tp_RuntimeError, "no response available");
    };
    if (c.py_isnone(resp_ptr)) return c.py_exception(c.tp_RuntimeError, "no response available");
    c.py_retval().* = resp_ptr.*;
    c.py_newnone(c.py_r0());
    c.py_setdict(self, c.py_name("_last_response"), c.py_r0());
    return true;
}

pub fn register() void {
    const builder = pk.ModuleBuilder.new("http.client");

    var resp_builder = pk.TypeBuilder.new("HTTPResponse", c.tp_object, builder.module, null);
    tp_resp = resp_builder
        .magic("__new__", respNew)
        .magic("__init__", respInit)
        .method("read", respRead)
        .method("getheader", respGetHeader)
        .build();

    var conn_builder = pk.TypeBuilder.new("HTTPConnection", c.tp_object, builder.module, null);
    tp_conn = conn_builder
        .magic("__new__", connNew)
        .magic("__init__", connInit)
        .method("request", connRequest)
        .method("getresponse", connGetResponse)
        .build();
}
