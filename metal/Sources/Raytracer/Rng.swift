/// A small, fast pseudo-random number generator (SplitMix64), the same as the
/// CPU versions' and the one the shader uses.
///
/// It is seedable, so scenes are reproducible.
public struct Rng {
    var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func nextU64() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }

    /// A uniformly distributed double in [0, 1).
    public mutating func next() -> Double {
        // The top 53 bits fill a double's mantissa exactly.
        Double(nextU64() >> 11) * (1.0 / Double(UInt64(1) << 53))
    }
}
