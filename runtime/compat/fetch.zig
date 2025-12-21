/// fetch - tiny requests-like HTTP/HTTPS client
///
/// Goals:
/// - zero runtime dependencies (no curl subprocess)
/// - HTTPS via BearSSL (TLS 1.2)
/// - bundled CA bundle, with overrides via `cafile=` and env vars
///
/// API (minimal):
/// - request(method, url, data=None, headers=None, timeout=None, json=None, verify=True, cafile=None) -> dict
/// - get(url, headers=None, timeout=None, verify=True, cafile=None) -> dict
/// - post(url, data=None, headers=None, timeout=None, json=None, verify=True, cafile=None) -> dict
///
/// Response dict:
/// - status (int), reason (str), headers (dict), body (bytes), url (str)
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

const br = @cImport({
    @cInclude("bearssl.h");
});

const CaBundle = @embedFile("cacert.pem");

const UrlParts = struct {
    scheme: []const u8,
    host: []const u8,
    port: u16,
    path: []const u8,
};

fn isAsciiDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}

fn parseUrl(url: []const u8) ?UrlParts {
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;
    const scheme = url[0..scheme_end];
    const rest = url[scheme_end + 3 ..];
    const slash = std.mem.indexOfScalar(u8, rest, '/') orelse rest.len;
    const authority = rest[0..slash];
    const path = if (slash < rest.len) rest[slash..] else "/";

    var host = authority;
    var port: u16 = if (std.mem.eql(u8, scheme, "https")) 443 else 80;

    if (std.mem.lastIndexOfScalar(u8, authority, ':')) |colon| {
        const maybe_port = authority[colon + 1 ..];
        var all_digits = maybe_port.len > 0;
        for (maybe_port) |ch| all_digits = all_digits and isAsciiDigit(ch);
        if (all_digits) {
            const parsed = std.fmt.parseInt(u16, maybe_port, 10) catch return null;
            port = parsed;
            host = authority[0..colon];
        }
    }

    if (host.len == 0) return null;
    if (!std.mem.eql(u8, scheme, "http") and !std.mem.eql(u8, scheme, "https")) return null;

    return .{ .scheme = scheme, .host = host, .port = port, .path = path };
}

