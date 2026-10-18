package raytracer

import kotlin.math.sqrt

data class Sphere(
    val center: Vec3,
    val radius: Double,
    val material: Material,
) {
    /**
     * The nearest t in ([tMin], [tMax]) at which the ray meets the sphere, or
     * NaN if there is none. NaN rather than null keeps the result unboxed.
     */
    fun intersect(
        ray: Ray,
        tMin: Double,
        tMax: Double,
    ): Double {
        val oc = ray.origin - center
        val a = ray.direction.dot(ray.direction)
        val b = oc.dot(ray.direction)
        val c = oc.dot(oc) - radius * radius
        val discriminant = b * b - a * c
        if (discriminant < 0.0) return Double.NaN
        val sqrtD = sqrt(discriminant)
        val near = (-b - sqrtD) / a
        if (near < tMax && near > tMin) return near
        val far = (-b + sqrtD) / a
        return if (far < tMax && far > tMin) far else Double.NaN
    }

    fun hit(
        ray: Ray,
        tMin: Double,
        tMax: Double,
    ): Hit? {
        val t = intersect(ray, tMin, tMax)
        return if (t.isNaN()) null else hitAt(ray, t)
    }

    /** The hit record for a t returned by [intersect]. */
    fun hitAt(
        ray: Ray,
        t: Double,
    ): Hit {
        val point = ray.at(t)
        return Hit(t, point, (point - center) / radius, material)
    }
}
