/// urllib_parse.zig - Python urllib.parse module implementation
///
/// Provides URL parsing and manipulation functions.
const std = @import("std");
const pk = @import("pk");
const c = pk.c;

// URL-safe characters that don't need encoding
const SAFE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-~";

fn isHexDigit(ch: u8) bool {
    return (ch >= '0' and ch <= '9') or (ch >= 'a' and ch <= 'f') or (ch >= 'A' and ch <= 'F');
}

fn hexToInt(ch: u8) u8 {
    if (ch >= '0' and ch <= '9') return ch - '0';
    if (ch >= 'a' and ch <= 'f') return ch - 'a' + 10;
    if (ch >= 'A' and ch <= 'F') return ch - 'A' + 10;
    return 0;
}

fn isSafe(ch: u8) bool {
    for (SAFE_CHARS) |safe| {
        if (ch == safe) return true;
    }
    return false;
}

// quote(string, safe='/', encoding=None, errors=None)
fn quoteFn(ctx: *pk.Context) bool {
    const input = ctx.argStr(0) orelse return ctx.typeError("quote() requires a string");
    const safe_str = ctx.argStr(1) orelse "/";

    var buffer: [16384]u8 = undefined;
    var pos: usize = 0;

    const hex = "0123456789ABCDEF";

    for (input) |ch| {
        // Check if char is safe or in the safe string
        var is_safe = isSafe(ch);
        if (!is_safe) {
            for (safe_str) |safe_ch| {
                if (ch == safe_ch) {
                    is_safe = true;
                    break;
                }
            }
        }

        if (is_safe) {
            if (pos >= buffer.len) return ctx.valueError("string too long");
            buffer[pos] = ch;
            pos += 1;
        } else {
            if (pos + 3 > buffer.len) return ctx.valueError("string too long");
            buffer[pos] = '%';
            buffer[pos + 1] = hex[ch >> 4];
            buffer[pos + 2] = hex[ch & 0x0f];
            pos += 3;
        }
    }

    return ctx.returnStr(buffer[0..pos]);
}

// unquote(string, encoding='utf-8', errors='replace')
fn unquoteFn(ctx: *pk.Context) bool {
    const input = ctx.argStr(0) orelse return ctx.typeError("unquote() requires a string");

    var buffer: [16384]u8 = undefined;
    var pos: usize = 0;
    var i: usize = 0;

    while (i < input.len) {
        if (pos >= buffer.len) return ctx.valueError("string too long");

        if (input[i] == '%' and i + 2 < input.len and isHexDigit(input[i + 1]) and isHexDigit(input[i + 2])) {
            const hi = hexToInt(input[i + 1]);
            const lo = hexToInt(input[i + 2]);
            buffer[pos] = (hi << 4) | lo;
            pos += 1;
            i += 3;
        } else if (input[i] == '+') {
            // Also decode + as space for form data
            buffer[pos] = ' ';
            pos += 1;
            i += 1;
        } else {
            buffer[pos] = input[i];
            pos += 1;
            i += 1;
        }
    }

    return ctx.returnStr(buffer[0..pos]);
}

