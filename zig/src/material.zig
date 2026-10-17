const std = @import("std");

const Color = @import("color.zig").Color;
const Hit = @import("hit.zig").Hit;
const Ray = @import("ray.zig").Ray;
const Rng = @import("rng.zig").Rng;
const Vec3 = @import("vec3.zig").Vec3;

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,
    dielectric: Dielectric,

    pub const Lambertian = struct { albedo: Color };

    pub const Metal = struct {
        albedo: Color,
        fuzz: f64,

        /// `fuzz` is clamped to [0, 1]: 0 is a perfect mirror.
        pub fn init(albedo: Color, fuzz: f64) Metal {
            return .{ .albedo = albedo, .fuzz = std.math.clamp(fuzz, 0, 1) };
        }
    };

    pub const Dielectric = struct { ref_index: f64 };

    pub const Scatter = struct {
        attenuation: Color,
        ray: Ray,
    };

    /// Returns the attenuation and scattered ray, or null if the ray is
    /// absorbed.
    pub fn scatter(self: Material, ray_in: Ray, hit: Hit, rng: *Rng) ?Scatter {
        const point = hit.point;
        const normal = hit.normal;
        switch (self) {
            .lambertian => |m| {
                const target = point.add(normal).add(Vec3.randomInUnitSphere(rng));
                return .{ .attenuation = m.albedo, .ray = .init(point, target.sub(point)) };
            },
            .metal => |m| {
                const reflected = reflect(ray_in.direction.unit(), normal);
                const direction = reflected.add(Vec3.randomInUnitSphere(rng).scale(m.fuzz));
                if (direction.dot(normal) > 0) {
                    return .{ .attenuation = m.albedo, .ray = .init(point, direction) };
                }
                return null;
            },
            .dielectric => |m| {
                const d = ray_in.direction;
                const d_dot_n = d.dot(normal);
                const outward_normal, const ni_over_nt, const cosine = if (d_dot_n > 0)
                    .{ normal.neg(), m.ref_index, m.ref_index * d_dot_n / d.length() }
                else
                    .{ normal, 1 / m.ref_index, -d_dot_n / d.length() };
                const direction = if (refract(d, outward_normal, ni_over_nt)) |refracted|
                    if (rng.next() >= schlick(cosine, m.ref_index)) refracted else reflect(d, normal)
                else
                    reflect(d, normal);
                return .{ .attenuation = .white, .ray = .init(point, direction) };
            },
        }
    }
};

fn reflect(v: Vec3, n: Vec3) Vec3 {
    return v.sub(n.scale(2 * v.dot(n)));
}

fn refract(v: Vec3, n: Vec3, ni_over_nt: f64) ?Vec3 {
    const uv = v.unit();
    const dt = uv.dot(n);
    const discriminant = 1 - ni_over_nt * ni_over_nt * (1 - dt * dt);
    if (discriminant > 0) {
        return uv.sub(n.scale(dt)).scale(ni_over_nt).sub(n.scale(@sqrt(discriminant)));
    }
    return null;
}

/// Schlick's approximation for reflectance at a given angle.
fn schlick(cosine: f64, ref_index: f64) f64 {
    var r0 = (1 - ref_index) / (1 + ref_index);
    r0 = r0 * r0;
    // Multiplied out rather than using std.math.pow, so that the result
    // matches the Rust version exactly.
    const x = 1 - cosine;
    const x2 = x * x;
    return r0 + (1 - r0) * x2 * x2 * x;
}

test "total internal reflection" {
    const n: Vec3 = .init(0, 1, 0);
    const grazing: Vec3 = .init(1, -0.1, 0);
    try std.testing.expectEqual(null, refract(grazing, n, 1.5));
}

test "refracts head on" {
    const n: Vec3 = .init(0, 1, 0);
    const down: Vec3 = .init(0, -1, 0);
    const r = refract(down, n, 1.0 / 1.5) orelse return error.TestExpectedRefraction;
    try std.testing.expect(r.sub(down).length() < 1e-9);
}

test "metal fuzz is clamped" {
    try std.testing.expectEqual(1, Material.Metal.init(.white, 2).fuzz);
}
