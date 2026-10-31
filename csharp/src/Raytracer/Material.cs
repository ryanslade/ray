namespace Raytracer;

public abstract record Material
{
    /// <summary>
    /// Gets the attenuation and scattered ray, or returns false if the ray is
    /// absorbed.
    /// </summary>
    public abstract bool Scatter(in Ray rayIn, in Hit hit, Rng rng, out Color attenuation, out Ray scattered);

    internal static Vec3 Reflect(Vec3 v, Vec3 n) => v - 2.0 * v.Dot(n) * n;

    /// <summary>The refracted direction, or null on total internal reflection.</summary>
    internal static Vec3? Refract(Vec3 v, Vec3 n, double niOverNt)
    {
        Vec3 uv = v.Unit();
        double dt = uv.Dot(n);
        double discriminant = 1.0 - niOverNt * niOverNt * (1.0 - dt * dt);
        return discriminant > 0.0 ? niOverNt * (uv - dt * n) - Math.Sqrt(discriminant) * n : null;
    }
}

public sealed record Lambertian(Color Albedo) : Material
{
    public override bool Scatter(in Ray rayIn, in Hit hit, Rng rng, out Color attenuation, out Ray scattered)
    {
        Vec3 target = hit.Point + hit.Normal + Vec3.RandomInUnitSphere(rng);
        attenuation = Albedo;
        scattered = new Ray(hit.Point, target - hit.Point);
        return true;
    }
}

public sealed record Metal : Material
{
    /// <param name="fuzz">Clamped to [0, 1]: 0 is a perfect mirror.</param>
    public Metal(Color albedo, double fuzz)
    {
        Albedo = albedo;
        Fuzz = Math.Clamp(fuzz, 0.0, 1.0);
    }

    public Color Albedo { get; }

    public double Fuzz { get; }

    public override bool Scatter(in Ray rayIn, in Hit hit, Rng rng, out Color attenuation, out Ray scattered)
    {
        Vec3 reflected = Reflect(rayIn.Direction.Unit(), hit.Normal);
        Vec3 direction = reflected + Fuzz * Vec3.RandomInUnitSphere(rng);
        attenuation = Albedo;
        scattered = new Ray(hit.Point, direction);
        return direction.Dot(hit.Normal) > 0.0;
    }
}

public sealed record Dielectric(double RefIndex) : Material
{
    public override bool Scatter(in Ray rayIn, in Hit hit, Rng rng, out Color attenuation, out Ray scattered)
    {
        Vec3 d = rayIn.Direction;
        double dDotN = d.Dot(hit.Normal);
        (Vec3 outwardNormal, double niOverNt, double cosine) = dDotN > 0.0
            ? (-hit.Normal, RefIndex, RefIndex * dDotN / d.Length())
            : (hit.Normal, 1.0 / RefIndex, -dDotN / d.Length());
        // Only draws a random number when the ray can refract.
        Vec3 direction = Refract(d, outwardNormal, niOverNt) is Vec3 refracted
            && rng.NextDouble() >= Schlick(cosine, RefIndex)
            ? refracted
            : Reflect(d, hit.Normal);
        attenuation = Color.White;
        scattered = new Ray(hit.Point, direction);
        return true;
    }

    /// <summary>Schlick's approximation for reflectance at a given angle.</summary>
    private static double Schlick(double cosine, double refIndex)
    {
        double r0 = (1.0 - refIndex) / (1.0 + refIndex);
        r0 *= r0;
        // Multiplied out rather than using Math.Pow, whose result can vary by
        // platform, to match the other versions' golden image.
        double x = 1.0 - cosine;
        double x2 = x * x;
        return r0 + (1.0 - r0) * x2 * x2 * x;
    }
}
