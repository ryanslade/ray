namespace Raytracer

type World = private { Spheres: Sphere array }

module World =
    let ofSeq spheres = { Spheres = Array.ofSeq spheres }

    /// The closest hit in (tMin, tMax), shrinking tMax as nearer spheres are
    /// found. Only the hit record for the closest sphere is ever needed, so
    /// this just tracks which one it is until the end.
    let hit world ray tMin tMax =
        let spheres = world.Spheres

        let rec closest i found tMax =
            if i = spheres.Length then
                found |> ValueOption.map (fun s -> Sphere.hitAt s ray tMax)
            else
                match Sphere.intersect spheres[i] ray tMin tMax with
                | ValueSome t -> closest (i + 1) (ValueSome spheres[i]) t
                | ValueNone -> closest (i + 1) found tMax

        closest 0 ValueNone tMax
