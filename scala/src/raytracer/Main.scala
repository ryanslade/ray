package raytracer

import java.io.IOException

object Main:
  private val Width = 800
  private val Height = 450
  private val Samples = 100

  private def randomWorld(rng: Rng): World =
    val ground = Sphere(Vec3(0, -1000, -1), 1000, Material.lambertian(Color(0.5, 0.5, 0.5)))

    def smallSphere(a: Int, b: Int): Option[Sphere] =
      val x = a + 0.9 * rng.nextDouble()
      val z = b + 0.9 * rng.nextDouble()
      val center = Vec3(x, 0.2, z)
      if (center - Vec3(4, 0.2, 0)).length <= 0.9 then None
      else
        def channel() = rng.nextDouble() * rng.nextDouble()
        val albedo = Color(channel(), channel(), channel())
        Some(Sphere(center, 0.2, Material.lambertian(albedo)))

    val smallSpheres =
      for
        a <- -11 until 11
        b <- -11 until 11
        sphere <- smallSphere(a, b)
      yield sphere

    val largeSpheres = Seq(
      Sphere(Vec3(4, 1, 0), 1, Material.metal(Color(0.8, 0.6, 0.2), 0.1)),
      Sphere(Vec3(0, 1, 0), 1, Material.dielectric(1.5)),
      Sphere(Vec3(-4, 1, 0), 1, Material.metal(Color(0.8, 0.8, 0.8), 0.2))
    )

    World(Seq(ground) ++ smallSpheres ++ largeSpheres)

  def main(args: Array[String]): Unit =
    val output = args.headOption.getOrElse("out.png")
    System.err.println("Generating world")
    val world = randomWorld(Rng(1))
    val lookFrom = Vec3(3, 2, 3)
    val lookAt = Vec3(0, 0, -1)
    val camera = Camera(
      CameraSettings(
        lookFrom = lookFrom,
        lookAt = lookAt,
        vUp = Vec3(0, 1, 0),
        vfov = 90,
        aspect = Width.toDouble / Height,
        aperture = 0.01,
        focusDist = (lookFrom - lookAt).length
      )
    )
    System.err.println(s"Rendering on ${Runtime.getRuntime.availableProcessors} threads")
    val img = render(Width, Height, Samples, camera, world)
    try img.savePng(output)
    catch
      case e: IOException =>
        System.err.println(s"Writing $output: ${e.getMessage}")
        sys.exit(1)
    System.err.println(s"Wrote $output")
