package raytracer

import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

private const val MAX_DEPTH = 50
private val SKY_BLUE = Color(0.5, 0.7, 1.0)

/** The colour seen along a ray, following up to 50 bounces. */
fun rayColor(
    world: World,
    ray: Ray,
    rng: Rng,
): Color {
    var ray = ray
    // The product of the attenuations of every surface hit so far.
    var attenuation = Color.WHITE
    for (depth in 0..MAX_DEPTH) {
        val hit = world.hit(ray, 0.001, Double.MAX_VALUE) ?: return attenuation * sky(ray)
        if (depth == MAX_DEPTH) break
        val material = hit.material
        ray = material.scatter(ray, hit, rng) ?: break
        attenuation = attenuation * material.attenuation
    }
    return Color.BLACK
}

private fun sky(ray: Ray): Color {
    val t = 0.5 * (ray.direction.unit().y + 1.0)
    return (1.0 - t) * Color.WHITE + t * SKY_BLUE
}

/**
 * Renders the world with [samples] rays per pixel, in parallel across all
 * available cores.
 */
fun render(
    width: Int,
    height: Int,
    samples: Int,
    camera: Camera,
    world: World,
): Image = renderWithThreads(Runtime.getRuntime().availableProcessors(), width, height, samples, camera, world)

/**
 * Like [render], but on [threads] threads.
 *
 * Each row uses its own random state seeded from the row index, so the image is
 * identical regardless of the number of threads.
 */
fun renderWithThreads(
    threads: Int,
    width: Int,
    height: Int,
    samples: Int,
    camera: Camera,
    world: World,
): Image {
    require(threads > 0) { "threads must be positive" }
    val img = Image(width, height)
    // Rows vary a lot in cost (sky is cheap, spheres are expensive), so threads
    // take rows one at a time rather than a fixed block each.
    val nextRow = AtomicInteger()
    val worker = {
        while (true) {
            val y = nextRow.getAndIncrement()
            if (y >= height) break
            renderRow(img.pixels, y, width, height, samples, camera, world)
        }
    }
    Executors.newThreadPerTaskExecutor(Thread.ofPlatform().factory()).use { executor ->
        val others = List(threads - 1) { executor.submit(worker) }
        worker()
        // Waits for the other threads, rethrowing anything they threw.
        others.forEach { it.get() }
    }
    return img
}

private fun renderRow(
    pixels: ByteArray,
    y: Int,
    width: Int,
    height: Int,
    samples: Int,
    camera: Camera,
    world: World,
) {
    val rng = Rng(y + 1L)
    for (x in 0..<width) {
        var c = Color.BLACK
        repeat(samples) {
            val u = (x + rng.nextDouble()) / width
            val v = ((height - 1 - y) + rng.nextDouble()) / height
            c += rayColor(world, camera.getRay(u, v, rng), rng)
        }
        setPixel(pixels, 3 * (y * width + x), c / samples.toDouble())
    }
}
