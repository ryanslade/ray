namespace Raytracer

type CameraSettings =
    {
        LookFrom: Vec3
        LookAt: Vec3
        VUp: Vec3
        /// The vertical field of view, in degrees.
        Vfov: float
        Aspect: float
        Aperture: float
        FocusDist: float
    }

type Camera =
    private
        {
            Origin: Vec3
            LowerLeft: Vec3
            Horizontal: Vec3
            Vertical: Vec3
            U: Vec3
            V: Vec3
            LensRadius: float
        }

module Camera =
    let create (s: CameraSettings) =
        // The same constant as Rust's to_radians.
        let theta = s.Vfov * (System.Math.PI / 180.0)
        let halfHeight = tan (theta / 2.0)
        let halfWidth = s.Aspect * halfHeight
        let w = Vec3.unit (s.LookFrom - s.LookAt)
        let u = Vec3.unit (Vec3.cross s.VUp w)
        let v = Vec3.cross w u

        {
            Origin = s.LookFrom
            LowerLeft =
                s.LookFrom
                - (halfWidth * s.FocusDist) * u
                - (halfHeight * s.FocusDist) * v
                - s.FocusDist * w
            Horizontal = (2.0 * halfWidth * s.FocusDist) * u
            Vertical = (2.0 * halfHeight * s.FocusDist) * v
            U = u
            V = v
            LensRadius = s.Aperture / 2.0
        }

    /// A ray through the viewport at normalised coordinates (s, t), with its
    /// origin jittered across the lens.
    let getRay (c: Camera) s t rng =
        let rd = c.LensRadius * Vec3.randomInUnitDisk rng
        let offset = rd.X * c.U + rd.Y * c.V

        ({
            Origin = c.Origin + offset
            Direction = c.LowerLeft + s * c.Horizontal + t * c.Vertical - c.Origin - offset
        }
        : Ray)
