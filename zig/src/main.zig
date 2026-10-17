const std = @import("std");

const rt = @import("raytracer");
const Camera = rt.Camera;
const Material = rt.Material;
const Rng = rt.Rng;
const Sphere = rt.Sphere;
const Vec3 = rt.Vec3;

const width = 800;
const height = 450;
const samples = 100;

fn randomWorld(gpa: std.mem.Allocator, rng: *Rng) ![]Sphere {
    var spheres: std.ArrayList(Sphere) = .empty;
    errdefer spheres.deinit(gpa);
    try spheres.append(gpa, .init(.init(0, -1000, -1), 1000, .{ .lambertian = .{ .albedo = .init(0.5, 0.5, 0.5) } }));

    var a: f64 = -11;
    while (a < 11) : (a += 1) {
        var b: f64 = -11;
        while (b < 11) : (b += 1) {
            const x = a + 0.9 * rng.next();
            const z = b + 0.9 * rng.next();
            const center: Vec3 = .init(x, 0.2, z);
            if (center.sub(.init(4, 0.2, 0)).length() <= 0.9) continue;
            const r = rng.next() * rng.next();
            const g = rng.next() * rng.next();
            const bl = rng.next() * rng.next();
            try spheres.append(gpa, .init(center, 0.2, .{ .lambertian = .{ .albedo = .init(r, g, bl) } }));
        }
    }

    try spheres.appendSlice(gpa, &.{
        .init(.init(4, 1, 0), 1, .{ .metal = .init(.init(0.8, 0.6, 0.2), 0.1) }),
        .init(.init(0, 1, 0), 1, .{ .dielectric = .{ .ref_index = 1.5 } }),
        .init(.init(-4, 1, 0), 1, .{ .metal = .init(.init(0.8, 0.8, 0.8), 0.2) }),
    });
    return spheres.toOwnedSlice(gpa);
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const output = if (args.len > 1) args[1] else "out.ppm";

    std.debug.print("Generating world\n", .{});
    var rng: Rng = .init(1);
    const spheres = try randomWorld(arena, &rng);
    const look_from: Vec3 = .init(3, 2, 3);
    const look_at: Vec3 = .init(0, 0, -1);
    const camera: Camera = .init(.{
        .look_from = look_from,
        .look_at = look_at,
        .v_up = .init(0, 1, 0),
        .vfov = 90,
        .aspect = @as(f64, width) / height,
        .aperture = 0.01,
        .focus_dist = look_from.sub(look_at).length(),
    });
    std.debug.print("Rendering on {d} threads\n", .{rt.defaultThreads()});
    const img = try rt.render(init.gpa, width, height, samples, camera, .init(spheres));
    defer img.deinit(init.gpa);
    img.savePpm(init.io, output) catch |err| {
        std.debug.print("Writing {s}: {t}\n", .{ output, err });
        std.process.exit(1);
    };
    std.debug.print("Wrote {s}\n", .{output});
}
