const std = @import("std");

/// Trailer format (48 bytes at end of binary):
/// - 8 bytes: magic "MCHARM01"
/// - 8 bytes: micropython_offset (u64 LE)
/// - 8 bytes: micropython_size (u64 LE)
/// - 8 bytes: python_offset (u64 LE)
/// - 8 bytes: python_size (u64 LE)
/// - 8 bytes: magic "MCHARM01"
pub const Trailer = struct {
    micropython_offset: u64,
    micropython_size: u64,
    python_offset: u64,
    python_size: u64,

    pub const SIZE: usize = 48;
    pub const MAGIC: *const [8]u8 = "MCHARM01";

    /// Read and parse trailer from file at current position
    pub fn readFromFile(file: std.fs.File) !Trailer {
        var buf: [SIZE]u8 = undefined;
        const bytes_read = try file.readAll(&buf);
        if (bytes_read != SIZE) {
            return error.InvalidTrailer;
        }
        return parse(&buf);
    }

    /// Parse trailer from raw bytes
    pub fn parse(buf: *const [SIZE]u8) !Trailer {
        // Check leading magic
        if (!std.mem.eql(u8, buf[0..8], MAGIC)) {
            return error.InvalidMagic;
        }

        // Check trailing magic
        if (!std.mem.eql(u8, buf[40..48], MAGIC)) {
            return error.InvalidMagic;
        }

        return Trailer{
            .micropython_offset = std.mem.readInt(u64, buf[8..16], .little),
            .micropython_size = std.mem.readInt(u64, buf[16..24], .little),
            .python_offset = std.mem.readInt(u64, buf[24..32], .little),
            .python_size = std.mem.readInt(u64, buf[32..40], .little),
        };
    }

    /// Serialize trailer to bytes
    pub fn toBytes(self: Trailer) [SIZE]u8 {
        var buf: [SIZE]u8 = undefined;

        // Leading magic
        @memcpy(buf[0..8], MAGIC);

        // Offsets and sizes
        std.mem.writeInt(u64, buf[8..16], self.micropython_offset, .little);
        std.mem.writeInt(u64, buf[16..24], self.micropython_size, .little);
        std.mem.writeInt(u64, buf[24..32], self.python_offset, .little);
        std.mem.writeInt(u64, buf[32..40], self.python_size, .little);

        // Trailing magic
        @memcpy(buf[40..48], MAGIC);

        return buf;
    }

    /// Validate trailer values
    pub fn isValid(self: Trailer) bool {
        // Basic sanity checks
        if (self.micropython_size == 0) return false;
        if (self.python_size == 0) return false;
        if (self.micropython_offset == 0) return false;
        if (self.python_offset <= self.micropython_offset) return false;
        return true;
    }
};

// Tests
test "trailer round-trip" {
    const original = Trailer{
        .micropython_offset = 50000,
        .micropython_size = 668000,
        .python_offset = 718000,
        .python_size = 35000,
    };

    const bytes = original.toBytes();
    const parsed = try Trailer.parse(&bytes);

    try std.testing.expectEqual(original.micropython_offset, parsed.micropython_offset);
    try std.testing.expectEqual(original.micropython_size, parsed.micropython_size);
    try std.testing.expectEqual(original.python_offset, parsed.python_offset);
    try std.testing.expectEqual(original.python_size, parsed.python_size);
}

test "trailer magic validation" {
    var bad_buf: [48]u8 = undefined;
    @memset(&bad_buf, 0);

    const result = Trailer.parse(&bad_buf);
    try std.testing.expectError(error.InvalidMagic, result);
}

test "trailer isValid" {
    const valid = Trailer{
        .micropython_offset = 50000,
        .micropython_size = 668000,
        .python_offset = 718000,
        .python_size = 35000,
    };
    try std.testing.expect(valid.isValid());

    const invalid_zero_mpy = Trailer{
        .micropython_offset = 50000,
        .micropython_size = 0,
        .python_offset = 50000,
        .python_size = 35000,
    };
    try std.testing.expect(!invalid_zero_mpy.isValid());
}
