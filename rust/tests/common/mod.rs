//! The scene used by the tests and benchmark, matching the Go and OCaml
//! versions.

use raytracer::{Camera, CameraSettings, Color, Material, Sphere, Vec3, World};

pub fn world() -> World {
    World::new(vec![
        Sphere::new(
            Vec3::new(0.0, -100.5, -1.0),
            100.0,
            Material::lambertian(Color::new(0.5, 0.5, 0.5)),
        ),
        Sphere::new(
            Vec3::new(0.0, 0.0, -1.0),
            1.0,
            Material::metal(Color::new(0.8, 0.8, 0.8), 0.2),
        ),
        Sphere::new(Vec3::new(1.5, 0.0, -1.0), 1.0, Material::dielectric(1.5)),
    ])
}

pub fn camera(width: usize, height: usize) -> Camera {
    let look_from = Vec3::new(1.0, 1.0, 1.0);
    let look_at = Vec3::new(0.0, 0.0, -1.0);
    Camera::new(&CameraSettings {
        look_from,
        look_at,
        v_up: Vec3::new(0.0, 1.0, 0.0),
        vfov: 90.0,
        aspect: width as f64 / height as f64,
        aperture: 0.01,
        focus_dist: (look_from - look_at).length(),
    })
}
