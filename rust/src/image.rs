use std::fs::File;
use std::io::{self, BufWriter, Write};
use std::path::Path;

use crate::color::Color;

/// An 8-bit RGB image. Row 0 is the top.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Image {
    width: usize,
    height: usize,
    pixels: Vec<u8>,
}

impl Image {
    pub fn new(width: usize, height: usize) -> Image {
        Image {
            width,
            height,
            pixels: vec![0; width * height * 3],
        }
    }

    pub fn width(&self) -> usize {
        self.width
    }

    pub fn height(&self) -> usize {
        self.height
    }

    /// Stores a colour, clamping each channel to [0, 1].
    pub fn set(&mut self, x: usize, y: usize, c: Color) {
        let i = self.index(x, y);
        set_pixel(&mut self.pixels.as_chunks_mut::<3>().0[i], c);
    }

    pub fn get(&self, x: usize, y: usize) -> (u8, u8, u8) {
        let [r, g, b] = self.pixels.as_chunks::<3>().0[self.index(x, y)];
        (r, g, b)
    }

    /// Iterates over the rows as mutable RGB byte slices, so that they can be
    /// filled in independently (e.g. from different threads).
    pub(crate) fn rows_mut(&mut self) -> impl Iterator<Item = &mut [u8]> {
        self.pixels.chunks_exact_mut(self.width * 3)
    }

    /// Binary (P6) PPM encoding.
    pub fn to_ppm(&self) -> Vec<u8> {
        let mut out = format!("P6\n{} {}\n255\n", self.width, self.height).into_bytes();
        out.extend_from_slice(&self.pixels);
        out
    }

    pub fn save_ppm(&self, path: impl AsRef<Path>) -> io::Result<()> {
        let mut w = BufWriter::new(File::create(path)?);
        w.write_all(&self.to_ppm())?;
        w.flush()
    }

    fn index(&self, x: usize, y: usize) -> usize {
        assert!(x < self.width && y < self.height, "pixel out of bounds");
        y * self.width + x
    }
}

/// Writes a colour to an RGB pixel, clamping each channel to [0, 1].
pub(crate) fn set_pixel(px: &mut [u8; 3], c: Color) {
    // `as` saturates, so negative channels become 0.
    let to_byte = |v: f64| (255.99 * v.min(1.0)) as u8;
    px[0] = to_byte(c.r);
    px[1] = to_byte(c.g);
    px[2] = to_byte(c.b);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_clamps() {
        let mut img = Image::new(2, 1);
        img.set(1, 0, Color::new(2.0, 0.5, -1.0));
        assert_eq!(img.get(0, 0), (0, 0, 0));
        assert_eq!(img.get(1, 0), (255, 127, 0));
    }

    #[test]
    fn ppm_header() {
        let ppm = Image::new(3, 2).to_ppm();
        assert!(ppm.starts_with(b"P6\n3 2\n255\n"));
        assert_eq!(ppm.len(), 11 + 3 * 2 * 3);
    }
}
