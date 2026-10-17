//! A simple ray tracer, based on the book Ray Tracing in One Weekend.

pub const Camera = @import("camera.zig").Camera;
pub const Color = @import("color.zig").Color;
pub const Hit = @import("hit.zig").Hit;
pub const Image = @import("image.zig").Image;
pub const Material = @import("material.zig").Material;
pub const Ray = @import("ray.zig").Ray;
pub const Rng = @import("rng.zig").Rng;
pub const Sphere = @import("sphere.zig").Sphere;
pub const Vec3 = @import("vec3.zig").Vec3;
pub const World = @import("world.zig").World;

const rendering = @import("render.zig");
pub const defaultThreads = rendering.defaultThreads;
pub const rayColor = rendering.rayColor;
pub const render = rendering.render;
pub const renderWithThreads = rendering.renderWithThreads;

test {
    _ = @import("image.zig");
    _ = @import("material.zig");
    _ = @import("rng.zig");
    _ = @import("sphere.zig");
    _ = @import("vec3.zig");
    _ = @import("world.zig");
}
