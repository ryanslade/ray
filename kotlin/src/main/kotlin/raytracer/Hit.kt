package raytracer

data class Hit(
    val t: Double,
    val point: Vec3,
    val normal: Vec3,
    val material: Material,
)
