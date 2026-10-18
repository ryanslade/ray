package raytracer

import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import scala.annotation.tailrec
import scala.util.Using

private val MaxDepth = 50
private val SkyBlue = Color(0.5, 0.7, 1.0)

/** The colour seen along a ray, following up to 50 bounces. */
def rayColor(world: World, ray: Ray, rng: Rng): Color = bounce(world, ray, rng, Color.White, 0)

// `attenuation` is the product of the attenuations of every surface hit so
// far. Being tail recursive, this compiles to a loop.
@tailrec
private def bounce(world: World, ray: Ray, rng: Rng, attenuation: Color, depth: Int): Color =
  world.hit(ray, 0.001, Double.MaxValue) match
    case None                         => attenuation * sky(ray)
    case Some(_) if depth == MaxDepth => Color.Black
    case Some(hit)                    =>
      val material = hit.material
      material.scatter(ray, hit, rng) match
        case Some(scattered) =>
          bounce(world, scattered, rng, attenuation * material.attenuation, depth + 1)
        case None => Color.Black

private def sky(ray: Ray): Color =
  val t = 0.5 * (ray.direction.unit.y + 1.0)
  (1.0 - t) * Color.White + t * SkyBlue

/** Renders the world with `samples` rays per pixel, in parallel across all available cores. */
def render(width: Int, height: Int, samples: Int, camera: Camera, world: World): Image =
  renderWithThreads(Runtime.getRuntime.availableProcessors, width, height, samples, camera, world)

/** Like [[render]], but on `threads` threads.
  *
  * Each row uses its own random state seeded from the row index, so the image is identical
  * regardless of the number of threads.
  */
def renderWithThreads(
    threads: Int,
    width: Int,
    height: Int,
    samples: Int,
    camera: Camera,
    world: World
): Image =
  require(threads > 0, "threads must be positive")
  val img = Image(width, height)
  // Rows vary a lot in cost (sky is cheap, spheres are expensive), so threads
  // take rows one at a time rather than a fixed block each.
  val nextRow = AtomicInteger()
  val worker: Runnable = () =>
    var y = nextRow.getAndIncrement()
    while y < height do
      renderRow(img.pixels, y, width, height, samples, camera, world)
      y = nextRow.getAndIncrement()
  Using.resource(Executors.newThreadPerTaskExecutor(Thread.ofPlatform().factory())) { executor =>
    val others = Seq.fill(threads - 1)(executor.submit(worker))
    worker.run()
    // Waits for the other threads, rethrowing anything they threw.
    others.foreach(_.get())
  }
  img

private def renderRow(
    pixels: Array[Byte],
    y: Int,
    width: Int,
    height: Int,
    samples: Int,
    camera: Camera,
    world: World
): Unit =
  val rng = Rng(y + 1L)
  for x <- 0 until width do
    var c = Color.Black
    for _ <- 0 until samples do
      val u = (x + rng.nextDouble()) / width
      val v = ((height - 1 - y) + rng.nextDouble()) / height
      c = c + rayColor(world, camera.getRay(u, v, rng), rng)
    Image.setPixel(pixels, 3 * (y * width + x), c / samples.toDouble)
