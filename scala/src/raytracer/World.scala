package raytracer

final class World(spheres: Seq[Sphere]):
  // An array rather than a Seq, so that the closest-hit loop indexes it
  // directly without an iterator or casts.
  private val sphereArray = spheres.toArray

  /** Returns the closest hit, shrinking `tMax` as nearer spheres are found. */
  def hit(ray: Ray, tMin: Double, tMax: Double): Option[Hit] =
    // Only the hit record for the closest sphere is ever needed, so just track
    // which one it is until the end.
    var closest = -1
    var closestT = tMax
    var i = 0
    while i < sphereArray.length do
      val t = sphereArray(i).intersect(ray, tMin, closestT)
      // t.isNaN would box t, since it converts the Double to a
      // java.lang.Double to call its isNaN method.
      if !java.lang.Double.isNaN(t) then
        closest = i
        closestT = t
      i += 1
    if closest < 0 then None else Some(sphereArray(closest).hitAt(ray, closestT))
