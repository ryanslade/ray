/// Renders the example scene: Raytracer.Cli [output.png]
module Raytracer.Cli.Program

open System
open System.IO
open Raytracer

let width = 800
let height = 450
let samples = 100

let randomWorld (rng: Rng) =
    let smallSphere (a: int) (b: int) =
        let x = float a + 0.9 * rng.NextFloat()
        let z = float b + 0.9 * rng.NextFloat()
        let center = Vec3.make x 0.2 z

        if Vec3.length (center - Vec3.make 4.0 0.2 0.0) <= 0.9 then
            None
        else
            let channel () = rng.NextFloat() * rng.NextFloat()
            let r = channel ()
            let g = channel ()
            let b = channel ()
            Some(Sphere.create center 0.2 (Lambertian(Color.make r g b)))

    World.ofSeq
        [
            Sphere.create (Vec3.make 0.0 -1000.0 -1.0) 1000.0 (Lambertian(Color.make 0.5 0.5 0.5))
            for a in -11 .. 10 do
                for b in -11 .. 10 do
                    yield! Option.toList (smallSphere a b)
            Sphere.create (Vec3.make 4.0 1.0 0.0) 1.0 (Material.metal (Color.make 0.8 0.6 0.2) 0.1)
            Sphere.create (Vec3.make 0.0 1.0 0.0) 1.0 (Dielectric 1.5)
            Sphere.create (Vec3.make -4.0 1.0 0.0) 1.0 (Material.metal (Color.make 0.8 0.8 0.8) 0.2)
        ]

[<EntryPoint>]
let main args =
    let output = args |> Array.tryHead |> Option.defaultValue "out.png"
    eprintfn "Generating world"
    let world = randomWorld (Rng 1UL)
    let lookFrom = Vec3.make 3.0 2.0 3.0
    let lookAt = Vec3.make 0.0 0.0 -1.0

    let camera =
        Camera.create
            {
                LookFrom = lookFrom
                LookAt = lookAt
                VUp = Vec3.make 0.0 1.0 0.0
                Vfov = 90.0
                Aspect = float width / float height
                Aperture = 0.01
                FocusDist = Vec3.length (lookFrom - lookAt)
            }

    eprintfn "Rendering on %d threads" Environment.ProcessorCount
    let img = Render.render width height samples camera world

    try
        Image.savePng output img
        eprintfn "Wrote %s" output
        0
    with :? IOException as e ->
        eprintfn "Writing %s: %s" output e.Message
        1
