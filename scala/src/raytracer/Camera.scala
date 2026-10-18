package raytracer

/** Settings for [[Camera]]. `vfov` is the vertical field of view in degrees. */
final case class CameraSettings(
    lookFrom: Vec3,
    lookAt: Vec3,
    vUp: Vec3,
    vfov: Double,
    aspect: Double,
    aperture: Double,
    focusDist: Double
)

final class Camera(s: CameraSettings):
  private val theta = math.toRadians(s.vfov)
  // StrictMath gives the same result on every JVM.
  private val halfHeight = StrictMath.tan(theta / 2.0)
  private val halfWidth = s.aspect * halfHeight
  private val w = (s.lookFrom - s.lookAt).unit
  private val u = s.vUp.cross(w).unit
  private val v = w.cross(u)
  private val origin = s.lookFrom
  private val lowerLeft =
    s.lookFrom - (halfWidth * s.focusDist) * u - (halfHeight * s.focusDist) * v - s.focusDist * w
  private val horizontal = (2.0 * halfWidth * s.focusDist) * u
  private val vertical = (2.0 * halfHeight * s.focusDist) * v
  private val lensRadius = s.aperture / 2.0

  /** A ray through the viewport at normalised coordinates (`s`, `t`), with its origin jittered
    * across the lens.
    */
  def getRay(s: Double, t: Double, rng: Rng): Ray =
    val rd = lensRadius * Vec3.randomInUnitDisk(rng)
    val offset = rd.x * u + rd.y * v
    Ray(origin + offset, lowerLeft + s * horizontal + t * vertical - origin - offset)
