package raytracer

class World(
    spheres: List<Sphere>,
) {
    // An array rather than a list, so that the closest-hit loop indexes it
    // directly without an iterator or casts.
    private val spheres = spheres.toTypedArray()

    /** Returns the closest hit, shrinking [tMax] as nearer spheres are found. */
    fun hit(
        ray: Ray,
        tMin: Double,
        tMax: Double,
    ): Hit? {
        // Only the hit record for the closest sphere is ever needed, so just
        // track which one it is until the end.
        var closest = -1
        var closestT = tMax
        for (i in spheres.indices) {
            val t = spheres[i].intersect(ray, tMin, closestT)
            if (!t.isNaN()) {
                closest = i
                closestT = t
            }
        }
        return if (closest < 0) null else spheres[closest].hitAt(ray, closestT)
    }
}
