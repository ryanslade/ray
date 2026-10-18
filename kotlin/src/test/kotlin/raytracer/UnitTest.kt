package raytracer

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

class UnitTest {
    private fun assertClose(
        expected: Vec3,
        actual: Vec3?,
    ) {
        assertNotNull(actual)
        assertTrue((expected - actual).length() < 1e-9, "$actual != $expected")
    }

    @Test
    fun vec3Arithmetic() {
        val a = Vec3(1.0, 2.0, 3.0)
        val b = Vec3(4.0, 5.0, 6.0)
        assertClose(Vec3(5.0, 7.0, 9.0), a + b)
        assertClose(Vec3(2.0, 4.0, 6.0), 2.0 * a)
        assertEquals(32.0, a.dot(b))
        assertClose(Vec3(-3.0, 6.0, -3.0), a.cross(b))
        assertTrue(abs(b.unit().length() - 1.0) < 1e-9)
    }

    @Test
    fun floatsInUnitInterval() {
        val rng = Rng(1)
        repeat(10_000) {
            val f = rng.nextDouble()
            assertTrue(f >= 0.0 && f < 1.0, "$f")
        }
    }

    @Test
    fun sameSeedSameSequence() {
        val a = Rng(42)
        val b = Rng(42)
        repeat(100) { assertEquals(a.nextU64(), b.nextU64()) }
    }

    @Test
    fun sphereHit() {
        val m = Material.dielectric(1.5)
        val s = Sphere(Vec3(0.0, 0.0, -1.0), 0.5, m)
        val towards = Ray(Vec3.ZERO, Vec3(0.0, 0.0, -1.0))

        val h = assertNotNull(s.hit(towards, 0.0, Double.POSITIVE_INFINITY))
        assertEquals(0.5, h.t)
        assertEquals(Vec3(0.0, 0.0, 1.0), h.normal)
        assertSame(m, h.material)

        assertEquals(1.5, s.hit(towards, 0.6, Double.POSITIVE_INFINITY)?.t, "far side")

        val away = Ray(Vec3.ZERO, Vec3(0.0, 1.0, 0.0))
        assertNull(s.hit(away, 0.0, Double.POSITIVE_INFINITY))
    }

    @Test
    fun closestHit() {
        val m = Material.dielectric(1.5)
        val world =
            World(
                listOf(
                    Sphere(Vec3(0.0, 0.0, -5.0), 1.0, m),
                    Sphere(Vec3(0.0, 0.0, -2.0), 0.5, m),
                ),
            )
        val ray = Ray(Vec3.ZERO, Vec3(0.0, 0.0, -1.0))
        assertEquals(1.5, world.hit(ray, 0.0, Double.POSITIVE_INFINITY)?.t)
        assertNull(world.hit(Ray(Vec3.ZERO, Vec3(0.0, 1.0, 0.0)), 0.0, Double.POSITIVE_INFINITY))
    }

    @Test
    fun totalInternalReflection() {
        val n = Vec3(0.0, 1.0, 0.0)
        val grazing = Vec3(1.0, -0.1, 0.0)
        assertNull(refract(grazing, n, 1.5))
    }

    @Test
    fun refractsHeadOn() {
        val n = Vec3(0.0, 1.0, 0.0)
        val down = Vec3(0.0, -1.0, 0.0)
        assertClose(down, refract(down, n, 1.0 / 1.5))
    }

    @Test
    fun metalFuzzIsClamped() {
        assertEquals(Material.Metal(Color.WHITE, 1.0), Material.metal(Color.WHITE, 2.0))
        assertEquals(Material.Metal(Color.WHITE, 0.0), Material.metal(Color.WHITE, -1.0))
    }

    @Test
    fun setClamps() {
        val img = Image(3, 1)
        img.set(1, 0, Color(2.0, 0.5, -1.0))
        // f64::min in Rust ignores NaN, so NaN becomes 255.
        img.set(2, 0, Color(Double.NaN, 0.0, 0.0))
        assertEquals(Triple(0, 0, 0), img.get(0, 0))
        assertEquals(Triple(255, 127, 0), img.get(1, 0))
        assertEquals(Triple(255, 0, 0), img.get(2, 0))
        assertFailsWith<IndexOutOfBoundsException> { img.get(3, 0) }
    }

    @Test
    fun ppmHeader() {
        val ppm = Image(3, 2).toPpm()
        assertEquals("P6\n3 2\n255\n", String(ppm, 0, 11, Charsets.US_ASCII))
        assertEquals(11 + 3 * 2 * 3, ppm.size)
    }
}
