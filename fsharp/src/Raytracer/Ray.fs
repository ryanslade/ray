namespace Raytracer

[<Struct>]
type Ray =
    {
        Origin: Vec3
        Direction: Vec3
    }

    member r.At(t: float) = r.Origin + t * r.Direction
