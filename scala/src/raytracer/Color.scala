package raytracer

final case class Color(r: Double, g: Double, b: Double):
  def +(o: Color): Color = Color(r + o.r, g + o.g, b + o.b)

  /** Component-wise multiplication. */
  def *(o: Color): Color = Color(r * o.r, g * o.g, b * o.b)

  def /(s: Double): Color = Color(r / s, g / s, b / s)

object Color:
  val Black: Color = Color(0, 0, 0)
  val White: Color = Color(1, 1, 1)
