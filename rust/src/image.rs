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
        save(path, &self.to_ppm())
    }

    /// PNG encoding. The pixel data is stored uncompressed, so the file is
    /// about the same size as the PPM.
    pub fn to_png(&self) -> Vec<u8> {
        let mut header = Vec::with_capacity(13);
        header.extend_from_slice(&(self.width as u32).to_be_bytes());
        header.extend_from_slice(&(self.height as u32).to_be_bytes());
        // 8 bits per channel, RGB, deflate, no filtering, no interlacing.
        header.extend_from_slice(&[8, 2, 0, 0, 0]);
        // Each scanline starts with its filter type, 0 for none.
        let mut raw = Vec::with_capacity((self.width * 3 + 1) * self.height);
        for row in self.pixels.chunks_exact(self.width * 3) {
            raw.push(0);
            raw.extend_from_slice(row);
        }
        let mut out = b"\x89PNG\r\n\x1a\n".to_vec();
        add_chunk(&mut out, b"IHDR", &header);
        add_chunk(&mut out, b"IDAT", &zlib_stored(&raw));
        add_chunk(&mut out, b"IEND", &[]);
        out
    }

    pub fn save_png(&self, path: impl AsRef<Path>) -> io::Result<()> {
        save(path, &self.to_png())
    }

    fn index(&self, x: usize, y: usize) -> usize {
        assert!(x < self.width && y < self.height, "pixel out of bounds");
        y * self.width + x
    }
}

fn save(path: impl AsRef<Path>, bytes: &[u8]) -> io::Result<()> {
    let mut w = BufWriter::new(File::create(path)?);
    w.write_all(bytes)?;
    w.flush()
}

fn crc32(bytes: &[u8]) -> u32 {
    let mut c = !0u32;
    for &b in bytes {
        c ^= u32::from(b);
        for _ in 0..8 {
            c = if c & 1 == 1 {
                0xEDB8_8320 ^ (c >> 1)
            } else {
                c >> 1
            };
        }
    }
    !c
}

fn adler32(bytes: &[u8]) -> u32 {
    let (mut a, mut b) = (1u32, 0u32);
    for &x in bytes {
        a = (a + u32::from(x)) % 65521;
        b = (b + a) % 65521;
    }
    b << 16 | a
}

/// A zlib stream holding `data` in uncompressed (stored) deflate blocks, which
/// can be at most 65535 bytes each. The standard library has no compressor,
/// and this keeps the encoder small at the cost of file size.
fn zlib_stored(data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(data.len() + data.len() / 65535 * 5 + 16);
    out.extend_from_slice(&[0x78, 0x01]);
    let mut blocks = data.chunks(65535).peekable();
    if blocks.peek().is_none() {
        // An empty final block.
        out.extend_from_slice(&[1, 0, 0, 0xFF, 0xFF]);
    }
    while let Some(block) = blocks.next() {
        out.push(u8::from(blocks.peek().is_none()));
        let len = block.len() as u16;
        out.extend_from_slice(&len.to_le_bytes());
        out.extend_from_slice(&(!len).to_le_bytes());
        out.extend_from_slice(block);
    }
    out.extend_from_slice(&adler32(data).to_be_bytes());
    out
}

fn add_chunk(out: &mut Vec<u8>, kind: &[u8; 4], data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_be_bytes());
    let start = out.len();
    out.extend_from_slice(kind);
    out.extend_from_slice(data);
    let crc = crc32(&out[start..]);
    out.extend_from_slice(&crc.to_be_bytes());
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

    /// Splits a PNG into its chunks, as (type, data) pairs.
    fn png_chunks(png: &[u8]) -> Vec<(&[u8], &[u8])> {
        let mut chunks = Vec::new();
        let mut rest = &png[8..];
        while !rest.is_empty() {
            let len = u32::from_be_bytes(rest[..4].try_into().unwrap()) as usize;
            chunks.push((&rest[4..8], &rest[8..8 + len]));
            rest = &rest[12 + len..];
        }
        chunks
    }

    /// Decodes a zlib stream made of stored deflate blocks, the only kind
    /// `to_png` writes.
    fn inflate_stored(z: &[u8]) -> Vec<u8> {
        let mut out = Vec::new();
        let mut pos = 2;
        loop {
            let header = z[pos];
            assert_eq!((header >> 1) & 3, 0, "expected a stored block");
            let len = u16::from_le_bytes([z[pos + 1], z[pos + 2]]);
            let nlen = u16::from_le_bytes([z[pos + 3], z[pos + 4]]);
            assert_eq!(nlen, !len, "NLEN");
            let len = usize::from(len);
            out.extend_from_slice(&z[pos + 5..pos + 5 + len]);
            pos += 5 + len;
            if header & 1 == 1 {
                break;
            }
        }
        out
    }

    #[test]
    fn png() {
        // Big enough for the pixel data to need more than one stored block.
        let (width, height) = (200, 120);
        let mut img = Image::new(width, height);
        for y in 0..height {
            for x in 0..width {
                let c = Color::new(
                    x as f64 / width as f64,
                    y as f64 / height as f64,
                    ((x + y) % 7) as f64 / 7.0,
                );
                img.set(x, y, c);
            }
        }
        let png = img.to_png();
        assert_eq!(&png[..8], b"\x89PNG\r\n\x1a\n");
        // IEND's CRC is the same in every PNG, which checks the CRC code.
        assert_eq!(&png[png.len() - 12..], b"\0\0\0\0IEND\xae\x42\x60\x82");
        let chunks = png_chunks(&png);
        let kinds: Vec<&[u8]> = chunks.iter().map(|&(kind, _)| kind).collect();
        assert_eq!(kinds, [b"IHDR", b"IDAT", b"IEND"]);
        let header = chunks[0].1;
        assert_eq!(header[..4], (width as u32).to_be_bytes());
        assert_eq!(header[4..8], (height as u32).to_be_bytes());
        assert_eq!(header[8..], [8, 2, 0, 0, 0], "8-bit RGB");
        let raw = inflate_stored(chunks[1].1);
        let row_bytes = 1 + width * 3;
        assert_eq!(raw.len(), row_bytes * height);
        for (y, row) in raw.chunks_exact(row_bytes).enumerate() {
            assert_eq!(row[0], 0, "no filter");
            for (x, &[r, g, b]) in row[1..].as_chunks::<3>().0.iter().enumerate() {
                assert_eq!((r, g, b), img.get(x, y), "pixel ({x}, {y})");
            }
        }
    }
}
