package raytracer

// Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with 50
// samples per pixel. Usage: ./mill bench [iterations [threads]]

object Bench:
  def main(args: Array[String]): Unit =
    val iterations = args.lift(0).fold(20)(_.toInt)
    val threads = args.lift(1).fold(Runtime.getRuntime.availableProcessors)(_.toInt)

    val (width, height) = (100, 100)
    val camera = testCamera(width, height)
    val world = testWorld()
    def run() = renderWithThreads(threads, width, height, 50, camera, world)

    // The JIT compiles the hot code as it runs, so warm up for a few seconds
    // first.
    val warmUntil = System.nanoTime() + 3_000_000_000L
    while System.nanoTime() < warmUntil do run()
    val start = System.nanoTime()
    for _ <- 1 to iterations do run()
    val ms = (System.nanoTime() - start) / 1e6 / iterations
    println(f"$iterations iterations on $threads threads: $ms%.2f ms/op")
