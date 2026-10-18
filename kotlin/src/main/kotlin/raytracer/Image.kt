package raytracer

import java.io.File

/** An 8-bit RGB image. Row 0 is the top. */
class Image(
    val width: Int,
    val height: Int,
) {
    internal val pixels = ByteArray(width * height * 3)

    /** Stores a colour, clamping each channel to [0, 1]. */
    fun set(
        x: Int,
        y: Int,
        c: Color,
    ) = setPixel(pixels, index(x, y), c)

    /** The pixel at ([x], [y]) as (r, g, b), each in [0, 255]. */
    fun get(
        x: Int,
        y: Int,
    ): Triple<Int, Int, Int> {
        val i = index(x, y)
        return Triple(pixels[i].toUByte().toInt(), pixels[i + 1].toUByte().toInt(), pixels[i + 2].toUByte().toInt())
    }

    /** Binary (P6) PPM encoding. */
    fun toPpm(): ByteArray = "P6\n$width $height\n255\n".toByteArray(Charsets.US_ASCII) + pixels

    fun savePpm(path: String) = File(path).writeBytes(toPpm())

    override fun equals(other: Any?) =
        other is Image && width == other.width && height == other.height && pixels.contentEquals(other.pixels)

    override fun hashCode() = pixels.contentHashCode()

    private fun index(
        x: Int,
        y: Int,
    ): Int {
        if (x !in 0..<width || y !in 0..<height) throw IndexOutOfBoundsException("pixel out of bounds")
        return 3 * (y * width + x)
    }
}

/** Writes a colour to the pixel at byte offset [i], clamping each channel to [0, 1]. */
internal fun setPixel(
    pixels: ByteArray,
    i: Int,
    c: Color,
) {
    pixels[i] = toByte(c.r)
    pixels[i + 1] = toByte(c.g)
    pixels[i + 2] = toByte(c.b)
}

// Written so that NaN becomes 255, like f64::min followed by a saturating cast
// in the Rust version.
private fun toByte(v: Double): Byte {
    val b = 255.99 * (if (v < 1.0) v else 1.0)
    return if (b > 0.0) b.toInt().toByte() else 0
}
