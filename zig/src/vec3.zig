const std = @import("std");

const Rng = @import("rng.zig").Rng;

pub const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub const zero: Vec3 = .init(0, 0, 0);

    pub fn init(x: f64, y: f64, z: f64) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .init(a.x + b.x, a.y + b.y, a.z + b.z);
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .init(a.x - b.x, a.y - b.y, a.z - b.z);
    }

    pub fn scale(v: Vec3, s: f64) Vec3 {
        return .init(s * v.x, s * v.y, s * v.z);
    }

    pub fn div(v: Vec3, s: f64) Vec3 {
        return .init(v.x / s, v.y / s, v.z / s);
    }

    pub fn neg(v: Vec3) Vec3 {
        return .init(-v.x, -v.y, -v.z);
    }

    pub fn dot(a: Vec3, b: Vec3) f64 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .init(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x,
        );
    }

    pub fn lengthSquared(v: Vec3) f64 {
        return v.dot(v);
    }

    pub fn length(v: Vec3) f64 {
        return @sqrt(v.lengthSquared());
    }

    pub fn unit(v: Vec3) Vec3 {
        return v.div(v.length());
    }

    /// Rejection sampling: pick points in the enclosing cube until one lands
    /// inside.
    pub fn randomInUnitSphere(rng: *Rng) Vec3 {
        while (true) {
            const x = 2 * rng.next() - 1;
            const y = 2 * rng.next() - 1;
            const z = 2 * rng.next() - 1;
            const p: Vec3 = .init(x, y, z);
            if (p.lengthSquared() < 1) return p;
        }
    }

    pub fn randomInUnitDisk(rng: *Rng) Vec3 {
        while (true) {
            const x = 2 * rng.next() - 1;
            const y = 2 * rng.next() - 1;
            const p: Vec3 = .init(x, y, 0);
            if (p.lengthSquared() < 1) return p;
        }
    }
};

fn expectClose(expected: Vec3, actual: Vec3) !void {
    try std.testing.expect(expected.sub(actual).length() < 1e-9);
}

test "arithmetic" {
    const a: Vec3 = .init(1, 2, 3);
    const b: Vec3 = .init(4, 5, 6);
    try expectClose(.init(5, 7, 9), a.add(b));
    try expectClose(.init(2, 4, 6), a.scale(2));
    try std.testing.expectEqual(32, a.dot(b));
    try expectClose(.init(-3, 6, -3), a.cross(b));
    try std.testing.expectApproxEqAbs(1, b.unit().length(), 1e-9);
}
