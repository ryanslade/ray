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

    fn index(self: Image, x: usize, y: usize) usize {
        std.debug.assert(x < self.width and y < self.height);
        return (y * self.width + x) * 3;
    }
};

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
