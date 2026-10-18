package raytracer

final case class Ray(origin: Vec3, direction: Vec3):
  def at(t: Double): Vec3 = origin + t * direction
