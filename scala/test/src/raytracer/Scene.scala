package raytracer

// The scene used by the tests and benchmark, matching the other versions.

def testWorld(): World =
  World(
    Seq(
      Sphere(Vec3(0, -100.5, -1), 100, Material.lambertian(Color(0.5, 0.5, 0.5))),
      Sphere(Vec3(0, 0, -1), 1, Material.metal(Color(0.8, 0.8, 0.8), 0.2)),
      Sphere(Vec3(1.5, 0, -1), 1, Material.dielectric(1.5))
    )
  )

def testCamera(width: Int, height: Int): Camera =
  val lookFrom = Vec3(1, 1, 1)
  val lookAt = Vec3(0, 0, -1)
  Camera(
    CameraSettings(
      lookFrom = lookFrom,
      lookAt = lookAt,
      vUp = Vec3(0, 1, 0),
      vfov = 90,
      aspect = width.toDouble / height,
      aperture = 0.01,
      focusDist = (lookFrom - lookAt).length
    )
  )
