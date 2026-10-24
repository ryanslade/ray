const std = @import("std");

const Color = @import("color.zig").Color;

/// An 8-bit RGB image. Row 0 is the top.
pub const Image = struct {
    width: usize,
    height: usize,
    pixels: []u8,

    pub fn init(gpa: std.mem.Allocator, width: usize, height: usize) !Image {
        const pixels = try gpa.alloc(u8, width * height * 3);
        @memset(pixels, 0);
        return .{ .width = width, .height = height, .pixels = pixels };
    }

    pub fn deinit(self: Image, gpa: std.mem.Allocator) void {
        gpa.free(self.pixels);
    }

    /// Stores a colour, clamping each channel to [0, 1].
    pub fn set(self: Image, x: usize, y: usize, c: Color) void {
        setPixel(self.pixels[self.index(x, y)..][0..3], c);
    }

    pub fn get(self: Image, x: usize, y: usize) [3]u8 {
        return self.pixels[self.index(x, y)..][0..3].*;
    }

    /// The RGB bytes of row `y`.
    pub fn row(self: Image, y: usize) []u8 {
        return self.pixels[self.index(0, y)..][0 .. self.width * 3];
    }

    /// Writes the image in binary (P6) PPM format.
    pub fn writePpm(self: Image, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print("P6\n{d} {d}\n255\n", .{ self.width, self.height });
        try w.writeAll(self.pixels);
    }

    pub fn savePpm(self: Image, io: std.Io, path: []const u8) !void {
        const file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);
        var buf: [64 * 1024]u8 = undefined;
        var fw: std.Io.File.Writer = .init(file, io, &buf);
        try self.writePpm(&fw.interface);
        try fw.interface.flush();
    }

    /// Writes the image in PNG format: 8-bit RGB, deflate-compressed, with no
    /// filtering.
    pub fn writePng(self: Image, gpa: std.mem.Allocator, w: *std.Io.Writer) !void {
        var header: [13]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], @intCast(self.width), .big);
        std.mem.writeInt(u32, header[4..8], @intCast(self.height), .big);
        // 8 bits per channel, RGB, deflate, no filtering, no interlacing.
        header[8..13].* = .{ 8, 2, 0, 0, 0 };

        // The chunk's length comes first, so the compressed data is collected
        // before it is written. The compressor needs room for at least 8 bytes.
        var data: std.Io.Writer.Allocating = try .initCapacity(gpa, 64 * 1024);
        defer data.deinit();
        const window = try gpa.alloc(u8, std.compress.flate.max_window_len);
        defer gpa.free(window);
        var compress: std.compress.flate.Compress = try .init(&data.writer, window, .zlib, .default);
        for (0..self.height) |y| {
            // Each scanline starts with its filter type, 0 for none.
            try compress.writer.writeByte(0);
            try compress.writer.writeAll(self.row(y));
        }
        try compress.finish();

        try w.writeAll("\x89PNG\r\n\x1a\n");
        try writeChunk(w, "IHDR", &header);
        try writeChunk(w, "IDAT", data.written());
        try writeChunk(w, "IEND", "");
    }

    pub fn savePng(self: Image, gpa: std.mem.Allocator, io: std.Io, path: []const u8) !void {
        const file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);
        var buf: [64 * 1024]u8 = undefined;
        var fw: std.Io.File.Writer = .init(file, io, &buf);
        try self.writePng(gpa, &fw.interface);
        try fw.interface.flush();
    }

    fn index(self: Image, x: usize, y: usize) usize {
        std.debug.assert(x < self.width and y < self.height);
        return (y * self.width + x) * 3;
    }
};

fn writeChunk(w: *std.Io.Writer, kind: *const [4]u8, data: []const u8) std.Io.Writer.Error!void {
    try w.writeInt(u32, @intCast(data.len), .big);
    try w.writeAll(kind);
    try w.writeAll(data);
    var crc: std.hash.Crc32 = .init();
    crc.update(kind);
    crc.update(data);
    try w.writeInt(u32, crc.final(), .big);
}

