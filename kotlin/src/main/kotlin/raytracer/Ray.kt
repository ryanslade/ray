package raytracer

data class Ray(
    val origin: Vec3,
    val direction: Vec3,
) {
    fun at(t: Double) = origin + t * direction
}
