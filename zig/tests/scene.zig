//! The scene used by the tests and benchmark, matching the other versions.

const std = @import("std");

const rt = @import("raytracer");
const Camera = rt.Camera;
const Sphere = rt.Sphere;
const Vec3 = rt.Vec3;
const World = rt.World;

const spheres = [_]Sphere{
    .init(.init(0, -100.5, -1), 100, .{ .lambertian = .{ .albedo = .init(0.5, 0.5, 0.5) } }),
    .init(.init(0, 0, -1), 1, .{ .metal = .init(.init(0.8, 0.8, 0.8), 0.2) }),
    .init(.init(1.5, 0, -1), 1, .{ .dielectric = .{ .ref_index = 1.5 } }),
};

pub fn world(gpa: std.mem.Allocator) !World {
    return .init(gpa, &spheres);
}

pub fn camera(width: usize, height: usize) Camera {
    const look_from: Vec3 = .init(1, 1, 1);
    const look_at: Vec3 = .init(0, 0, -1);
    const fw: f64 = @floatFromInt(width);
    const fh: f64 = @floatFromInt(height);
    return .init(.{
        .look_from = look_from,
        .look_at = look_at,
        .v_up = .init(0, 1, 0),
        .vfov = 90,
        .aspect = fw / fh,
        .aperture = 0.01,
        .focus_dist = look_from.sub(look_at).length(),
    });
}
