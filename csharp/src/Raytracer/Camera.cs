namespace Raytracer;

public sealed class Camera
{
    private readonly Vec3 _origin;
    private readonly Vec3 _lowerLeft;
    private readonly Vec3 _horizontal;
    private readonly Vec3 _vertical;
    private readonly Vec3 _u;
    private readonly Vec3 _v;
    private readonly double _lensRadius;

    /// <param name="vfov">The vertical field of view, in degrees.</param>
    public Camera(Vec3 lookFrom, Vec3 lookAt, Vec3 vUp, double vfov, double aspect, double aperture, double focusDist)
    {
        // The same constant as Rust's to_radians.
        double theta = vfov * (Math.PI / 180.0);
        double halfHeight = Math.Tan(theta / 2.0);
        double halfWidth = aspect * halfHeight;
        Vec3 w = (lookFrom - lookAt).Unit();
        _u = vUp.Cross(w).Unit();
        _v = w.Cross(_u);
        _origin = lookFrom;
        _lowerLeft = lookFrom - (halfWidth * focusDist) * _u - (halfHeight * focusDist) * _v - focusDist * w;
        _horizontal = (2.0 * halfWidth * focusDist) * _u;
        _vertical = (2.0 * halfHeight * focusDist) * _v;
        _lensRadius = aperture / 2.0;
    }

    /// <summary>
    /// A ray through the viewport at normalised coordinates (s, t), with its
    /// origin jittered across the lens.
    /// </summary>
    public Ray GetRay(double s, double t, Rng rng)
    {
        Vec3 rd = _lensRadius * Vec3.RandomInUnitDisk(rng);
        Vec3 offset = rd.X * _u + rd.Y * _v;
        return new Ray(_origin + offset, _lowerLeft + s * _horizontal + t * _vertical - _origin - offset);
    }
}
