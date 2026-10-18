const std = @import("std");

const Hit = @import("hit.zig").Hit;
const Material = @import("material.zig").Material;
const Ray = @import("ray.zig").Ray;
const Rng = @import("rng.zig").Rng;
const Sphere = @import("sphere.zig").Sphere;
const Vec3 = @import("vec3.zig").Vec3;

/// How many spheres the closest-hit loop tests at once.
const lanes = 4;
const Lanes = @Vector(lanes, f64);

/// The centres and squared radii of `lanes` spheres, stored as a structure of
/// arrays so that the closest-hit loop can work on all of them at once. A
/// partly filled block is padded with spheres of radius squared -inf, whose
/// discriminant is -inf (or NaN for a zero-length ray), so they never hit.
const Block = struct {
    x: Lanes,
    y: Lanes,
    z: Lanes,
    radius_squared: Lanes,
};

/// The objects in a scene. It doesn't own `spheres`, but does own `blocks`.
pub const World = struct {
    spheres: []const Sphere,
    blocks: []const Block,

    pub fn init(gpa: std.mem.Allocator, spheres: []const Sphere) !World {
        const blocks = try gpa.alloc(Block, std.math.divCeil(usize, spheres.len, lanes) catch unreachable);
        for (blocks, 0..) |*block, i| {
            var x: [lanes]f64 = @splat(0);
            var y: [lanes]f64 = @splat(0);
            var z: [lanes]f64 = @splat(0);
            var radius_squared: [lanes]f64 = @splat(-std.math.inf(f64));
            const chunk = spheres[i * lanes .. @min(spheres.len, (i + 1) * lanes)];
            for (chunk, 0..) |s, l| {
                x[l] = s.center.x;
                y[l] = s.center.y;
                z[l] = s.center.z;
                radius_squared[l] = s.radius * s.radius;
            }
            block.* = .{ .x = x, .y = y, .z = z, .radius_squared = radius_squared };
        }
        return .{ .spheres = spheres, .blocks = blocks };
    }

    pub fn deinit(self: World, gpa: std.mem.Allocator) void {
        gpa.free(self.blocks);
    }

    /// Returns the closest hit, shrinking `t_max` as nearer objects are found.
    ///
    /// This finds the same hit as calling `Sphere.intersect` on each sphere in
    /// turn, with the same arithmetic, so renders are unchanged.
    pub fn hit(self: World, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        const o = ray.origin;
        const d = ray.direction;
        const a = d.dot(d);
        const ox: Lanes = @splat(o.x);
        const oy: Lanes = @splat(o.y);
        const oz: Lanes = @splat(o.z);
        const dx: Lanes = @splat(d.x);
        const dy: Lanes = @splat(d.y);
        const dz: Lanes = @splat(d.z);
        const zero: Lanes = @splat(0);
        // Only the hit record for the closest sphere is ever needed, so just
        // track which one it is until the end.
        var closest: ?usize = null;
        var t_closest = t_max;
        for (self.blocks, 0..) |block, i| {
            // The discriminants don't depend on t_closest, so all four are
            // computed together.
            const ocx = ox - block.x;
            const ocy = oy - block.y;
            const ocz = oz - block.z;
            const b = ocx * dx + ocy * dy + ocz * dz;
            const c = (ocx * ocx + ocy * ocy + ocz * ocz) - block.radius_squared;
            const discriminant = b * b - @as(Lanes, @splat(a)) * c;
            // Most rays miss most spheres.
            if (@reduce(.And, discriminant < zero)) continue;
            // The distances do depend on t_closest, so they are checked one
            // sphere at a time, in order, from arrays, which unlike vectors
            // can be indexed at run time.
            const bs: [lanes]f64 = b;
            const discriminants: [lanes]f64 = discriminant;
            for (bs, discriminants, 0..) |bl, disc, l| {
                if (disc < 0) continue;
                const sqrt_d = @sqrt(disc);
                const near = (-bl - sqrt_d) / a;
                const t = if (near < t_closest and near > t_min) near else t: {
                    const far = (-bl + sqrt_d) / a;
                    if (far < t_closest and far > t_min) break :t far;
                    continue;
                };
                closest = i * lanes + l;
                t_closest = t;
            }
        }
        const index = closest orelse return null;
        return self.spheres[index].hitAt(ray, t_closest);
    }
};

test "closest hit" {
    const gpa = std.testing.allocator;
    const m: Material = .{ .dielectric = .{ .ref_index = 1.5 } };
    const world: World = try .init(gpa, &.{
        .init(.init(0, 0, -5), 1, m),
        .init(.init(0, 0, -2), 0.5, m),
    });
    defer world.deinit(gpa);
    const ray: Ray = .init(.zero, .init(0, 0, -1));
    const h = world.hit(ray, 0, std.math.inf(f64)) orelse return error.TestExpectedHit;
    try std.testing.expectEqual(1.5, h.t);
}

// The blocked loop finds exactly the hit that testing each sphere in turn
// would, for every number of spheres modulo the block size.
test "matches sphere by sphere" {
    const gpa = std.testing.allocator;
    var rng: Rng = .init(1);
    const m: Material = .{ .dielectric = .{ .ref_index = 1.5 } };
    var spheres: [23]Sphere = undefined;
    for (&spheres) |*s| {
        const center: Vec3 = .init(coord(&rng, 3), coord(&rng, 3), coord(&rng, 3));
        s.* = .init(center, 0.1 + @abs(coord(&rng, 1)), m);
    }
    var rays: [2000]Ray = undefined;
    for (&rays) |*r| {
        const origin: Vec3 = .init(coord(&rng, 5), coord(&rng, 5), coord(&rng, 5));
        r.* = .init(origin, .init(coord(&rng, 1), coord(&rng, 1), coord(&rng, 1)));
    }
    const max = std.math.floatMax(f64);
    for (0..spheres.len) |n| {
        const world: World = try .init(gpa, spheres[0..n]);
        defer world.deinit(gpa);
        for (rays) |ray| {
            var want: ?Hit = null;
            var t_max = max;
            for (spheres[0..n]) |s| {
                if (s.intersect(ray, 0.001, t_max)) |t| {
                    want = s.hitAt(ray, t);
                    t_max = t;
                }
            }
            const got = world.hit(ray, 0.001, max);
            try std.testing.expectEqual(want == null, got == null);
            if (want) |w| {
                try std.testing.expectEqual(w.t, got.?.t);
                try std.testing.expectEqual(w.point, got.?.point);
                try std.testing.expectEqual(w.normal, got.?.normal);
            }
        }
    }
}

/// A random number in (-scale, scale).
fn coord(rng: *Rng, scale: f64) f64 {
    return scale * (2 * rng.next() - 1);
}
