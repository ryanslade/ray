namespace Raytracer;

public readonly record struct Ray(Vec3 Origin, Vec3 Direction)
{
    public Vec3 At(double t) => Origin + t * Direction;
}

/// <summary>Where a ray meets a surface.</summary>
public readonly record struct Hit(double T, Vec3 Point, Vec3 Normal, Material Material);
