use std::env;
use std::process::ExitCode;
use std::thread;

use raytracer::{Camera, CameraSettings, Color, Material, Rng, Sphere, Vec3, World, render};

const WIDTH: usize = 800;
const HEIGHT: usize = 450;
const SAMPLES: u32 = 100;

fn random_world(rng: &mut Rng) -> World {
    let ground = Sphere::new(
        Vec3::new(0.0, -1000.0, -1.0),
        1000.0,
        Material::lambertian(Color::new(0.5, 0.5, 0.5)),
    );

    let mut small_sphere = |a: f64, b: f64| {
        let x = a + 0.9 * rng.next_f64();
        let z = b + 0.9 * rng.next_f64();
        let center = Vec3::new(x, 0.2, z);
        if (center - Vec3::new(4.0, 0.2, 0.0)).length() <= 0.9 {
            return None;
        }
        let mut channel = || rng.next_f64() * rng.next_f64();
        let albedo = Color::new(channel(), channel(), channel());
        Some(Sphere::new(center, 0.2, Material::lambertian(albedo)))
    };
    let grid = || (-11..11).map(f64::from);
    let small_spheres: Vec<Sphere> = grid()
        .flat_map(|a| grid().map(move |b| (a, b)))
        .filter_map(|(a, b)| small_sphere(a, b))
        .collect();

    let large_spheres = [
        Sphere::new(
            Vec3::new(4.0, 1.0, 0.0),
            1.0,
            Material::metal(Color::new(0.8, 0.6, 0.2), 0.1),
        ),
        Sphere::new(Vec3::new(0.0, 1.0, 0.0), 1.0, Material::dielectric(1.5)),
        Sphere::new(
            Vec3::new(-4.0, 1.0, 0.0),
            1.0,
            Material::metal(Color::new(0.8, 0.8, 0.8), 0.2),
        ),
    ];

    std::iter::once(ground)
        .chain(small_spheres)
        .chain(large_spheres)
        .collect()
}

fn main() -> ExitCode {
    let output = env::args().nth(1).unwrap_or_else(|| "out.png".to_string());
    eprintln!("Generating world");
    let world = random_world(&mut Rng::new(1));
    let look_from = Vec3::new(3.0, 2.0, 3.0);
    let look_at = Vec3::new(0.0, 0.0, -1.0);
    let camera = Camera::new(&CameraSettings {
        look_from,
        look_at,
        v_up: Vec3::new(0.0, 1.0, 0.0),
        vfov: 90.0,
        aspect: WIDTH as f64 / HEIGHT as f64,
        aperture: 0.01,
        focus_dist: (look_from - look_at).length(),
    });
    let threads = thread::available_parallelism().map_or(1, |n| n.get());
    eprintln!("Rendering on {threads} threads");
    let img = render(WIDTH, HEIGHT, SAMPLES, &camera, &world);
    if let Err(e) = img.save_png(&output) {
        eprintln!("Writing {output}: {e}");
        return ExitCode::FAILURE;
    }
    eprintln!("Wrote {output}");
    ExitCode::SUCCESS
}
