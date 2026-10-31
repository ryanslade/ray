module Raytracer.Render

open System
open System.Threading.Tasks

let private maxDepth = 50
let private skyBlue = Color.make 0.5 0.7 1.0

let private sky (ray: Ray) =
    let t = 0.5 * ((Vec3.unit ray.Direction).Y + 1.0)
    (1.0 - t) * Color.white + t * skyBlue

/// The colour seen along a ray, following up to 50 bounces.
let rayColor world ray rng =
    // The attenuation is the product of the attenuations of every surface hit
    // so far.
    let rec bounce depth attenuation ray =
        match World.hit world ray 0.001 Double.MaxValue with
        | ValueNone -> attenuation * sky ray
        | ValueSome _ when depth = maxDepth -> Color.black
        | ValueSome hit ->
            match Material.scatter rng ray hit with
            | ValueSome(a, scattered) -> bounce (depth + 1) (attenuation * a) scattered
            | ValueNone -> Color.black

    bounce 0 Color.white ray

let private renderRow (row: Span<byte>) y width height samples camera world =
    let rng = Rng(uint64 y + 1UL)

    for x in 0 .. width - 1 do
        let mutable c = Color.black

        for _ in 1..samples do
            let u = (float x + rng.NextFloat()) / float width
            let v = (float (height - 1 - y) + rng.NextFloat()) / float height
            c <- c + rayColor world (Camera.getRay camera u v rng) rng

        Image.writePixel (row.Slice(3 * x, 3)) (c / float samples)

/// Renders the world with the given number of rays per pixel, in parallel on
/// up to the given number of threads.
///
/// Each row uses its own random state seeded from the row index, so the image
/// is identical regardless of the number of threads.
let renderOn threads width height samples camera world =
    if threads < 1 then
        invalidArg (nameof threads) "must be positive"

    let img = Image.create width height
    let options = ParallelOptions(MaxDegreeOfParallelism = threads)
    // Rows vary a lot in cost (sky is cheap, spheres are expensive), and
    // Parallel.For balances them across the threads as it goes.
    Parallel.For(
        0,
        height,
        options,
        fun y -> renderRow (Image.row img y).Span y width height samples camera world
    )
    |> ignore

    img

/// Like renderOn, with one thread per core.
let render width height samples camera world =
    renderOn Environment.ProcessorCount width height samples camera world
