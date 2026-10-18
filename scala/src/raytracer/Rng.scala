package raytracer

/** A small, fast pseudo-random number generator (SplitMix64).
  *
  * The same generator as the other versions use, so that scenes and renders are identical. It is
  * seedable, so renders are reproducible, and cheap to create per row. Not safe to share between
  * threads.
  */
final class Rng(seed: Long):
  // Long arithmetic wraps like Rust's wrapping_add and wrapping_mul, and >>>
  // shifts in zeros like a shift of a u64, so the bits are the same.
  private var state = seed

  def nextLong(): Long =
    state += 0x9e3779b97f4a7c15L
    var z = state
    z = (z ^ (z >>> 30)) * 0xbf58476d1ce4e5b9L
    z = (z ^ (z >>> 27)) * 0x94d049bb133111ebL
    z ^ (z >>> 31)

  /** A uniformly distributed double in [0, 1). */
  def nextDouble(): Double =
    // The top 53 bits fill a double's mantissa exactly.
    (nextLong() >>> 11).toDouble * (1.0 / (1L << 53))
