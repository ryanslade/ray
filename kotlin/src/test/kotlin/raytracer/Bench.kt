package raytracer

// Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with 50
// samples per pixel. Usage: ./gradlew bench [--args="iterations threads"]

fun main(args: Array<String>) {
    val iterations = args.getOrNull(0)?.toInt() ?: 20
    val threads = args.getOrNull(1)?.toInt() ?: Runtime.getRuntime().availableProcessors()

    val (width, height) = 100 to 100
    val camera = testCamera(width, height)
    val world = testWorld()
    val run = { renderWithThreads(threads, width, height, 50, camera, world) }

    // The JIT compiles the hot code as it runs, so warm up for a few seconds
    // first.
    val warmUntil = System.nanoTime() + 3_000_000_000
    while (System.nanoTime() < warmUntil) run()
    val start = System.nanoTime()
    repeat(iterations) { run() }
    val ms = (System.nanoTime() - start) / 1e6 / iterations
    println("$iterations iterations on $threads threads: ${"%.2f".format(ms)} ms/op")
}
