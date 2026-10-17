const std = @import("std");

const Hit = @import("hit.zig").Hit;
const Material = @import("material.zig").Material;
const Ray = @import("ray.zig").Ray;
const Sphere = @import("sphere.zig").Sphere;

/// The objects in a scene. It doesn't own `spheres`.
pub const World = struct {
    spheres: []const Sphere,

    pub fn init(spheres: []const Sphere) World {
        return .{ .spheres = spheres };
    }

    /// Returns the closest hit, shrinking `t_max` as nearer objects are found.
    pub fn hit(self: World, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        // Only the hit record for the closest sphere is ever needed, so just
        // track which one it is until the end.
        var closest: ?*const Sphere = null;
        var t_closest = t_max;
        for (self.spheres) |*sphere| {
            if (sphere.intersect(ray, t_min, t_closest)) |t| {
                closest = sphere;
                t_closest = t;
            }
        }
        const sphere = closest orelse return null;
        return sphere.hitAt(ray, t_closest);
    }
};

test "closest hit" {
    const m: Material = .{ .dielectric = .{ .ref_index = 1.5 } };
    const world: World = .init(&.{
        .init(.init(0, 0, -5), 1, m),
        .init(.init(0, 0, -2), 0.5, m),
    });
    const ray: Ray = .init(.zero, .init(0, 0, -1));
    const h = world.hit(ray, 0, std.math.inf(f64)) orelse return error.TestExpectedHit;
    try std.testing.expectEqual(1.5, h.t);
}