/// Writes a colour to an RGB pixel, clamping each channel to [0, 1].
pub fn setPixel(px: *[3]u8, c: Color) void {
    px.* = .{ toByte(c.r), toByte(c.g), toByte(c.b) };
}

fn toByte(v: f64) u8 {
    // Written so that NaN becomes 0, like a saturating cast in Rust.
    if (!(v > 0)) return 0;
    return @intFromFloat(255.99 * @min(v, 1));
}

test "set clamps" {
    const gpa = std.testing.allocator;
    const img: Image = try .init(gpa, 2, 1);
    defer img.deinit(gpa);
    img.set(1, 0, .init(2, 0.5, -1));
    try std.testing.expectEqual([3]u8{ 0, 0, 0 }, img.get(0, 0));
    try std.testing.expectEqual([3]u8{ 255, 127, 0 }, img.get(1, 0));
}

test "ppm header" {
    const gpa = std.testing.allocator;
    const img: Image = try .init(gpa, 3, 2);
    defer img.deinit(gpa);
    var out: std.Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    try img.writePpm(&out.writer);
    try std.testing.expectStringStartsWith(out.written(), "P6\n3 2\n255\n");
    try std.testing.expectEqual(11 + 3 * 2 * 3, out.written().len);
}

test "png" {
    const gpa = std.testing.allocator;
    const width = 200;
    const height = 120;
    const img: Image = try .init(gpa, width, height);
    defer img.deinit(gpa);
    for (0..height) |y| {
        for (0..width) |x| {
            const fx: f64 = @floatFromInt(x);
            const fy: f64 = @floatFromInt(y);
            const fz: f64 = @floatFromInt((x + y) % 7);
            img.set(x, y, .init(fx / width, fy / height, fz / 7));
        }
    }
    var out: std.Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    try img.writePng(gpa, &out.writer);
    const png = out.written();

    var r: std.Io.Reader = .fixed(png);
    try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", try r.take(8));
    // Splits the PNG into its chunks, checking their order and CRCs.
    var chunks: [3][]const u8 = undefined;
    for (&chunks, [_]*const [4]u8{ "IHDR", "IDAT", "IEND" }) |*chunk, kind| {
        const len = try r.takeInt(u32, .big);
        const kind_and_data = try r.take(4 + len);
        try std.testing.expectEqualStrings(kind, kind_and_data[0..4]);
        try std.testing.expectEqual(std.hash.Crc32.hash(kind_and_data), try r.takeInt(u32, .big));
        chunk.* = kind_and_data[4..];
    }
    try std.testing.expectEqual(0, r.bufferedLen());
    // IEND's CRC is the same in every PNG, which checks the CRC code.
    try std.testing.expectEqualSlices(u8, "\x00\x00\x00\x00IEND\xae\x42\x60\x82", png[png.len - 12 ..]);

    const header = chunks[0];
    try std.testing.expectEqual(width, std.mem.readInt(u32, header[0..4], .big));
    try std.testing.expectEqual(height, std.mem.readInt(u32, header[4..8], .big));
    try std.testing.expectEqualSlices(u8, &.{ 8, 2, 0, 0, 0 }, header[8..13]);

    var compressed: std.Io.Reader = .fixed(chunks[1]);
    var decompress: std.compress.flate.Decompress = .init(&compressed, .zlib, &.{});
    const raw = try decompress.reader.allocRemaining(gpa, .unlimited);
    defer gpa.free(raw);
    const row_bytes = 1 + width * 3;
    try std.testing.expectEqual(row_bytes * height, raw.len);
    for (0..height) |y| {
        const line = raw[y * row_bytes ..][0..row_bytes];
        try std.testing.expectEqual(0, line[0]);
        try std.testing.expectEqualSlices(u8, img.row(y), line[1..]);
    }
}