const urllib_parse_py =
    \\class ParseResult:
    \\    def __init__(self, scheme, netloc, path, params, query, fragment):
    \\        self.scheme = scheme
    \\        self.netloc = netloc
    \\        self.path = path
    \\        self.params = params
    \\        self.query = query
    \\        self.fragment = fragment
    \\
    \\    def __getitem__(self, i):
    \\        return (self.scheme, self.netloc, self.path, self.params, self.query, self.fragment)[i]
    \\
    \\    def __iter__(self):
    \\        return iter((self.scheme, self.netloc, self.path, self.params, self.query, self.fragment))
    \\
    \\    def __repr__(self):
    \\        return f"ParseResult(scheme={self.scheme!r}, netloc={self.netloc!r}, path={self.path!r}, params={self.params!r}, query={self.query!r}, fragment={self.fragment!r})"
    \\
    \\def urlparse(url, scheme='', allow_fragments=True):
    \\    # Extract fragment
    \\    fragment = ''
    \\    if allow_fragments and '#' in url:
    \\        idx = url.index('#')
    \\        fragment = url[idx+1:]
    \\        url = url[:idx]
    \\
    \\    # Extract query
    \\    query = ''
    \\    if '?' in url:
    \\        idx = url.index('?')
    \\        query = url[idx+1:]
    \\        url = url[:idx]
    \\
    \\    # Extract scheme
    \\    parsed_scheme = scheme
    \\    if '://' in url:
    \\        idx = url.index('://')
    \\        parsed_scheme = url[:idx]
    \\        url = url[idx+3:]
    \\    elif ':' in url and url.index(':') < len(url) - 1:
    \\        # Check for scheme without //
    \\        idx = url.index(':')
    \\        potential_scheme = url[:idx]
    \\        # Only treat as scheme if it's all alphanumeric
    \\        if potential_scheme.isalpha():
    \\            parsed_scheme = potential_scheme
    \\            url = url[idx+1:]
    \\
    \\    # Extract netloc and path
    \\    netloc = ''
    \\    path = url
    \\    if parsed_scheme and url:
    \\        # If we had a scheme with //, the rest starts with netloc
    \\        if '/' in url:
    \\            idx = url.index('/')
    \\            netloc = url[:idx]
    \\            path = url[idx:]
    \\        else:
    \\            netloc = url
    \\            path = ''
    \\
    \\    return ParseResult(parsed_scheme, netloc, path, '', query, fragment)
    \\
    \\def urlunparse(components):
    \\    if hasattr(components, 'scheme'):
    \\        scheme = components.scheme
    \\        netloc = components.netloc
    \\        path = components.path
    \\        params = components.params
    \\        query = components.query
    \\        fragment = components.fragment
    \\    else:
    \\        scheme, netloc, path, params, query, fragment = components
    \\    url = ''
    \\    if scheme:
    \\        url = scheme + '://'
    \\    if netloc:
    \\        url += netloc
    \\    url += path
    \\    if params:
    \\        url += ';' + params
    \\    if query:
    \\        url += '?' + query
    \\    if fragment:
    \\        url += '#' + fragment
    \\    return url
    \\
    \\def urljoin(base, url, allow_fragments=True):
    \\    # If url is absolute, return it
    \\    if '://' in url:
    \\        return url
    \\
    \\    parsed_base = urlparse(base)
    \\
    \\    if url.startswith('/'):
    \\        # Absolute path - keep scheme and netloc from base
    \\        return urlunparse((parsed_base.scheme, parsed_base.netloc, url, '', '', ''))
    \\
    \\    # Relative path - resolve against base path
    \\    base_path = parsed_base.path
    \\    if '/' in base_path:
    \\        # Remove last component of base path - find last /
    \\        idx = 0
    \\        for i in range(len(base_path)):
    \\            if base_path[i] == '/':
    \\                idx = i
    \\        base_path = base_path[:idx+1]
    \\    else:
    \\        base_path = '/'
    \\
    \\    new_path = base_path + url
    \\    return urlunparse((parsed_base.scheme, parsed_base.netloc, new_path, '', '', ''))
    \\
    \\def urlencode(query, doseq=False, safe='', encoding=None, errors=None, quote_via=None):
    \\    # Handle dict or list of tuples
    \\    if hasattr(query, 'items'):
    \\        items = list(query.items())
    \\    else:
    \\        items = list(query)
    \\
    \\    parts = []
    \\    for key, value in items:
    \\        # Encode key and value, using + for spaces (form encoding)
    \\        k = str(key).replace('%', '%25').replace(' ', '+').replace('&', '%26').replace('=', '%3D')
    \\        v = str(value).replace('%', '%25').replace(' ', '+').replace('&', '%26').replace('=', '%3D')
    \\        parts.append(k + '=' + v)
    \\
    \\    return '&'.join(parts)
;

pub fn register() void {
    var builder = pk.ModuleBuilder.new("urllib.parse");
    _ = builder
        .funcSigWrapped("quote(string, safe='/')", 1, 2, quoteFn)
        .funcWrapped("unquote", 1, 1, unquoteFn);

    _ = builder.exec(urllib_parse_py);
}
