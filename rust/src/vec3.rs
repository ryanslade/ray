use std::ops::{Add, Div, Mul, Neg, Sub};

use crate::rng::Rng;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Vec3 {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

impl Vec3 {
    pub const ZERO: Vec3 = Vec3::new(0.0, 0.0, 0.0);

    pub const fn new(x: f64, y: f64, z: f64) -> Vec3 {
        Vec3 { x, y, z }
    }

    #[inline]
    pub fn dot(self, o: Vec3) -> f64 {
        self.x * o.x + self.y * o.y + self.z * o.z
    }

    #[inline]
    pub fn cross(self, o: Vec3) -> Vec3 {
        Vec3::new(
            self.y * o.z - self.z * o.y,
            self.z * o.x - self.x * o.z,
            self.x * o.y - self.y * o.x,
        )
    }

    #[inline]
    pub fn length_squared(self) -> f64 {
        self.dot(self)
    }

    #[inline]
    pub fn length(self) -> f64 {
        self.length_squared().sqrt()
    }

    #[inline]
    pub fn unit(self) -> Vec3 {
        self / self.length()
    }

    /// Rejection sampling: pick points in the enclosing cube until one lands
    /// inside.
    pub fn random_in_unit_sphere(rng: &mut Rng) -> Vec3 {
        loop {
            let x = 2.0 * rng.next_f64() - 1.0;
            let y = 2.0 * rng.next_f64() - 1.0;
            let z = 2.0 * rng.next_f64() - 1.0;
            let p = Vec3::new(x, y, z);
            if p.length_squared() < 1.0 {
                return p;
            }
        }
    }

    pub fn random_in_unit_disk(rng: &mut Rng) -> Vec3 {
        loop {
            let x = 2.0 * rng.next_f64() - 1.0;
            let y = 2.0 * rng.next_f64() - 1.0;
            let p = Vec3::new(x, y, 0.0);
            if p.length_squared() < 1.0 {
                return p;
            }
        }
    }
}

impl Add for Vec3 {
    type Output = Vec3;
    #[inline]
    fn add(self, o: Vec3) -> Vec3 {
        Vec3::new(self.x + o.x, self.y + o.y, self.z + o.z)
    }
}

impl Sub for Vec3 {
    type Output = Vec3;
    #[inline]
    fn sub(self, o: Vec3) -> Vec3 {
        Vec3::new(self.x - o.x, self.y - o.y, self.z - o.z)
    }
}

impl Mul<Vec3> for f64 {
    type Output = Vec3;
    #[inline]
    fn mul(self, v: Vec3) -> Vec3 {
        Vec3::new(self * v.x, self * v.y, self * v.z)
    }
}

impl Div<f64> for Vec3 {
    type Output = Vec3;
    #[inline]
    fn div(self, s: f64) -> Vec3 {
        Vec3::new(self.x / s, self.y / s, self.z / s)
    }
}

impl Neg for Vec3 {
    type Output = Vec3;
    #[inline]
    fn neg(self) -> Vec3 {
        Vec3::new(-self.x, -self.y, -self.z)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn assert_close(a: Vec3, b: Vec3) {
        assert!((a - b).length() < 1e-9, "{a:?} != {b:?}");
    }

    #[test]
    fn arithmetic() {
        let a = Vec3::new(1.0, 2.0, 3.0);
        let b = Vec3::new(4.0, 5.0, 6.0);
        assert_close(a + b, Vec3::new(5.0, 7.0, 9.0));
        assert_close(2.0 * a, Vec3::new(2.0, 4.0, 6.0));
        assert_eq!(a.dot(b), 32.0);
        assert_close(a.cross(b), Vec3::new(-3.0, 6.0, -3.0));
        assert!((b.unit().length() - 1.0).abs() < 1e-9);
    }
}
