const std = @import("std");

const Camera = @import("camera.zig").Camera;
const Color = @import("color.zig").Color;
const image = @import("image.zig");
const Image = image.Image;
const Ray = @import("ray.zig").Ray;
const Rng = @import("rng.zig").Rng;
const World = @import("world.zig").World;

const max_depth = 50;
const sky_blue: Color = .init(0.5, 0.7, 1);

/// The colour seen along a ray, following up to 50 bounces.
pub fn rayColor(world: World, ray_in: Ray, rng: *Rng) Color {
    var ray = ray_in;
    // The product of the attenuations of every surface hit so far.
    var attenuation: Color = .white;
    for (0..max_depth + 1) |depth| {
        const hit = world.hit(ray, 0.001, std.math.floatMax(f64)) orelse
            return attenuation.mul(sky(ray));
        if (depth == max_depth) break;
        const s = hit.material.scatter(ray, hit, rng) orelse break;
        attenuation = attenuation.mul(s.attenuation);
        ray = s.ray;
    }
    return .black;
}

fn sky(ray: Ray) Color {
    const t = 0.5 * (ray.direction.unit().y + 1);
    return Color.white.scale(1 - t).add(sky_blue.scale(t));
}

/// The number of threads `render` uses: one per logical CPU.
pub fn defaultThreads() usize {
    return std.Thread.getCpuCount() catch 1;
}

/// Renders the world with `samples` rays per pixel, in parallel across all
/// available cores. The caller owns the returned image.
pub fn render(
    gpa: std.mem.Allocator,
    width: usize,
    height: usize,
    samples: u32,
    camera: Camera,
    world: World,
) !Image {
    return renderWithThreads(gpa, defaultThreads(), width, height, samples, camera, world);
}

/// Like `render`, but on `threads` threads.
///
/// Each row uses its own random state seeded from the row index, so the image
/// is identical regardless of the number of threads.
pub fn renderWithThreads(
    gpa: std.mem.Allocator,
    threads: usize,
    width: usize,
    height: usize,
    samples: u32,
    camera: Camera,
    world: World,
) !Image {
    std.debug.assert(threads > 0);
    const img: Image = try .init(gpa, width, height);
    errdefer img.deinit(gpa);
    if (width == 0 or height == 0) return img;

    var job: Job = .{
        .img = img,
        .samples = samples,
        .camera = camera,
        .world = world,
    };
    const handles = try gpa.alloc(std.Thread, threads - 1);
    defer gpa.free(handles);
    var spawned: usize = 0;
    // On a spawn failure the threads already running still finish the image
    // before it is freed.
    defer for (handles[0..spawned]) |h| h.join();
    for (handles) |*h| {
        h.* = try std.Thread.spawn(.{}, Job.work, .{&job});
        spawned += 1;
    }
    job.work();
    return img;
}

const Job = struct {
    img: Image,
    samples: u32,
    camera: Camera,
    world: World,
    /// Rows vary a lot in cost (sky is cheap, spheres are expensive), so
    /// threads take rows one at a time rather than a fixed block each.
    next_row: std.atomic.Value(usize) = .init(0),

    fn work(job: *Job) void {
        while (true) {
            const y = job.next_row.fetchAdd(1, .monotonic);
            if (y >= job.img.height) return;
            job.renderRow(y);
        }
    }

    fn renderRow(job: *const Job, y: usize) void {
        const width = job.img.width;
        const height = job.img.height;
        var rng: Rng = .init(y + 1);
        const fw: f64 = @floatFromInt(width);
        const fh: f64 = @floatFromInt(height);
        const fy: f64 = @floatFromInt(height - 1 - y);
        const pixels = job.img.row(y);
        for (0..width) |x| {
            const fx: f64 = @floatFromInt(x);
            var c: Color = .black;
            for (0..job.samples) |_| {
                const u = (fx + rng.next()) / fw;
                const v = (fy + rng.next()) / fh;
                const ray = job.camera.getRay(u, v, &rng);
                c = c.add(rayColor(job.world, ray, &rng));
            }
            const fs: f64 = @floatFromInt(job.samples);
            image.setPixel(pixels[x * 3 ..][0..3], c.div(fs));
        }
    }
};
