//! Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with
//! 50 samples per pixel. Usage: zig build bench -- [iterations] [threads]

const std = @import("std");

const rt = @import("raytracer");
const scene = @import("scene");

const width = 100;
const height = 100;

fn run(gpa: std.mem.Allocator, threads: usize, camera: rt.Camera) !void {
    const img = try rt.renderWithThreads(gpa, threads, width, height, 50, camera, scene.world);
    defer img.deinit(gpa);
    std.mem.doNotOptimizeAway(img.pixels.ptr);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const iterations = if (args.len > 1) try std.fmt.parseInt(usize, args[1], 10) else 20;
    const threads = if (args.len > 2) try std.fmt.parseInt(usize, args[2], 10) else rt.defaultThreads();

    const camera = scene.camera(width, height);
    try run(init.gpa, threads, camera);
    const start: std.Io.Clock.Timestamp = .now(init.io, .awake);
    for (0..iterations) |_| try run(init.gpa, threads, camera);
    const elapsed = start.untilNow(init.io);
    const ns: f64 = @floatFromInt(elapsed.raw.toNanoseconds());
    const n: f64 = @floatFromInt(iterations);
    std.debug.print("{d} iterations on {d} threads: {d:.2} ms/op\n", .{ iterations, threads, ns / 1e6 / n });
}
