//! Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with
//! 50 samples per pixel. Usage: cargo bench -- [iterations] [threads]

#[path = "../tests/common/mod.rs"]
mod common;

use std::env;
use std::hint::black_box;
use std::thread;
use std::time::Instant;

use raytracer::render_with_threads;

fn main() {
    // cargo bench passes --bench, so skip flags.
    let mut args = env::args().skip(1).filter(|a| !a.starts_with('-'));
    let mut arg = |default: usize| args.next().map_or(default, |a| a.parse().unwrap());
    let iterations = arg(20);
    let threads = arg(thread::available_parallelism().map_or(1, |n| n.get()));

    let (width, height) = (100, 100);
    let camera = common::camera(width, height);
    let world = common::world();
    let run = || {
        black_box(render_with_threads(
            threads, width, height, 50, &camera, &world,
        ))
    };

    run();
    let start = Instant::now();
    for _ in 0..iterations {
        run();
    }
    let elapsed = start.elapsed();
    println!(
        "{iterations} iterations on {threads} threads: {:.2} ms/op",
        elapsed.as_secs_f64() * 1000.0 / iterations as f64
    );
}
