package raytracer

final case class Hit(t: Double, point: Vec3, normal: Vec3, material: Material)
