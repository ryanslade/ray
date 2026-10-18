package raytracer

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.fail

class RenderTest {
    @Test
    fun deterministicAcrossThreads() {
        val (width, height) = 40 to 30
        val camera = testCamera(width, height)
        val world = testWorld()

        fun render(threads: Int) = renderWithThreads(threads, width, height, 8, camera, world)
        val expected = render(1)
        for (threads in listOf(2, 4, 7)) {
            assertEquals(expected, render(threads), "$threads threads")
        }
    }

    /**
     * Renders the test scene and compares it with `src/test/golden.ppm`.
     *
     * After an intentional change to the output, run with `UPDATE_GOLDEN=1` to
     * accept it. On a mismatch the rendered image is written to
     * `build/golden.actual.ppm` for inspection.
     */
    @Test
    fun goldenImage() {
        val (width, height) = 200 to 200
        val actual = render(width, height, 100, testCamera(width, height), testWorld()).toPpm()

        // Gradle runs tests in the project directory.
        val golden = File("src/test/golden.ppm")
        if (System.getenv("UPDATE_GOLDEN") != null) {
            golden.writeBytes(actual)
            return
        }
        if (!actual.contentEquals(golden.readBytes())) {
            val out = File("build/golden.actual.ppm")
            out.writeBytes(actual)
            fail("rendered image doesn't match $golden; wrote it to $out")
        }
    }
}
