namespace Raytracer;

public sealed record Sphere(Vec3 Center, double Radius, Material Material)
{
    /// <summary>
    /// Finds the nearest t in (tMin, tMax) at which the ray meets the sphere.
    /// </summary>
    public bool TryIntersect(in Ray ray, double tMin, double tMax, out double t)
    {
        Vec3 oc = ray.Origin - Center;
        double a = ray.Direction.Dot(ray.Direction);
        double b = oc.Dot(ray.Direction);
        double c = oc.Dot(oc) - Radius * Radius;
        double discriminant = b * b - a * c;
        if (discriminant >= 0.0)
        {
            double sqrtD = Math.Sqrt(discriminant);
            t = (-b - sqrtD) / a;
            if (t < tMax && t > tMin)
            {
                return true;
            }
            t = (-b + sqrtD) / a;
            if (t < tMax && t > tMin)
            {
                return true;
            }
        }
        t = 0.0;
        return false;
    }

    /// <summary>The hit record for a t found by <see cref="TryIntersect"/>.</summary>
    public Hit HitAt(in Ray ray, double t)
    {
        Vec3 point = ray.At(t);
        return new Hit(t, point, (point - Center) / Radius, Material);
    }

    public bool TryHit(in Ray ray, double tMin, double tMax, out Hit hit)
    {
        bool found = TryIntersect(ray, tMin, tMax, out double t);
        hit = found ? HitAt(ray, t) : default;
        return found;
    }
}
