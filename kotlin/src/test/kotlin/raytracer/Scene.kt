package raytracer

// The scene used by the tests and benchmark, matching the other versions.

fun testWorld() =
    World(
        listOf(
            Sphere(Vec3(0.0, -100.5, -1.0), 100.0, Material.lambertian(Color(0.5, 0.5, 0.5))),
            Sphere(Vec3(0.0, 0.0, -1.0), 1.0, Material.metal(Color(0.8, 0.8, 0.8), 0.2)),
            Sphere(Vec3(1.5, 0.0, -1.0), 1.0, Material.dielectric(1.5)),
        ),
    )

fun testCamera(
    width: Int,
    height: Int,
): Camera {
    val lookFrom = Vec3(1.0, 1.0, 1.0)
    val lookAt = Vec3(0.0, 0.0, -1.0)
    return Camera(
        CameraSettings(
            lookFrom = lookFrom,
            lookAt = lookAt,
            vUp = Vec3(0.0, 1.0, 0.0),
            vfov = 90.0,
            aspect = width.toDouble() / height,
            aperture = 0.01,
            focusDist = (lookFrom - lookAt).length(),
        ),
    )
}
