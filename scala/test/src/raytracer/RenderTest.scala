package raytracer

import java.nio.file.{Files, Path}

class RenderTest extends munit.FunSuite:
  test("deterministic across threads") {
    val (width, height) = (40, 30)
    val camera = testCamera(width, height)
    val world = testWorld()

    def render(threads: Int) = renderWithThreads(threads, width, height, 8, camera, world)
    val expected = render(1)
    for threads <- Seq(2, 4, 7) do assertEquals(render(threads), expected, s"$threads threads")
  }

  /** Renders the test scene and compares it with `test/resources/golden.ppm`.
    *
    * After an intentional change to the output, run with `UPDATE_GOLDEN=1` to accept it. On a
    * mismatch the rendered image is written to `golden.actual.ppm` in the test's sandbox directory
    * for inspection.
    */
  test("golden image") {
    val (width, height) = (200, 200)
    val actual = render(width, height, 100, testCamera(width, height), testWorld()).toPpm

    // Mill runs tests in a sandbox directory, and passes the resource
    // directory in the environment.
    val golden = Path.of(sys.env("MILL_TEST_RESOURCE_DIR"), "golden.ppm")
    if sys.env.contains("UPDATE_GOLDEN") then Files.write(golden, actual)
    else if !java.util.Arrays.equals(actual, Files.readAllBytes(golden)) then
      val out = Path.of("golden.actual.ppm").toAbsolutePath
      Files.write(out, actual)
      fail(s"rendered image doesn't match $golden; wrote it to $out")
  }
