namespace Raytracer.Tests;

/// <summary>The scene used by the tests and benchmark, matching the other versions.</summary>
public static class Scene
{
    public static World World() => new([
        new Sphere(new Vec3(0.0, -100.5, -1.0), 100.0, new Lambertian(new Color(0.5, 0.5, 0.5))),
        new Sphere(new Vec3(0.0, 0.0, -1.0), 1.0, new Metal(new Color(0.8, 0.8, 0.8), 0.2)),
        new Sphere(new Vec3(1.5, 0.0, -1.0), 1.0, new Dielectric(1.5)),
    ]);

    public static Camera Camera(int width, int height)
    {
        var lookFrom = new Vec3(1.0, 1.0, 1.0);
        var lookAt = new Vec3(0.0, 0.0, -1.0);
        return new Camera(
            lookFrom,
            lookAt,
            vUp: new Vec3(0.0, 1.0, 0.0),
            vfov: 90.0,
            aspect: (double)width / height,
            aperture: 0.01,
            focusDist: (lookFrom - lookAt).Length());
    }
}
