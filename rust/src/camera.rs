use crate::ray::Ray;
use crate::rng::Rng;
use crate::vec3::Vec3;

/// Settings for [`Camera::new`].
#[derive(Clone, Copy, Debug)]
pub struct CameraSettings {
    pub look_from: Vec3,
    pub look_at: Vec3,
    pub v_up: Vec3,
    /// Vertical field of view in degrees.
    pub vfov: f64,
    pub aspect: f64,
    pub aperture: f64,
    pub focus_dist: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct Camera {
    origin: Vec3,
    lower_left: Vec3,
    horizontal: Vec3,
    vertical: Vec3,
    u: Vec3,
    v: Vec3,
    lens_radius: f64,
}

impl Camera {
    pub fn new(s: &CameraSettings) -> Camera {
        let theta = s.vfov.to_radians();
        let half_height = (theta / 2.0).tan();
        let half_width = s.aspect * half_height;
        let w = (s.look_from - s.look_at).unit();
        let u = s.v_up.cross(w).unit();
        let v = w.cross(u);
        Camera {
            origin: s.look_from,
            lower_left: s.look_from
                - (half_width * s.focus_dist) * u
                - (half_height * s.focus_dist) * v
                - s.focus_dist * w,
            horizontal: (2.0 * half_width * s.focus_dist) * u,
            vertical: (2.0 * half_height * s.focus_dist) * v,
            u,
            v,
            lens_radius: s.aperture / 2.0,
        }
    }

    /// A ray through the viewport at normalised coordinates `(s, t)`, with its
    /// origin jittered across the lens.
    pub fn get_ray(&self, s: f64, t: f64, rng: &mut Rng) -> Ray {
        let rd = self.lens_radius * Vec3::random_in_unit_disk(rng);
        let offset = rd.x * self.u + rd.y * self.v;
        Ray::new(
            self.origin + offset,
            self.lower_left + s * self.horizontal + t * self.vertical - self.origin - offset,
        )
    }
}
