const std = @import("std");

const Ray = @import("ray.zig").Ray;
const Rng = @import("rng.zig").Rng;
const Vec3 = @import("vec3.zig").Vec3;

pub const Camera = struct {
    origin: Vec3,
    lower_left: Vec3,
    horizontal: Vec3,
    vertical: Vec3,
    u: Vec3,
    v: Vec3,
    lens_radius: f64,

    /// Settings for `Camera.init`.
    pub const Settings = struct {
        look_from: Vec3,
        look_at: Vec3,
        v_up: Vec3,
        /// Vertical field of view in degrees.
        vfov: f64,
        aspect: f64,
        aperture: f64,
        focus_dist: f64,
    };

    pub fn init(s: Settings) Camera {
        const theta = s.vfov * (std.math.pi / 180.0);
        const half_height = @tan(theta / 2);
        const half_width = s.aspect * half_height;
        const w = s.look_from.sub(s.look_at).unit();
        const u = s.v_up.cross(w).unit();
        const v = w.cross(u);
        return .{
            .origin = s.look_from,
            .lower_left = s.look_from
                .sub(u.scale(half_width * s.focus_dist))
                .sub(v.scale(half_height * s.focus_dist))
                .sub(w.scale(s.focus_dist)),
            .horizontal = u.scale(2 * half_width * s.focus_dist),
            .vertical = v.scale(2 * half_height * s.focus_dist),
            .u = u,
            .v = v,
            .lens_radius = s.aperture / 2,
        };
    }

    /// A ray through the viewport at normalised coordinates `(s, t)`, with its
    /// origin jittered across the lens.
    pub fn getRay(self: Camera, s: f64, t: f64, rng: *Rng) Ray {
        const rd = Vec3.randomInUnitDisk(rng).scale(self.lens_radius);
        const offset = self.u.scale(rd.x).add(self.v.scale(rd.y));
        return .init(
            self.origin.add(offset),
            self.lower_left
                .add(self.horizontal.scale(s))
                .add(self.vertical.scale(t))
                .sub(self.origin)
                .sub(offset),
        );
    }
};
