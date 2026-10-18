package raytracer

import scala.annotation.tailrec

final case class Vec3(x: Double, y: Double, z: Double):
  def +(o: Vec3): Vec3 = Vec3(x + o.x, y + o.y, z + o.z)
  def -(o: Vec3): Vec3 = Vec3(x - o.x, y - o.y, z - o.z)
  def /(s: Double): Vec3 = Vec3(x / s, y / s, z / s)
  def unary_- : Vec3 = Vec3(-x, -y, -z)

  def dot(o: Vec3): Double = x * o.x + y * o.y + z * o.z

  def cross(o: Vec3): Vec3 =
    Vec3(
      y * o.z - z * o.y,
      z * o.x - x * o.z,
      x * o.y - y * o.x
    )

  def lengthSquared: Double = dot(this)
  def length: Double = math.sqrt(lengthSquared)
  def unit: Vec3 = this / length

object Vec3:
  val Zero: Vec3 = Vec3(0, 0, 0)

  /** Rejection sampling: pick points in the enclosing cube until one lands inside. */
  @tailrec
  def randomInUnitSphere(rng: Rng): Vec3 =
    val p =
      Vec3(2.0 * rng.nextDouble() - 1.0, 2.0 * rng.nextDouble() - 1.0, 2.0 * rng.nextDouble() - 1.0)
    if p.lengthSquared < 1.0 then p else randomInUnitSphere(rng)

  @tailrec
  def randomInUnitDisk(rng: Rng): Vec3 =
    val p = Vec3(2.0 * rng.nextDouble() - 1.0, 2.0 * rng.nextDouble() - 1.0, 0)
    if p.lengthSquared < 1.0 then p else randomInUnitDisk(rng)

// Scaling by a number on the left, as in the other versions. Both overloads
// are here, since two top-level extensions named * in the same package would
// be ambiguous.
extension (s: Double)
  def *(v: Vec3): Vec3 = Vec3(s * v.x, s * v.y, s * v.z)
  def *(c: Color): Color = Color(s * c.r, s * c.g, s * c.b)
