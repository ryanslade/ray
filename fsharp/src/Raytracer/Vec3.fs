namespace Raytracer

[<Struct>]
type Vec3 =
    {
        X: float
        Y: float
        Z: float
    }

    static member (+)(a, b) =
        {
            X = a.X + b.X
            Y = a.Y + b.Y
            Z = a.Z + b.Z
        }

    static member (-)(a, b) =
        {
            X = a.X - b.X
            Y = a.Y - b.Y
            Z = a.Z - b.Z
        }

    static member (~-) v = { X = -v.X; Y = -v.Y; Z = -v.Z }

    static member (*)(s: float, v) =
        {
            X = s * v.X
            Y = s * v.Y
            Z = s * v.Z
        }

    static member (/)(v, s: float) =
        {
            X = v.X / s
            Y = v.Y / s
            Z = v.Z / s
        }

module Vec3 =
    let inline make x y z = { X = x; Y = y; Z = z }

    let zero = make 0.0 0.0 0.0

    let inline dot a b = a.X * b.X + a.Y * b.Y + a.Z * b.Z

    let cross a b =
        make (a.Y * b.Z - a.Z * b.Y) (a.Z * b.X - a.X * b.Z) (a.X * b.Y - a.Y * b.X)

    let inline lengthSquared v = dot v v

    let inline length v = sqrt (lengthSquared v)

    let inline unit v = v / length v

    let private coord (rng: Rng) = 2.0 * rng.NextFloat() - 1.0

    /// Rejection sampling: picks points in the enclosing cube until one lands
    /// inside.
    let rec randomInUnitSphere rng =
        let x = coord rng
        let y = coord rng
        let z = coord rng
        let p = make x y z
        if lengthSquared p < 1.0 then p else randomInUnitSphere rng

    let rec randomInUnitDisk rng =
        let x = coord rng
        let y = coord rng
        let p = make x y 0.0
        if lengthSquared p < 1.0 then p else randomInUnitDisk rng

[<Struct>]
type Color =
    {
        R: float
        G: float
        B: float
    }

    static member (+)(a, b) =
        {
            R = a.R + b.R
            G = a.G + b.G
            B = a.B + b.B
        }

    /// Component-wise multiplication.
    static member (*)(a, b) =
        {
            R = a.R * b.R
            G = a.G * b.G
            B = a.B * b.B
        }

    static member (*)(s: float, c) =
        {
            R = s * c.R
            G = s * c.G
            B = s * c.B
        }

    static member (/)(c, s: float) =
        {
            R = c.R / s
            G = c.G / s
            B = c.B / s
        }

module Color =
    let inline make r g b = { R = r; G = g; B = b }

    let black = make 0.0 0.0 0.0

    let white = make 1.0 1.0 1.0
