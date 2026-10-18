package raytracer

import java.io.IOException
import kotlin.system.exitProcess

private const val WIDTH = 800
private const val HEIGHT = 450
private const val SAMPLES = 100

private fun randomWorld(rng: Rng): World {
    val ground = Sphere(Vec3(0.0, -1000.0, -1.0), 1000.0, Material.lambertian(Color(0.5, 0.5, 0.5)))

    fun smallSphere(
        a: Double,
        b: Double,
    ): Sphere? {
        val x = a + 0.9 * rng.nextDouble()
        val z = b + 0.9 * rng.nextDouble()
        val center = Vec3(x, 0.2, z)
        if ((center - Vec3(4.0, 0.2, 0.0)).length() <= 0.9) return null

        fun channel() = rng.nextDouble() * rng.nextDouble()
        val albedo = Color(channel(), channel(), channel())
        return Sphere(center, 0.2, Material.lambertian(albedo))
    }
    val grid = -11..<11
    val smallSpheres = grid.flatMap { a -> grid.mapNotNull { b -> smallSphere(a.toDouble(), b.toDouble()) } }

    val largeSpheres =
        listOf(
            Sphere(Vec3(4.0, 1.0, 0.0), 1.0, Material.metal(Color(0.8, 0.6, 0.2), 0.1)),
            Sphere(Vec3(0.0, 1.0, 0.0), 1.0, Material.dielectric(1.5)),
            Sphere(Vec3(-4.0, 1.0, 0.0), 1.0, Material.metal(Color(0.8, 0.8, 0.8), 0.2)),
        )

    return World(listOf(ground) + smallSpheres + largeSpheres)
}

fun main(args: Array<String>) {
    val output = args.firstOrNull() ?: "out.ppm"
    System.err.println("Generating world")
    val world = randomWorld(Rng(1))
    val lookFrom = Vec3(3.0, 2.0, 3.0)
    val lookAt = Vec3(0.0, 0.0, -1.0)
    val camera =
        Camera(
            CameraSettings(
                lookFrom = lookFrom,
                lookAt = lookAt,
                vUp = Vec3(0.0, 1.0, 0.0),
                vfov = 90.0,
                aspect = WIDTH.toDouble() / HEIGHT,
                aperture = 0.01,
                focusDist = (lookFrom - lookAt).length(),
            ),
        )
    System.err.println("Rendering on ${Runtime.getRuntime().availableProcessors()} threads")
    val img = render(WIDTH, HEIGHT, SAMPLES, camera, world)
    try {
        img.savePpm(output)
    } catch (e: IOException) {
        System.err.println("Writing $output: ${e.message}")
        exitProcess(1)
    }
    System.err.println("Wrote $output")
}
