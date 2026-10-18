package raytracer

import kotlin.math.sqrt

sealed interface Material {
    data class Lambertian(
        val albedo: Color,
    ) : Material

    data class Metal(
        val albedo: Color,
        val fuzz: Double,
    ) : Material

    data class Dielectric(
        val refIndex: Double,
    ) : Material

    /** The colour that scattered light is multiplied by. */
    val attenuation: Color
        get() =
            when (this) {
                is Lambertian -> albedo
                is Metal -> albedo
                is Dielectric -> Color.WHITE
            }

    /** The scattered ray, or null if the ray is absorbed. */
    fun scatter(
        rayIn: Ray,
        hit: Hit,
        rng: Rng,
    ): Ray? {
        val point = hit.point
        val normal = hit.normal
        return when (this) {
            is Lambertian -> {
                val target = point + normal + Vec3.randomInUnitSphere(rng)
                Ray(point, target - point)
            }

            is Metal -> {
                val reflected = reflect(rayIn.direction.unit(), normal)
                val direction = reflected + fuzz * Vec3.randomInUnitSphere(rng)
                if (direction.dot(normal) > 0.0) Ray(point, direction) else null
            }

            is Dielectric -> {
                val d = rayIn.direction
                val dDotN = d.dot(normal)
                val outwardNormal: Vec3
                val niOverNt: Double
                val cosine: Double
                if (dDotN > 0.0) {
                    outwardNormal = -normal
                    niOverNt = refIndex
                    cosine = refIndex * dDotN / d.length()
                } else {
                    outwardNormal = normal
                    niOverNt = 1.0 / refIndex
                    cosine = -dDotN / d.length()
                }
                val refracted = refract(d, outwardNormal, niOverNt)
                // Only draws a random number when the ray can refract.
                val direction =
                    if (refracted != null && rng.nextDouble() >= schlick(cosine, refIndex)) {
                        refracted
                    } else {
                        reflect(d, normal)
                    }
                Ray(point, direction)
            }
        }
    }

    companion object {
        fun lambertian(albedo: Color): Material = Lambertian(albedo)

        /** [fuzz] is clamped to [0, 1]: 0 is a perfect mirror. */
        fun metal(
            albedo: Color,
            fuzz: Double,
        ): Material = Metal(albedo, fuzz.coerceIn(0.0, 1.0))

        fun dielectric(refIndex: Double): Material = Dielectric(refIndex)
    }
}

internal fun reflect(
    v: Vec3,
    n: Vec3,
) = v - 2.0 * v.dot(n) * n

/** The refracted direction, or null on total internal reflection. */
internal fun refract(
    v: Vec3,
    n: Vec3,
    niOverNt: Double,
): Vec3? {
    val uv = v.unit()
    val dt = uv.dot(n)
    val discriminant = 1.0 - niOverNt * niOverNt * (1.0 - dt * dt)
    return if (discriminant > 0.0) niOverNt * (uv - dt * n) - sqrt(discriminant) * n else null
}

/** Schlick's approximation for reflectance at a given angle. */
private fun schlick(
    cosine: Double,
    refIndex: Double,
): Double {
    var r0 = (1.0 - refIndex) / (1.0 + refIndex)
    r0 *= r0
    // Multiplied out rather than using pow, to match the other versions'
    // golden image.
    val x = 1.0 - cosine
    val x2 = x * x
    return r0 + (1.0 - r0) * x2 * x2 * x
}
