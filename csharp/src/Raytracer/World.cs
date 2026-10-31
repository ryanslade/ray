namespace Raytracer;

public sealed class World(IEnumerable<Sphere> spheres)
{
    private readonly Sphere[] _spheres = [.. spheres];

    public IReadOnlyList<Sphere> Spheres => _spheres;

    /// <summary>
    /// Finds the closest hit in (tMin, tMax), shrinking tMax as nearer
    /// spheres are found. Only the hit record for the closest sphere is ever
    /// needed, so this just tracks which one it is until the end.
    /// </summary>
    public bool TryHit(in Ray ray, double tMin, double tMax, out Hit hit)
    {
        Sphere? closest = null;
        foreach (Sphere sphere in _spheres)
        {
            if (sphere.TryIntersect(ray, tMin, tMax, out double t))
            {
                closest = sphere;
                tMax = t;
            }
        }
        hit = closest?.HitAt(ray, tMax) ?? default;
        return closest is not null;
    }
}
