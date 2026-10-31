namespace Raytracer

type Material =
    | Lambertian of albedo: Color
    | Metal of albedo: Color * fuzz: float
    | Dielectric of refIndex: float

/// Where a ray meets a surface.
[<Struct>]
type Hit =
    {
        T: float
        Point: Vec3
        Normal: Vec3
        Material: Material
    }

module Material =
    /// A metal whose fuzz is clamped to [0, 1]: 0 is a perfect mirror.
    let metal albedo fuzz =
        Metal(albedo, fuzz |> min 1.0 |> max 0.0)

    let private reflect v n = v - (2.0 * Vec3.dot v n) * n

    /// The refracted direction, or ValueNone on total internal reflection.
    let refract v n niOverNt =
        let uv = Vec3.unit v
        let dt = Vec3.dot uv n
        let discriminant = 1.0 - niOverNt * niOverNt * (1.0 - dt * dt)

        if discriminant > 0.0 then
            ValueSome(niOverNt * (uv - dt * n) - sqrt discriminant * n)
        else
            ValueNone

    /// Schlick's approximation for reflectance at a given angle.
    let private schlick cosine refIndex =
        let r0 = (1.0 - refIndex) / (1.0 + refIndex)
        let r0 = r0 * r0
        // Multiplied out rather than using ( ** ), whose result can vary by
        // platform, to match the other versions' golden image.
        let x = 1.0 - cosine
        let x2 = x * x
        r0 + (1.0 - r0) * x2 * x2 * x

    /// The attenuation and scattered ray, or ValueNone if the ray is absorbed.
    let scatter (rng: Rng) (rayIn: Ray) (hit: Hit) =
        match hit.Material with
        | Lambertian albedo ->
            let target = hit.Point + hit.Normal + Vec3.randomInUnitSphere rng

            ValueSome(
                albedo,
                {
                    Origin = hit.Point
                    Direction = target - hit.Point
                }
            )
        | Metal(albedo, fuzz) ->
            let reflected = reflect (Vec3.unit rayIn.Direction) hit.Normal
            let direction = reflected + fuzz * Vec3.randomInUnitSphere rng

            if Vec3.dot direction hit.Normal > 0.0 then
                ValueSome(
                    albedo,
                    {
                        Origin = hit.Point
                        Direction = direction
                    }
                )
            else
                ValueNone
        | Dielectric refIndex ->
            let d = rayIn.Direction
            let dDotN = Vec3.dot d hit.Normal

            let outwardNormal, niOverNt, cosine =
                if dDotN > 0.0 then
                    -hit.Normal, refIndex, refIndex * dDotN / Vec3.length d
                else
                    hit.Normal, 1.0 / refIndex, -dDotN / Vec3.length d

            // Only draws a random number when the ray can refract.
            let direction =
                match refract d outwardNormal niOverNt with
                | ValueSome refracted when rng.NextFloat() >= schlick cosine refIndex -> refracted
                | _ -> reflect d hit.Normal

            ValueSome(
                Color.white,
                {
                    Origin = hit.Point
                    Direction = direction
                }
            )
