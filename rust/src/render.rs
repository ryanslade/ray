use std::num::NonZeroUsize;
use std::sync::Mutex;
use std::thread;

use crate::camera::Camera;
use crate::color::Color;
use crate::image::{self, Image};
use crate::ray::Ray;
use crate::rng::Rng;
use crate::world::World;

const MAX_DEPTH: u32 = 50;
const SKY_BLUE: Color = Color::new(0.5, 0.7, 1.0);

/// The colour seen along a ray, following up to 50 bounces.
pub fn ray_color(world: &World, ray: &Ray, rng: &mut Rng) -> Color {
    let mut ray = *ray;
    // The product of the attenuations of every surface hit so far.
    let mut attenuation = Color::WHITE;
    for depth in 0..=MAX_DEPTH {
        let Some(hit) = world.hit(&ray, 0.001, f64::MAX) else {
            return attenuation * sky(&ray);
        };
        if depth == MAX_DEPTH {
            break;
        }
        match hit.material.scatter(&ray, &hit, rng) {
            Some((a, scattered)) => {
                attenuation = attenuation * a;
                ray = scattered;
            }
            None => break,
        }
    }
    Color::BLACK
}

fn sky(ray: &Ray) -> Color {
    let t = 0.5 * (ray.direction.unit().y + 1.0);
    (1.0 - t) * Color::WHITE + t * SKY_BLUE
}

/// Renders the world with `samples` rays per pixel, in parallel across all
/// available cores.
pub fn render(width: usize, height: usize, samples: u32, camera: &Camera, world: &World) -> Image {
    let threads = thread::available_parallelism().map_or(1, NonZeroUsize::get);
    render_with_threads(threads, width, height, samples, camera, world)
}

/// Like [`render`], but on `threads` threads.
///
/// Each row uses its own random state seeded from the row index, so the image
/// is identical regardless of the number of threads.
///
/// # Panics
///
/// If `threads` is zero.
pub fn render_with_threads(
    threads: usize,
    width: usize,
    height: usize,
    samples: u32,
    camera: &Camera,
    world: &World,
) -> Image {
    assert!(threads > 0, "threads must be positive");
    let mut img = Image::new(width, height);
    if width == 0 || height == 0 {
        return img;
    }
    // Rows vary a lot in cost (sky is cheap, spheres are expensive), so
    // threads take rows one at a time rather than a fixed block each.
    let rows = Mutex::new(img.rows_mut().enumerate());
    let worker = || {
        loop {
            // Bind the row first so the lock is released before rendering.
            let next = rows.lock().unwrap().next();
            let Some((y, row)) = next else { break };
            render_row(row, y, width, height, samples, camera, world);
        }
    };
    thread::scope(|s| {
        for _ in 1..threads {
            s.spawn(worker);
        }
        worker();
    });
    drop(rows);
    img
}

fn render_row(
    row: &mut [u8],
    y: usize,
    width: usize,
    height: usize,
    samples: u32,
    camera: &Camera,
    world: &World,
) {
    let mut rng = Rng::new(y as u64 + 1);
    for (x, px) in row.as_chunks_mut::<3>().0.iter_mut().enumerate() {
        let mut c = Color::BLACK;
        for _ in 0..samples {
            let u = (x as f64 + rng.next_f64()) / width as f64;
            let v = ((height - 1 - y) as f64 + rng.next_f64()) / height as f64;
            let ray = camera.get_ray(u, v, &mut rng);
            c = c + ray_color(world, &ray, &mut rng);
        }
        image::set_pixel(px, c / f64::from(samples));
    }
}
