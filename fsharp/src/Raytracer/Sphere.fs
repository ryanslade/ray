namespace Raytracer

type Sphere =
    {
        Center: Vec3
        Radius: float
        Material: Material
    }

module Sphere =
    let create center radius material =
        {
            Center = center
            Radius = radius
            Material = material
        }

    /// The nearest t in (tMin, tMax) at which the ray meets the sphere.
    let intersect (s: Sphere) (ray: Ray) tMin tMax =
        let oc = ray.Origin - s.Center
        let a = Vec3.dot ray.Direction ray.Direction
        let b = Vec3.dot oc ray.Direction
        let c = Vec3.dot oc oc - s.Radius * s.Radius
        let discriminant = b * b - a * c
        let inRange t = t < tMax && t > tMin

        if discriminant < 0.0 then
            ValueNone
        else
            let sqrtD = sqrt discriminant
            let near = (-b - sqrtD) / a
            let far = (-b + sqrtD) / a

            if inRange near then ValueSome near
            elif inRange far then ValueSome far
            else ValueNone

    /// The hit record for a t returned by intersect.
    let hitAt (s: Sphere) (ray: Ray) t =
        let point = ray.At t

        {
            T = t
            Point = point
            Normal = (point - s.Center) / s.Radius
            Material = s.Material
        }

    let hit s ray tMin tMax =
        intersect s ray tMin tMax |> ValueOption.map (hitAt s ray)
