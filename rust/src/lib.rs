//! A simple ray tracer, based on the book Ray Tracing in One Weekend.

mod camera;
mod color;
mod hit;
mod image;
mod material;
mod ray;
mod render;
mod rng;
mod sphere;
mod vec3;
mod world;

pub use camera::{Camera, CameraSettings};
pub use color::Color;
pub use hit::Hit;
pub use image::Image;
pub use material::Material;
pub use ray::Ray;
pub use render::{ray_color, render, render_with_threads};
pub use rng::Rng;
pub use sphere::Sphere;
pub use vec3::Vec3;
pub use world::World;
