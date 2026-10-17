const Material = @import("material.zig").Material;
const Vec3 = @import("vec3.zig").Vec3;

pub const Hit = struct {
    t: f64,
    point: Vec3,
    normal: Vec3,
    material: Material,
};
