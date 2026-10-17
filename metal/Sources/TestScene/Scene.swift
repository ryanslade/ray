// The scene used by the tests and benchmark, matching the other versions.

import Raytracer
import simd

public func testWorld() -> [Sphere] {
    [
        Sphere(
            center: Vec3(0, -100.5, -1), radius: 100,
            material: .lambertian(albedo: Color(0.5, 0.5, 0.5))),
        Sphere(
            center: Vec3(0, 0, -1), radius: 1, material: .metal(Color(0.8, 0.8, 0.8), fuzz: 0.2)),
        Sphere(center: Vec3(1.5, 0, -1), radius: 1, material: .dielectric(refIndex: 1.5)),
    ]
}

public func testCamera(width: Int, height: Int) -> Camera {
    let lookFrom = Vec3(1, 1, 1)
    let lookAt = Vec3(0, 0, -1)
    return Camera(
        CameraSettings(
            lookFrom: lookFrom, lookAt: lookAt, vUp: Vec3(0, 1, 0), vfov: 90,
            aspect: Double(width) / Double(height), aperture: 0.01,
            focusDist: length(lookFrom - lookAt)))
}
