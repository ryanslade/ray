/// The scene used by the tests and benchmark, matching the other versions.
module Raytracer.Tests.Scene

open Raytracer

let world =
    World.ofSeq
        [
            Sphere.create (Vec3.make 0.0 -100.5 -1.0) 100.0 (Lambertian(Color.make 0.5 0.5 0.5))
            Sphere.create (Vec3.make 0.0 0.0 -1.0) 1.0 (Material.metal (Color.make 0.8 0.8 0.8) 0.2)
            Sphere.create (Vec3.make 1.5 0.0 -1.0) 1.0 (Dielectric 1.5)
        ]

let camera width height =
    let lookFrom = Vec3.make 1.0 1.0 1.0
    let lookAt = Vec3.make 0.0 0.0 -1.0

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
