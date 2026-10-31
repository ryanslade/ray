namespace Raytracer;

public readonly record struct Vec3(double X, double Y, double Z)
{
    public static readonly Vec3 Zero = new(0.0, 0.0, 0.0);

    public static Vec3 operator +(Vec3 a, Vec3 b) => new(a.X + b.X, a.Y + b.Y, a.Z + b.Z);

    public static Vec3 operator -(Vec3 a, Vec3 b) => new(a.X - b.X, a.Y - b.Y, a.Z - b.Z);

    public static Vec3 operator -(Vec3 v) => new(-v.X, -v.Y, -v.Z);

    public static Vec3 operator *(double s, Vec3 v) => new(s * v.X, s * v.Y, s * v.Z);

    public static Vec3 operator /(Vec3 v, double s) => new(v.X / s, v.Y / s, v.Z / s);

    public double Dot(Vec3 o) => X * o.X + Y * o.Y + Z * o.Z;

    public Vec3 Cross(Vec3 o) => new(Y * o.Z - Z * o.Y, Z * o.X - X * o.Z, X * o.Y - Y * o.X);

    public double LengthSquared() => Dot(this);

    public double Length() => Math.Sqrt(LengthSquared());

    public Vec3 Unit() => this / Length();

    /// <summary>
    /// Rejection sampling: picks points in the enclosing cube until one lands
    /// inside.
    /// </summary>
    public static Vec3 RandomInUnitSphere(Rng rng)
    {
        while (true)
        {
            // Arguments are evaluated left to right, so x is drawn first.
            var p = new Vec3(2.0 * rng.NextDouble() - 1.0, 2.0 * rng.NextDouble() - 1.0, 2.0 * rng.NextDouble() - 1.0);
            if (p.LengthSquared() < 1.0)
            {
                return p;
            }
        }
    }

    public static Vec3 RandomInUnitDisk(Rng rng)
    {
        while (true)
        {
            var p = new Vec3(2.0 * rng.NextDouble() - 1.0, 2.0 * rng.NextDouble() - 1.0, 0.0);
            if (p.LengthSquared() < 1.0)
            {
                return p;
            }
        }
    }
}
