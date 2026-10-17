import Foundation
import Raytracer
import simd

let width = 800
let height = 450
let samples = 100

/// The product of two random numbers, drawn in a fixed order.
func randomChannel(_ rng: inout Rng) -> Double {
    let a = rng.next()
    return a * rng.next()
}

/// The ground, a 22x22 grid of small spheres (less any too close to the metal
/// one at (4, 1, 0)) and three large ones.
func randomWorld(_ rng: inout Rng) -> [Sphere] {
    var world = [
        Sphere(
            center: Vec3(0, -1000, -1), radius: 1000,
            material: .lambertian(albedo: Color(0.5, 0.5, 0.5)))
    ]
    for a in -11..<11 {
        for b in -11..<11 {
            let x = Double(a) + 0.9 * rng.next()
            let z = Double(b) + 0.9 * rng.next()
            let center = Vec3(x, 0.2, z)
            if length(center - Vec3(4, 0.2, 0)) <= 0.9 {
                continue
            }
            let r = randomChannel(&rng)
            let g = randomChannel(&rng)
            let bl = randomChannel(&rng)
            world.append(
                Sphere(center: center, radius: 0.2, material: .lambertian(albedo: Color(r, g, bl))))
        }
    }
    world.append(
        Sphere(center: Vec3(4, 1, 0), radius: 1, material: .metal(Color(0.8, 0.6, 0.2), fuzz: 0.1)))
    world.append(Sphere(center: Vec3(0, 1, 0), radius: 1, material: .dielectric(refIndex: 1.5)))
    world.append(
        Sphere(center: Vec3(-4, 1, 0), radius: 1, material: .metal(Color(0.8, 0.8, 0.8), fuzz: 0.2))
    )
    return world
}

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "out.ppm"

printError("Generating world")
var rng = Rng(seed: 1)
let world = randomWorld(&rng)
let lookFrom = Vec3(3, 2, 3)
let lookAt = Vec3(0, 0, -1)
let camera = Camera(
    CameraSettings(
        lookFrom: lookFrom, lookAt: lookAt, vUp: Vec3(0, 1, 0), vfov: 90,
        aspect: Double(width) / Double(height), aperture: 0.01,
        focusDist: length(lookFrom - lookAt)))

do {
    let renderer = try Renderer()
    printError("Rendering on \(renderer.device.name)")
    let img = try renderer.render(
        width: width, height: height, samples: samples, camera: camera, world: world)
    do {
        try img.save(to: output)
    } catch {
        printError("Writing \(output): \(error.localizedDescription)")
        exit(EXIT_FAILURE)
    }
    printError("Wrote \(output)")
} catch {
    printError("Rendering: \(error)")
    exit(EXIT_FAILURE)
}
