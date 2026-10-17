const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raytracer = b.addModule("raytracer", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "raytracer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "raytracer", .module = raytracer }},
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    b.step("run", "Render the example scene").dependOn(&run_cmd.step);

    // The scene shared by the tests and the benchmark.
    const scene = b.createModule(.{
        .root_source_file = b.path("tests/scene.zig"),
        .imports = &.{.{ .name = "raytracer", .module = raytracer }},
    });

    const options = b.addOptions();
    options.addOption([]const u8, "golden_path", b.pathFromRoot("tests/golden.ppm"));
    options.addOption([]const u8, "actual_path", b.pathFromRoot("tests/golden.actual.ppm"));

    const unit_tests = b.addTest(.{ .root_module = raytracer });
    const render_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/render.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raytracer", .module = raytracer },
                .{ .name = "scene", .module = scene },
                .{ .name = "options", .module = options.createModule() },
            },
        }),
    });
    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);
    test_step.dependOn(&b.addRunArtifact(render_tests).step);

    const bench = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/bench.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raytracer", .module = raytracer },
                .{ .name = "scene", .module = scene },
            },
        }),
    });
    const run_bench = b.addRunArtifact(bench);
    if (b.args) |args| run_bench.addArgs(args);
    b.step("bench", "Run the benchmark").dependOn(&run_bench.step);
}
