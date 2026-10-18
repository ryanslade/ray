package raytracer

import kotlin.math.sqrt

data class Vec3(
    val x: Double,
    val y: Double,
    val z: Double,
) {
    operator fun plus(o: Vec3) = Vec3(x + o.x, y + o.y, z + o.z)

    operator fun minus(o: Vec3) = Vec3(x - o.x, y - o.y, z - o.z)

    operator fun div(s: Double) = Vec3(x / s, y / s, z / s)

    operator fun unaryMinus() = Vec3(-x, -y, -z)

    fun dot(o: Vec3) = x * o.x + y * o.y + z * o.z

    fun cross(o: Vec3) =
        Vec3(
            y * o.z - z * o.y,
            z * o.x - x * o.z,
            x * o.y - y * o.x,
        )

    fun lengthSquared() = dot(this)

    fun length() = sqrt(lengthSquared())

    fun unit() = this / length()

    companion object {
        val ZERO = Vec3(0.0, 0.0, 0.0)

        /**
         * Rejection sampling: pick points in the enclosing cube until one lands
         * inside.
         */
        fun randomInUnitSphere(rng: Rng): Vec3 {
            while (true) {
                val p = Vec3(2.0 * rng.nextDouble() - 1.0, 2.0 * rng.nextDouble() - 1.0, 2.0 * rng.nextDouble() - 1.0)
                if (p.lengthSquared() < 1.0) return p
            }
        }

        fun randomInUnitDisk(rng: Rng): Vec3 {
            while (true) {
                val p = Vec3(2.0 * rng.nextDouble() - 1.0, 2.0 * rng.nextDouble() - 1.0, 0.0)
                if (p.lengthSquared() < 1.0) return p
            }
        }
    }
}

operator fun Double.times(v: Vec3) = Vec3(this * v.x, this * v.y, this * v.z)
