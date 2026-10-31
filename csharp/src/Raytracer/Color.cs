namespace Raytracer;

public readonly record struct Color(double R, double G, double B)
{
    public static readonly Color Black = new(0.0, 0.0, 0.0);
    public static readonly Color White = new(1.0, 1.0, 1.0);

    public static Color operator +(Color a, Color b) => new(a.R + b.R, a.G + b.G, a.B + b.B);

    /// <summary>Component-wise multiplication.</summary>
    public static Color operator *(Color a, Color b) => new(a.R * b.R, a.G * b.G, a.B * b.B);

    public static Color operator *(double s, Color c) => new(s * c.R, s * c.G, s * c.B);

    public static Color operator /(Color c, double s) => new(c.R / s, c.G / s, c.B / s);
}
