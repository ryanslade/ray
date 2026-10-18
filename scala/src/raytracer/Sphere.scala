package raytracer

final case class Sphere(center: Vec3, radius: Double, material: Material):
  /** The nearest t in (`tMin`, `tMax`) at which the ray meets the sphere, or NaN if there is none.
    * NaN rather than an Option keeps the result unboxed.
    */
  def intersect(ray: Ray, tMin: Double, tMax: Double): Double =
    val oc = ray.origin - center
    val a = ray.direction.dot(ray.direction)
    val b = oc.dot(ray.direction)
    val c = oc.dot(oc) - radius * radius
    val discriminant = b * b - a * c
    if discriminant < 0.0 then Double.NaN
    else
      val sqrtD = math.sqrt(discriminant)
      val near = (-b - sqrtD) / a
      if near < tMax && near > tMin then near
      else
        val far = (-b + sqrtD) / a
        if far < tMax && far > tMin then far else Double.NaN

  def hit(ray: Ray, tMin: Double, tMax: Double): Option[Hit] =
    val t = intersect(ray, tMin, tMax)
    if java.lang.Double.isNaN(t) then None else Some(hitAt(ray, t))

  /** The hit record for a t returned by [[intersect]]. */
  def hitAt(ray: Ray, t: Double): Hit =
    val point = ray.at(t)
    Hit(t, point, (point - center) / radius, material)
