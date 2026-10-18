package raytracer

data class Color(
    val r: Double,
    val g: Double,
    val b: Double,
) {
    operator fun plus(o: Color) = Color(r + o.r, g + o.g, b + o.b)

    /** Component-wise multiplication. */
    operator fun times(o: Color) = Color(r * o.r, g * o.g, b * o.b)

    operator fun div(s: Double) = Color(r / s, g / s, b / s)

    companion object {
        val BLACK = Color(0.0, 0.0, 0.0)
        val WHITE = Color(1.0, 1.0, 1.0)
    }
}

operator fun Double.times(c: Color) = Color(this * c.r, this * c.g, this * c.b)
