package raytracer

/** Settings for [Camera]. */
data class CameraSettings(
    val lookFrom: Vec3,
    val lookAt: Vec3,
    val vUp: Vec3,
    /** Vertical field of view in degrees. */
    val vfov: Double,
    val aspect: Double,
    val aperture: Double,
    val focusDist: Double,
)

class Camera(
    s: CameraSettings,
) {
    private val origin: Vec3
    private val lowerLeft: Vec3
    private val horizontal: Vec3
    private val vertical: Vec3
    private val u: Vec3
    private val v: Vec3
    private val lensRadius: Double

    init {
        val theta = Math.toRadians(s.vfov)
        // StrictMath gives the same result on every JVM.
        val halfHeight = StrictMath.tan(theta / 2.0)
        val halfWidth = s.aspect * halfHeight
        val w = (s.lookFrom - s.lookAt).unit()
        u = s.vUp.cross(w).unit()
        v = w.cross(u)
        origin = s.lookFrom
        lowerLeft = s.lookFrom - (halfWidth * s.focusDist) * u - (halfHeight * s.focusDist) * v - s.focusDist * w
        horizontal = (2.0 * halfWidth * s.focusDist) * u
        vertical = (2.0 * halfHeight * s.focusDist) * v
        lensRadius = s.aperture / 2.0
    }

    /**
     * A ray through the viewport at normalised coordinates ([s], [t]), with its
     * origin jittered across the lens.
     */
    fun getRay(
        s: Double,
        t: Double,
        rng: Rng,
    ): Ray {
        val rd = lensRadius * Vec3.randomInUnitDisk(rng)
        val offset = rd.x * u + rd.y * v
        return Ray(origin + offset, lowerLeft + s * horizontal + t * vertical - origin - offset)
    }
}
