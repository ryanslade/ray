const std = @import("std");

const options = @import("options");
const rt = @import("raytracer");
const scene = @import("scene");

const gpa = std.testing.allocator;
const io = std.testing.io;

test "deterministic across threads" {
    const width = 40;
    const height = 30;
    const camera = scene.camera(width, height);
    const expected = try rt.renderWithThreads(gpa, 1, width, height, 8, camera, scene.world);
    defer expected.deinit(gpa);
    for ([_]usize{ 2, 4, 7 }) |threads| {
        const img = try rt.renderWithThreads(gpa, threads, width, height, 8, camera, scene.world);
        defer img.deinit(gpa);
        try std.testing.expectEqualSlices(u8, expected.pixels, img.pixels);
    }
}

// Renders the test scene and compares it with `tests/golden.ppm`.
//
// After an intentional change to the output, run with `UPDATE_GOLDEN=1` to
// accept it. On a mismatch the rendered image is written to
// `tests/golden.actual.ppm` for inspection.
test "golden image" {
    const width = 200;
    const height = 200;
    const img = try rt.render(gpa, width, height, 100, scene.camera(width, height), scene.world);
    defer img.deinit(gpa);
    var actual: std.Io.Writer.Allocating = .init(gpa);
    defer actual.deinit();
    try img.writePpm(&actual.writer);

    const cwd = std.Io.Dir.cwd();
    if (try std.testing.environ.contains(gpa, "UPDATE_GOLDEN")) {
        try cwd.writeFile(io, .{ .sub_path = options.golden_path, .data = actual.written() });
        return;
    }
    const expected = try cwd.readFileAlloc(io, options.golden_path, gpa, .unlimited);
    defer gpa.free(expected);
    if (!std.mem.eql(u8, expected, actual.written())) {
        try cwd.writeFile(io, .{ .sub_path = options.actual_path, .data = actual.written() });
        std.debug.print("rendered image doesn't match {s}; wrote it to {s}\n", .{
            options.golden_path,
            options.actual_path,
        });
        return error.TestGoldenMismatch;
    }
}