fn lowerAsciiInPlace(buf: []u8) void {
    for (buf) |*ch| {
        if (ch.* >= 'A' and ch.* <= 'Z') ch.* = ch.* - 'A' + 'a';
    }
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

fn envCafile() ?[]const u8 {
    if (std.posix.getenv("SSL_CERT_FILE")) |p| return p[0..p.len];
    if (std.posix.getenv("REQUESTS_CA_BUNDLE")) |p| return p[0..p.len];
    if (std.posix.getenv("CURL_CA_BUNDLE")) |p| return p[0..p.len];
    return null;
}

const TrustAnchors = struct {
    anchors: []br.br_x509_trust_anchor,
};

var g_default_anchors: ?TrustAnchors = null;
var g_file_anchors_path: ?[]u8 = null;
var g_file_anchors: ?TrustAnchors = null;

fn x509AppendDn(ctx_any: ?*anyopaque, buf_any: ?*const anyopaque, len: usize) callconv(.c) void {
    if (ctx_any == null or buf_any == null) return;
    const list: *std.ArrayList(u8) = @ptrCast(@alignCast(ctx_any));
    const bytes = @as([*]const u8, @ptrCast(buf_any))[0..len];
    list.appendSlice(std.heap.c_allocator, bytes) catch {};
}

fn pemDest(ctx_any: ?*anyopaque, buf_any: ?*const anyopaque, len: usize) callconv(.c) void {
    if (ctx_any == null or buf_any == null) return;
    const list: *std.ArrayList(u8) = @ptrCast(@alignCast(ctx_any));
    const bytes = @as([*]const u8, @ptrCast(buf_any))[0..len];
    list.appendSlice(std.heap.c_allocator, bytes) catch {};
}

fn deepCopyPkey(allocator: std.mem.Allocator, pkey: *const br.br_x509_pkey) ?br.br_x509_pkey {
    var out: br.br_x509_pkey = pkey.*;
    if (pkey.key_type == br.BR_KEYTYPE_RSA) {
        const n = pkey.key.rsa.n[0..pkey.key.rsa.nlen];
        const e = pkey.key.rsa.e[0..pkey.key.rsa.elen];
        const buf = allocator.alloc(u8, n.len + e.len) catch return null;
        @memcpy(buf[0..n.len], n);
        @memcpy(buf[n.len .. n.len + e.len], e);
        out.key.rsa.n = buf.ptr;
        out.key.rsa.nlen = n.len;
        out.key.rsa.e = buf.ptr + n.len;
        out.key.rsa.elen = e.len;
        return out;
    } else if (pkey.key_type == br.BR_KEYTYPE_EC) {
        const q = pkey.key.ec.q[0..pkey.key.ec.qlen];
        const buf = allocator.alloc(u8, q.len) catch return null;
        @memcpy(buf[0..q.len], q);
        out.key.ec.q = buf.ptr;
        out.key.ec.qlen = q.len;
        return out;
    }
    return null;
}

fn pemDrainEvents(
    allocator: std.mem.Allocator,
    pc: *br.br_pem_decoder_context,
    collecting: *bool,
    der: *std.ArrayList(u8),
    anchors: *std.ArrayList(br.br_x509_trust_anchor),
) bool {
    var did: bool = false;
    while (true) {
        const ev = br.br_pem_decoder_event(pc);
        if (ev == 0) return did;
        did = true;

        if (ev == br.BR_PEM_BEGIN_OBJ) {
            const name = std.mem.span(br.br_pem_decoder_name(pc));
            collecting.* = std.mem.eql(u8, name, "CERTIFICATE");
            der.clearRetainingCapacity();
            if (collecting.*) {
                br.br_pem_decoder_setdest(pc, pemDest, der);
            } else {
                br.br_pem_decoder_setdest(pc, null, null);
            }
            continue;
        }

        if (ev == br.BR_PEM_END_OBJ and collecting.* and der.items.len > 0) {
            collecting.* = false;
            // Decode certificate to get DN + public key.
            var dn = std.ArrayList(u8).empty;
            defer dn.deinit(std.heap.c_allocator);

            var xc: br.br_x509_decoder_context = undefined;
            br.br_x509_decoder_init(&xc, x509AppendDn, &dn);
            br.br_x509_decoder_push(&xc, der.items.ptr, der.items.len);
            if (br.br_x509_decoder_last_error(&xc) != 0) continue;

            const pkey = br.br_x509_decoder_get_pkey(&xc) orelse continue;
            const copied_pkey = deepCopyPkey(allocator, pkey) orelse continue;

            const dn_copy = allocator.alloc(u8, dn.items.len) catch continue;
            @memcpy(dn_copy, dn.items);

            var ta: br.br_x509_trust_anchor = undefined;
            ta.dn.data = dn_copy.ptr;
            ta.dn.len = dn_copy.len;
            ta.flags = if (br.br_x509_decoder_isCA(&xc) != 0) br.BR_X509_TA_CA else 0;
            ta.pkey = copied_pkey;
            anchors.append(allocator, ta) catch return did;
            continue;
        }
    }
}

fn loadTrustAnchorsFromPem(allocator: std.mem.Allocator, pem: []const u8) ?TrustAnchors {
    var anchors = std.ArrayList(br.br_x509_trust_anchor).empty;
    errdefer anchors.deinit(allocator);

    var der = std.ArrayList(u8).empty;
    defer der.deinit(std.heap.c_allocator);
    var collecting = false;

    var pc: br.br_pem_decoder_context = undefined;
    br.br_pem_decoder_init(&pc);

    var idx: usize = 0;
    while (idx < pem.len) {
        const avail = pem.len - idx;
        const n = br.br_pem_decoder_push(&pc, pem.ptr + idx, avail);
        idx += n;
        const did = pemDrainEvents(allocator, &pc, &collecting, &der, &anchors);
        if (n == 0 and !did) {
            // No progress and no events: avoid an infinite loop.
            break;
        }
    }
    // Flush any pending events (e.g. if the PEM ends right after END marker).
    _ = br.br_pem_decoder_push(&pc, pem.ptr + pem.len, 0);
    _ = pemDrainEvents(allocator, &pc, &collecting, &der, &anchors);

    if (anchors.items.len == 0) return null;
    return .{ .anchors = anchors.toOwnedSlice(allocator) catch return null };
}

fn getTrustAnchors(cafile: ?[]const u8) ?TrustAnchors {
    if (cafile) |path| {
        if (g_file_anchors_path) |p| {
            if (std.mem.eql(u8, p, path)) return g_file_anchors;
        }
        const data = std.fs.cwd().readFileAlloc(std.heap.c_allocator, path, 8 * 1024 * 1024) catch return null;
        defer std.heap.c_allocator.free(data);
        // BearSSL's PEM decoder is picky about end-of-input; normalize to end
        // with a newline so single-cert PEM blobs still decode reliably.
        const ta = blk: {
            if (data.len == 0 or data[data.len - 1] == '\n') {
                break :blk loadTrustAnchorsFromPem(std.heap.c_allocator, data);
            }
            const tmp = std.heap.c_allocator.alloc(u8, data.len + 1) catch break :blk null;
            defer std.heap.c_allocator.free(tmp);
            @memcpy(tmp[0..data.len], data);
            tmp[data.len] = '\n';
            break :blk loadTrustAnchorsFromPem(std.heap.c_allocator, tmp);
        } orelse return null;
        if (g_file_anchors_path) |p| std.heap.c_allocator.free(p);
        g_file_anchors_path = std.heap.c_allocator.dupe(u8, path) catch null;
        g_file_anchors = ta;
        return ta;
    }

    if (g_default_anchors != null) return g_default_anchors;
    const ta = loadTrustAnchorsFromPem(std.heap.c_allocator, CaBundle) orelse return null;
    g_default_anchors = ta;
    return ta;
}

const InsecureX509 = extern struct {
    vtable: *const br.br_x509_class,
    dec: br.br_x509_decoder_context,
    cert_index: c_int,
    got_pkey: c_int,
};

fn insecureStartChain(ctx: [*c][*c]const br.br_x509_class, _: [*c]const u8) callconv(.c) void {
    const self: *InsecureX509 = @ptrCast(@alignCast(@constCast(ctx)));
    self.cert_index = 0;
    self.got_pkey = 0;
}

fn insecureStartCert(ctx: [*c][*c]const br.br_x509_class, _: u32) callconv(.c) void {
    const self: *InsecureX509 = @ptrCast(@alignCast(@constCast(ctx)));
    if (self.cert_index == 0) {
        br.br_x509_decoder_init(&self.dec, null, null);
    }
}

fn insecureAppend(ctx: [*c][*c]const br.br_x509_class, buf: [*c]const u8, len: usize) callconv(.c) void {
    const self: *InsecureX509 = @ptrCast(@alignCast(@constCast(ctx)));
    if (self.cert_index != 0) return;
    if (buf == null) return;
    br.br_x509_decoder_push(&self.dec, buf, len);
}

fn insecureEndCert(ctx: [*c][*c]const br.br_x509_class) callconv(.c) void {
    const self: *InsecureX509 = @ptrCast(@alignCast(@constCast(ctx)));
    if (self.cert_index == 0) {
        if (br.br_x509_decoder_last_error(&self.dec) == 0) {
            const pkey = br.br_x509_decoder_get_pkey(&self.dec);
            if (pkey != null) self.got_pkey = 1;
        }
    }
    self.cert_index += 1;
}

fn insecureEndChain(_: [*c][*c]const br.br_x509_class) callconv(.c) c_uint {
    return 0;
}

fn insecureGetPkey(ctx: [*c]const [*c]const br.br_x509_class, usages: [*c]c_uint) callconv(.c) [*c]const br.br_x509_pkey {
    const self: *InsecureX509 = @ptrCast(@alignCast(@constCast(ctx)));
    if (usages != null) usages.* = br.BR_KEYTYPE_KEYX | br.BR_KEYTYPE_SIGN;
    if (self.got_pkey == 0) return null;
    const pkey = br.br_x509_decoder_get_pkey(&self.dec) orelse return null;
    return pkey;
}

const insecure_vtable = br.br_x509_class{
    .start_chain = insecureStartChain,
    .start_cert = insecureStartCert,
    .append = insecureAppend,
    .end_cert = insecureEndCert,
    .end_chain = insecureEndChain,
    .get_pkey = insecureGetPkey,
};

const TlsStream = struct {
    stream: std.net.Stream,
    sc: br.br_ssl_client_context,
    xc: br.br_x509_minimal_context,
    x_insec: InsecureX509,
    ioc: br.br_sslio_context,
    iobuf: [br.BR_SSL_BUFSIZE_BIDI]u8,
    host_z: [256]u8,
    verify: bool,
    saw_eof: bool,

    // Note: BearSSL stores pointers into this struct (engine, i/o callbacks).
    // Therefore this type must not be copied after initialization.

    fn lowRead(ctx_any: ?*anyopaque, data: [*c]u8, len: usize) callconv(.c) c_int {
        if (ctx_any == null) return -1;
        const self: *TlsStream = @ptrCast(@alignCast(ctx_any));
        const buf = @as([*]u8, @ptrCast(data))[0..len];
        const n = self.stream.read(buf) catch return -1;
        // BearSSL's br_sslio loop treats 0 as "try again", not EOF; convert
        // EOF into an I/O error so the caller can stop reading.
        if (n == 0) {
            self.saw_eof = true;
            return -1;
        }
        return @intCast(n);
    }

    fn lowWrite(ctx_any: ?*anyopaque, data: [*c]const u8, len: usize) callconv(.c) c_int {
        if (ctx_any == null) return -1;
        const self: *TlsStream = @ptrCast(@alignCast(ctx_any));
        const buf = @as([*]const u8, @ptrCast(data))[0..len];
        const n = self.stream.write(buf) catch return -1;
        return @intCast(n);
    }

    fn initInPlace(self: *TlsStream, host: []const u8, stream: std.net.Stream, verify: bool, cafile: ?[]const u8) !void {
        self.* = undefined;
        self.stream = stream;
        self.verify = verify;
        self.saw_eof = false;

        if (host.len + 1 > self.host_z.len) return error.NameTooLong;
        @memcpy(self.host_z[0..host.len], host);
        self.host_z[host.len] = 0;

        // Always init the full client profile for algorithms/cipher suites.
        // For verify=false we override the X.509 engine with an insecure one.
        const ta = if (verify) (getTrustAnchors(cafile) orelse return error.TrustAnchorsUnavailable) else null;
        if (ta) |t| {
            br.br_ssl_client_init_full(&self.sc, &self.xc, t.anchors.ptr, t.anchors.len);
        } else {
            br.br_ssl_client_init_full(&self.sc, &self.xc, null, 0);
        }

        br.br_ssl_engine_set_buffer(&self.sc.eng, &self.iobuf, self.iobuf.len, 1);
        br.br_ssl_engine_set_versions(&self.sc.eng, br.BR_TLS10, br.BR_TLS12);

        if (!verify) {
            self.x_insec = .{ .vtable = &insecure_vtable, .dec = undefined, .cert_index = 0, .got_pkey = 0 };
            br.br_ssl_engine_set_x509(&self.sc.eng, @ptrCast(&self.x_insec));
        }

        if (br.br_ssl_client_reset(&self.sc, @ptrCast(&self.host_z), 0) == 0) return error.TlsResetFailed;

        br.br_sslio_init(&self.ioc, &self.sc.eng, lowRead, self, lowWrite, self);
    }

    fn deinit(self: *TlsStream) void {
        self.stream.close();
    }

    fn writeAll(self: *TlsStream, bytes: []const u8) !void {
        if (bytes.len == 0) return;
        if (br.br_sslio_write_all(&self.ioc, bytes.ptr, bytes.len) < 0) return error.TlsIoFailed;
        if (br.br_sslio_flush(&self.ioc) < 0) return error.TlsIoFailed;
    }

    fn read(self: *TlsStream, buf: []u8) !usize {
        if (buf.len == 0) return 0;
        const n: c_int = br.br_sslio_read(&self.ioc, buf.ptr, buf.len);
        if (n > 0) return @intCast(n);
        const errc = br.br_ssl_engine_last_error(&self.sc.eng);
        if (errc == 0) return 0;
        if (errc == br.BR_ERR_IO and self.saw_eof) return 0;
        return error.TlsIoFailed;
    }
};

var g_last_error_buf: [256:0]u8 = undefined;
var g_last_error: [:0]const u8 = "";

fn setLastError(comptime fmt: []const u8, args: anytype) void {
    const s = std.fmt.bufPrintZ(&g_last_error_buf, fmt, args) catch {
        g_last_error_buf[0] = 0;
        g_last_error = "";
        return;
    };
    g_last_error = s;
}

fn lastError() [:0]const u8 {
    return g_last_error;
}

fn buildRequest(
    method: []const u8,
    host: []const u8,
    port: u16,
    path: []const u8,
    headers_obj: c.py_Ref,
    body: []const u8,
    content_type: ?[]const u8,
) ![]u8 {
    var buf = std.ArrayList(u8).empty;
    errdefer buf.deinit(std.heap.c_allocator);

    try buf.writer(std.heap.c_allocator).print("{s} {s} HTTP/1.1\r\n", .{ method, path });

    if ((port == 80) or (port == 443)) {
        try buf.writer(std.heap.c_allocator).print("Host: {s}\r\n", .{host});
    } else {
        try buf.writer(std.heap.c_allocator).print("Host: {s}:{d}\r\n", .{ host, port });
    }
    try buf.writer(std.heap.c_allocator).writeAll("Connection: close\r\n");

    if (body.len > 0) {
        try buf.writer(std.heap.c_allocator).print("Content-Length: {}\r\n", .{body.len});
        if (content_type) |ct| {
            try buf.writer(std.heap.c_allocator).print("Content-Type: {s}\r\n", .{ct});
        }
    }

    if (!c.py_isnone(headers_obj)) {
        if (!c.py_isdict(headers_obj)) return error.InvalidHeaders;
        const apply_ctx = struct {
            b: *std.ArrayList(u8),
        };
        var ctx_local = apply_ctx{ .b = &buf };
        const cb = struct {
            fn f(key: c.py_Ref, val: c.py_Ref, p: ?*anyopaque) callconv(.c) bool {
                const ctxp: *apply_ctx = @ptrCast(@alignCast(p));
                if (!c.py_isstr(key)) return true;
                if (!c.py_str(val)) return false;
                const k = c.py_tostr(key);
                const k_s = k[0..std.mem.len(k)];
                const v = c.py_tostr(c.py_retval());
                const v_s = v[0..std.mem.len(v)];
                ctxp.b.writer(std.heap.c_allocator).print("{s}: {s}\r\n", .{ k_s, v_s }) catch return false;
                return true;
            }
        }.f;
        if (!c.py_dict_apply(headers_obj, cb, &ctx_local)) return error.InvalidHeaders;
    }

    try buf.writer(std.heap.c_allocator).writeAll("\r\n");
    if (body.len > 0) try buf.appendSlice(std.heap.c_allocator, body);
    return buf.toOwnedSlice(std.heap.c_allocator);
}

fn readAllPlain(stream: std.net.Stream) ![]u8 {
    var s = stream;
    defer s.close();
    var list = std.ArrayList(u8).empty;
    errdefer list.deinit(std.heap.c_allocator);
    var tmp: [4096]u8 = undefined;
    while (true) {
        const n = s.read(&tmp) catch return error.IoFailed;
        if (n == 0) break;
        try list.appendSlice(std.heap.c_allocator, tmp[0..n]);
        if (list.items.len > 8 * 1024 * 1024) return error.ResponseTooLarge;
    }
    return list.toOwnedSlice(std.heap.c_allocator);
}

fn readAllTls(tls: *TlsStream) ![]u8 {
    var list = std.ArrayList(u8).empty;
    errdefer list.deinit(std.heap.c_allocator);
    var tmp: [4096]u8 = undefined;
    while (true) {
        const n = tls.read(&tmp) catch return error.IoFailed;
        if (n == 0) break;
        try list.appendSlice(std.heap.c_allocator, tmp[0..n]);
        if (list.items.len > 8 * 1024 * 1024) return error.ResponseTooLarge;
    }
    return list.toOwnedSlice(std.heap.c_allocator);
}

fn tcpConnectPreferIpv4(host: []const u8, port: u16) !std.net.Stream {
    const list = std.net.getAddressList(std.heap.c_allocator, host, port) catch return error.ConnectFailed;
    defer list.deinit();

    if (list.addrs.len == 0) return error.ConnectFailed;

    // Try IPv4 first, then everything else (IPv6, etc).
    for (list.addrs) |addr| {
        if (addr.any.family != std.posix.AF.INET) continue;
        return std.net.tcpConnectToAddress(addr) catch |err| switch (err) {
            error.ConnectionRefused => continue,
            else => continue,
        };
    }
    for (list.addrs) |addr| {
        return std.net.tcpConnectToAddress(addr) catch |err| switch (err) {
            error.ConnectionRefused => continue,
            else => continue,
        };
    }
    return error.ConnectFailed;
}

fn doRequest(
    method: []const u8,
    url: []const u8,
    body_obj: c.py_Ref,
    headers_obj: c.py_Ref,
    json_obj: c.py_Ref,
    verify: bool,
    cafile: ?[]const u8,
) ?struct {
    status: i64,
    reason: []const u8,
    headers: c.py_TValue,
    body: []u8,
    url: []const u8,
} {
    g_last_error = "";
    const parts = parseUrl(url) orelse {
        setLastError("invalid url", .{});
        return null;
    };

    var body_len: usize = 0;
    var body: []const u8 = &.{};
    var owned_body: ?[]u8 = null;
    var content_type: ?[]const u8 = null;

    if (!c.py_isnone(json_obj)) {
        // json.dumps(json_obj)
        const imp = c.py_import("json");
        if (imp < 0 or imp == 0) return null;
        const json_mod = c.py_getmodule("json") orelse return null;
        if (!c.py_getattr(json_mod, c.py_name("dumps"))) return null;
        const dumps_fn = c.py_retval();
        var arg0: c.py_TValue = json_obj.*;
        if (!c.py_call(dumps_fn, 1, @ptrCast(&arg0))) return null;
        if (!c.py_isstr(c.py_retval())) return null;
        const s = c.py_tostr(c.py_retval());
        const tmp = s[0..std.mem.len(s)];
        // `json.dumps()` result only lives in `py_retval`; subsequent Python calls
        // (e.g. rendering headers) can clobber it. Copy to stable memory.
        owned_body = std.heap.c_allocator.dupe(u8, tmp) catch return null;
        body = owned_body.?;
        content_type = "application/json";
    } else {
        if (bytesLikeToSlice(body_obj, &body_len)) |sl| body = sl else body = &.{};
    }

    const req_bytes = buildRequest(method, parts.host, parts.port, parts.path, headers_obj, body, content_type) catch {
        if (owned_body) |b| std.heap.c_allocator.free(b);
        return null;
    };
    if (owned_body) |b| std.heap.c_allocator.free(b);
    defer std.heap.c_allocator.free(req_bytes);

    const resp_bytes = blk: {
        var stream = tcpConnectPreferIpv4(parts.host, parts.port) catch {
            setLastError("connect failed", .{});
            return null;
        };
        if (std.mem.eql(u8, parts.scheme, "https")) {
            var tls: TlsStream = undefined;
            tls.initInPlace(parts.host, stream, verify, cafile) catch |e| {
                stream.close();
                setLastError("tls init failed: {s}", .{@errorName(e)});
                return null;
            };
            errdefer tls.deinit();
            tls.writeAll(req_bytes) catch |e| {
                const berr = br.br_ssl_engine_last_error(&tls.sc.eng);
                setLastError("tls write failed: {s} (bearssl={d})", .{ @errorName(e), berr });
                return null;
            };
            const out = readAllTls(&tls) catch |e| {
                const berr = br.br_ssl_engine_last_error(&tls.sc.eng);
                setLastError("tls read failed: {s} (bearssl={d})", .{ @errorName(e), berr });
                return null;
            };
            tls.deinit();
            break :blk out;
        }
        stream.writeAll(req_bytes) catch {
            stream.close();
            setLastError("write failed", .{});
            return null;
        };
        break :blk readAllPlain(stream) catch {
            setLastError("read failed", .{});
            return null;
        };
    };

    const header_end = std.mem.indexOf(u8, resp_bytes, "\r\n\r\n") orelse {
        std.heap.c_allocator.free(resp_bytes);
        setLastError("invalid response (no headers)", .{});
        return null;
    };
    const head = resp_bytes[0..header_end];
    const body_all = resp_bytes[header_end + 4 ..];

    const line_end = std.mem.indexOf(u8, head, "\r\n") orelse {
        std.heap.c_allocator.free(resp_bytes);
        setLastError("invalid response (no status line)", .{});
        return null;
    };
    const status_line = head[0..line_end];
    var sp = std.mem.splitScalar(u8, status_line, ' ');
    _ = sp.next();
    const status_part = sp.next() orelse {
        std.heap.c_allocator.free(resp_bytes);
        setLastError("invalid response (bad status)", .{});
        return null;
    };
    const status_code = std.fmt.parseInt(i64, status_part, 10) catch {
        std.heap.c_allocator.free(resp_bytes);
        setLastError("invalid response (bad status)", .{});
        return null;
    };
    const reason_part = sp.rest();

    const headers_text = head[line_end + 2 ..];
    const headers_tv = parseHeadersIntoDict(headers_text) orelse {
        std.heap.c_allocator.free(resp_bytes);
        setLastError("invalid response (headers)", .{});
        return null;
    };

    const body_copy = std.heap.c_allocator.alloc(u8, body_all.len) catch {
        std.heap.c_allocator.free(resp_bytes);
        setLastError("oom", .{});
        return null;
    };
    @memcpy(body_copy, body_all);
    std.heap.c_allocator.free(resp_bytes);

    return .{
        .status = status_code,
        .reason = reason_part,
        .headers = headers_tv,
        .body = body_copy,
        .url = url,
    };
}

fn requestFn(ctx: *pk.Context) bool {
    const method = ctx.argStr(0) orelse return ctx.typeError("method must be str");
    const url = ctx.argStr(1) orelse return ctx.typeError("url must be str");
    const body_obj = (ctx.arg(2) orelse pk.Value.from(c.py_None())).refConst();
    const headers_obj = (ctx.arg(3) orelse pk.Value.from(c.py_None())).refConst();
    _ = ctx.arg(4); // timeout (unused for now)
    const json_obj = (ctx.arg(5) orelse pk.Value.from(c.py_None())).refConst();
    const verify = ctx.argBool(6) orelse true;
    const cafile_opt = ctx.argStr(7);

    const cafile_final = cafile_opt orelse envCafile();

    const res = doRequest(method, url, body_obj, headers_obj, json_obj, verify, cafile_final) orelse {
        const msg = lastError();
        if (msg.len == 0) return ctx.runtimeError("request failed");
        return c.py_exception(c.tp_RuntimeError, msg.ptr);
    };
    defer std.heap.c_allocator.free(res.body);

    c.py_newdict(c.py_retval());
    const d = c.py_retval();

    c.py_newint(c.py_r0(), res.status);
    _ = c.py_dict_setitem_by_str(d, "status", c.py_r0());
    c.py_newstrv(c.py_r0(), .{ .data = res.reason.ptr, .size = @intCast(res.reason.len) });
    _ = c.py_dict_setitem_by_str(d, "reason", c.py_r0());
    var headers_tv = res.headers;
    _ = c.py_dict_setitem_by_str(d, "headers", &headers_tv);
    const outb = c.py_newbytes(c.py_r0(), @intCast(res.body.len));
    @memcpy(outb[0..res.body.len], res.body);
    _ = c.py_dict_setitem_by_str(d, "body", c.py_r0());
    c.py_newstrv(c.py_r0(), .{ .data = res.url.ptr, .size = @intCast(res.url.len) });
    _ = c.py_dict_setitem_by_str(d, "url", c.py_r0());

    return true;
}

fn getFn(ctx: *pk.Context) bool {
    const url = ctx.argStr(0) orelse return ctx.typeError("url must be str");
    const headers_obj = (ctx.arg(1) orelse pk.Value.from(c.py_None())).refConst();
    _ = ctx.arg(2); // timeout (unused)
    const verify = ctx.argBool(3) orelse true;
    const cafile_opt = ctx.argStr(4);

    const cafile_final = cafile_opt orelse envCafile();
    const none = c.py_None();

    const res = doRequest("GET", url, none, headers_obj, none, verify, cafile_final) orelse {
        const msg = lastError();
        if (msg.len == 0) return ctx.runtimeError("request failed");
        return c.py_exception(c.tp_RuntimeError, msg.ptr);
    };
    defer std.heap.c_allocator.free(res.body);

    c.py_newdict(c.py_retval());
    const d = c.py_retval();

    c.py_newint(c.py_r0(), res.status);
    _ = c.py_dict_setitem_by_str(d, "status", c.py_r0());
    c.py_newstrv(c.py_r0(), .{ .data = res.reason.ptr, .size = @intCast(res.reason.len) });
    _ = c.py_dict_setitem_by_str(d, "reason", c.py_r0());
    var headers_tv = res.headers;
    _ = c.py_dict_setitem_by_str(d, "headers", &headers_tv);
    const outb = c.py_newbytes(c.py_r0(), @intCast(res.body.len));
    @memcpy(outb[0..res.body.len], res.body);
    _ = c.py_dict_setitem_by_str(d, "body", c.py_r0());
    c.py_newstrv(c.py_r0(), .{ .data = res.url.ptr, .size = @intCast(res.url.len) });
    _ = c.py_dict_setitem_by_str(d, "url", c.py_r0());

    return true;
}

fn postFn(ctx: *pk.Context) bool {
    const url = ctx.argStr(0) orelse return ctx.typeError("url must be str");
    const body_obj = (ctx.arg(1) orelse pk.Value.from(c.py_None())).refConst();
    const headers_obj = (ctx.arg(2) orelse pk.Value.from(c.py_None())).refConst();
    _ = ctx.arg(3); // timeout (unused)
    const json_obj = (ctx.arg(4) orelse pk.Value.from(c.py_None())).refConst();
    const verify = ctx.argBool(5) orelse true;
    const cafile_opt = ctx.argStr(6);

    const cafile_final = cafile_opt orelse envCafile();

    const res = doRequest("POST", url, body_obj, headers_obj, json_obj, verify, cafile_final) orelse {
        const msg = lastError();
        if (msg.len == 0) return ctx.runtimeError("request failed");
        return c.py_exception(c.tp_RuntimeError, msg.ptr);
    };
    defer std.heap.c_allocator.free(res.body);

    c.py_newdict(c.py_retval());
    const d = c.py_retval();

    c.py_newint(c.py_r0(), res.status);
    _ = c.py_dict_setitem_by_str(d, "status", c.py_r0());
    c.py_newstrv(c.py_r0(), .{ .data = res.reason.ptr, .size = @intCast(res.reason.len) });
    _ = c.py_dict_setitem_by_str(d, "reason", c.py_r0());
    var headers_tv = res.headers;
    _ = c.py_dict_setitem_by_str(d, "headers", &headers_tv);
    const outb = c.py_newbytes(c.py_r0(), @intCast(res.body.len));
    @memcpy(outb[0..res.body.len], res.body);
    _ = c.py_dict_setitem_by_str(d, "body", c.py_r0());
    c.py_newstrv(c.py_r0(), .{ .data = res.url.ptr, .size = @intCast(res.url.len) });
    _ = c.py_dict_setitem_by_str(d, "url", c.py_r0());

    return true;
}

pub fn register() void {
    var m = pk.ModuleBuilder.new("fetch");
    _ = m
        .funcSigWrapped("request(method, url, data=None, headers=None, timeout=None, json=None, verify=True, cafile=None)", 2, 8, requestFn)
        .funcSigWrapped("get(url, headers=None, timeout=None, verify=True, cafile=None)", 1, 5, getFn)
        .funcSigWrapped("post(url, data=None, headers=None, timeout=None, json=None, verify=True, cafile=None)", 1, 7, postFn);
}
