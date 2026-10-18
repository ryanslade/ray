package raytracer

enum Material:
  case Lambertian(albedo: Color)
  case Metal(albedo: Color, fuzz: Double)
  case Dielectric(refIndex: Double)

  /** The colour that scattered light is multiplied by. */
  def attenuation: Color = this match
    case Lambertian(albedo) => albedo
    case Metal(albedo, _)   => albedo
    case Dielectric(_)      => Color.White

  /** The scattered ray, or None if the ray is absorbed. */
  def scatter(rayIn: Ray, hit: Hit, rng: Rng): Option[Ray] =
    val point = hit.point
    val normal = hit.normal
    this match
      case Lambertian(_) =>
        val target = point + normal + Vec3.randomInUnitSphere(rng)
        Some(Ray(point, target - point))

      case Metal(_, fuzz) =>
        val reflected = reflect(rayIn.direction.unit, normal)
        val direction = reflected + fuzz * Vec3.randomInUnitSphere(rng)
        if direction.dot(normal) > 0.0 then Some(Ray(point, direction)) else None

      case Dielectric(refIndex) =>
        val d = rayIn.direction
        val dDotN = d.dot(normal)
        val (outwardNormal, niOverNt, cosine) =
          if dDotN > 0.0 then (-normal, refIndex, refIndex * dDotN / d.length)
          else (normal, 1.0 / refIndex, -dDotN / d.length)
        // Only draws a random number when the ray can refract.
        val direction = refract(d, outwardNormal, niOverNt)
          .filter(_ => rng.nextDouble() >= schlick(cosine, refIndex))
          .getOrElse(reflect(d, normal))
        Some(Ray(point, direction))

object Material:
  def lambertian(albedo: Color): Material = Lambertian(albedo)

  /** `fuzz` is clamped to [0, 1]: 0 is a perfect mirror. */
  def metal(albedo: Color, fuzz: Double): Material =
    Metal(albedo, math.min(math.max(fuzz, 0.0), 1.0))

  def dielectric(refIndex: Double): Material = Dielectric(refIndex)

private[raytracer] def reflect(v: Vec3, n: Vec3): Vec3 = v - 2.0 * v.dot(n) * n

/** The refracted direction, or None on total internal reflection. */
private[raytracer] def refract(v: Vec3, n: Vec3, niOverNt: Double): Option[Vec3] =
  val uv = v.unit
  val dt = uv.dot(n)
  val discriminant = 1.0 - niOverNt * niOverNt * (1.0 - dt * dt)
  if discriminant > 0.0 then Some(niOverNt * (uv - dt * n) - math.sqrt(discriminant) * n) else None

/** Schlick's approximation for reflectance at a given angle. */
private def schlick(cosine: Double, refIndex: Double): Double =
  val r0 = (1.0 - refIndex) / (1.0 + refIndex)
  val r0Squared = r0 * r0
  // Multiplied out rather than using pow, to match the other versions'
  // golden image.
  val x = 1.0 - cosine
  val x2 = x * x
  r0Squared + (1.0 - r0Squared) * x2 * x2 * x
