pub const Color = struct {
    r: f64,
    g: f64,
    b: f64,

    pub const black: Color = .init(0, 0, 0);
    pub const white: Color = .init(1, 1, 1);

    pub fn init(r: f64, g: f64, b: f64) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn add(a: Color, o: Color) Color {
        return .init(a.r + o.r, a.g + o.g, a.b + o.b);
    }

    /// Component-wise multiplication.
    pub fn mul(a: Color, o: Color) Color {
        return .init(a.r * o.r, a.g * o.g, a.b * o.b);
    }

    pub fn scale(c: Color, s: f64) Color {
        return .init(s * c.r, s * c.g, s * c.b);
    }

    pub fn div(c: Color, s: f64) Color {
        return .init(c.r / s, c.g / s, c.b / s);
    }
};
