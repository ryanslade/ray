mod common;

use std::env;
use std::fs;
use std::path::Path;

use raytracer::render_with_threads;

#[test]
fn deterministic_across_threads() {
    let (width, height) = (40, 30);
    let camera = common::camera(width, height);
    let world = common::world();
    let render = |threads| render_with_threads(threads, width, height, 8, &camera, &world);
    let expected = render(1);
    for threads in [2, 4, 7] {
        assert!(render(threads) == expected, "{threads} threads");
    }
}

/// Renders the test scene and compares it with `tests/golden.ppm`.
///
/// After an intentional change to the output, run with `UPDATE_GOLDEN=1` to
/// accept it. On a mismatch the rendered image is written to
/// `target/golden.actual.ppm` for inspection.
#[test]
fn golden_image() {
    let (width, height) = (200, 200);
    let camera = common::camera(width, height);
    let img = raytracer::render(width, height, 100, &camera, &common::world());
    let actual = img.to_ppm();

    let golden = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/golden.ppm");
    if env::var_os("UPDATE_GOLDEN").is_some() {
        fs::write(&golden, &actual).unwrap();
        return;
    }
    let expected = fs::read(&golden).unwrap();
    if actual != expected {
        let out = Path::new(env!("CARGO_TARGET_TMPDIR"))
            .parent()
            .unwrap()
            .join("golden.actual.ppm");
        fs::write(&out, &actual).unwrap();
        panic!(
            "rendered image doesn't match {}; wrote it to {}",
            golden.display(),
            out.display()
        );
    }
}
