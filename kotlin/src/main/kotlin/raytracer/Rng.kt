package raytracer

/**
 * A small, fast pseudo-random number generator (SplitMix64).
 *
 * The same generator as the other versions use, so that scenes and renders are
 * identical. It is seedable, so renders are reproducible, and cheap to create
 * per row. Not safe to share between threads.
 */
class Rng(
    seed: Long,
) {
    private var state = seed.toULong()

    fun nextU64(): ULong {
        state += 0x9e3779b97f4a7c15uL
        var z = state
        z = (z xor (z shr 30)) * 0xbf58476d1ce4e5b9uL
        z = (z xor (z shr 27)) * 0x94d049bb133111ebuL
        return z xor (z shr 31)
    }

    /** A uniformly distributed double in [0, 1). */
    fun nextDouble(): Double {
        // The top 53 bits fill a double's mantissa exactly. They fit in a
        // signed long, which converts to a double faster than a ULong does.
        return (nextU64() shr 11).toLong().toDouble() * (1.0 / (1L shl 53))
    }
}
