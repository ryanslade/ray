use std::ops::{Add, Div, Mul};

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Color {
    pub r: f64,
    pub g: f64,
    pub b: f64,
}

impl Color {
    pub const BLACK: Color = Color::new(0.0, 0.0, 0.0);
    pub const WHITE: Color = Color::new(1.0, 1.0, 1.0);

    pub const fn new(r: f64, g: f64, b: f64) -> Color {
        Color { r, g, b }
    }
}

impl Add for Color {
    type Output = Color;
    #[inline]
    fn add(self, o: Color) -> Color {
        Color::new(self.r + o.r, self.g + o.g, self.b + o.b)
    }
}

/// Component-wise multiplication.
impl Mul for Color {
    type Output = Color;
    #[inline]
    fn mul(self, o: Color) -> Color {
        Color::new(self.r * o.r, self.g * o.g, self.b * o.b)
    }
}

impl Mul<Color> for f64 {
    type Output = Color;
    #[inline]
    fn mul(self, c: Color) -> Color {
        Color::new(self * c.r, self * c.g, self * c.b)
    }
}

impl Div<f64> for Color {
    type Output = Color;
    #[inline]
    fn div(self, s: f64) -> Color {
        Color::new(self.r / s, self.g / s, self.b / s)
    }
}
