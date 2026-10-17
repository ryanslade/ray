const std = @import("std");

const Hit = @import("hit.zig").Hit;
const Material = @import("material.zig").Material;
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vec3.zig").Vec3;

pub const Sphere = struct {
    center: Vec3,
    radius: f64,
    material: Material,

    pub fn init(center: Vec3, radius: f64, material: Material) Sphere {
        return .{ .center = center, .radius = radius, .material = material };
    }

    /// The nearest `t` in (`t_min`, `t_max`) at which the ray meets the
    /// sphere.
    pub fn intersect(self: Sphere, ray: Ray, t_min: f64, t_max: f64) ?f64 {
        const oc = ray.origin.sub(self.center);
        const a = ray.direction.dot(ray.direction);
        const b = oc.dot(ray.direction);
        const c = oc.dot(oc) - self.radius * self.radius;
        const discriminant = b * b - a * c;
        if (discriminant < 0) return null;
        const sqrt_d = @sqrt(discriminant);
        const near = (-b - sqrt_d) / a;
        if (near < t_max and near > t_min) return near;
        const far = (-b + sqrt_d) / a;
        if (far < t_max and far > t_min) return far;
        return null;
    }

    pub fn hit(self: Sphere, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        const t = self.intersect(ray, t_min, t_max) orelse return null;
        return self.hitAt(ray, t);
    }

    /// The hit record for a `t` returned by `intersect`.
    pub fn hitAt(self: Sphere, ray: Ray, t: f64) Hit {
        const point = ray.at(t);
        return .{
            .t = t,
            .point = point,
            .normal = point.sub(self.center).div(self.radius),
            .material = self.material,
        };
    }
};

test "hit" {
    const s: Sphere = .init(.init(0, 0, -1), 0.5, .{ .dielectric = .{ .ref_index = 1.5 } });
    const towards: Ray = .init(.zero, .init(0, 0, -1));
    const inf = std.math.inf(f64);

    const h = s.hit(towards, 0, inf) orelse return error.TestExpectedHit;
    try std.testing.expectEqual(0.5, h.t);
    try std.testing.expectEqual(Vec3.init(0, 0, 1), h.normal);

    const far = s.hit(towards, 0.6, inf) orelse return error.TestExpectedHit;
    try std.testing.expectEqual(1.5, far.t);

    const away: Ray = .init(.zero, .init(0, 1, 0));
    try std.testing.expectEqual(null, s.hit(away, 0, inf));
}
