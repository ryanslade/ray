package raytracer

import java.nio.charset.StandardCharsets.US_ASCII
import java.nio.file.{Files, Path}

/** An 8-bit RGB image. Row 0 is the top. */
final class Image(val width: Int, val height: Int):
  private[raytracer] val pixels = new Array[Byte](width * height * 3)

  /** Stores a colour, clamping each channel to [0, 1]: `img(x, y) = c`. */
  def update(x: Int, y: Int, c: Color): Unit = Image.setPixel(pixels, index(x, y), c)

  /** The pixel at (`x`, `y`) as (r, g, b), each in [0, 255]. */
  def apply(x: Int, y: Int): (Int, Int, Int) =
    val i = index(x, y)
    (pixels(i) & 0xff, pixels(i + 1) & 0xff, pixels(i + 2) & 0xff)

  /** Binary (P6) PPM encoding. */
  def toPpm: Array[Byte] = s"P6\n$width $height\n255\n".getBytes(US_ASCII) ++ pixels

  def savePpm(path: String): Unit = Files.write(Path.of(path), toPpm)

  override def equals(other: Any): Boolean = other match
    case o: Image =>
      width == o.width && height == o.height && java.util.Arrays.equals(pixels, o.pixels)
    case _ => false

  override def hashCode: Int = java.util.Arrays.hashCode(pixels)

  private def index(x: Int, y: Int): Int =
    if x < 0 || x >= width || y < 0 || y >= height then
      throw IndexOutOfBoundsException("pixel out of bounds")
    3 * (y * width + x)

object Image:
  /** Writes a colour to the pixel at byte offset `i`, clamping each channel to [0, 1]. */
  private[raytracer] def setPixel(pixels: Array[Byte], i: Int, c: Color): Unit =
    pixels(i) = toByte(c.r)
    pixels(i + 1) = toByte(c.g)
    pixels(i + 2) = toByte(c.b)

  // Written so that NaN becomes 255, like f64::min followed by a saturating
  // cast in the Rust version.
  private def toByte(v: Double): Byte =
    val b = 255.99 * (if v < 1.0 then v else 1.0)
    if b > 0.0 then b.toInt.toByte else 0
