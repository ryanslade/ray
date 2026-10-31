namespace Raytracer

/// A small, fast pseudo-random number generator (SplitMix64), the same as the
/// other versions use, so that scenes and renders are identical.
/// System.Random's algorithm is unspecified and has changed between releases.
type Rng(seed: uint64) =
    let mutable state = seed

    member _.NextUInt64() =
        // uint64 arithmetic wraps.
        state <- state + 0x9e3779b97f4a7c15UL
        let z = (state ^^^ (state >>> 30)) * 0xbf58476d1ce4e5b9UL
        let z = (z ^^^ (z >>> 27)) * 0x94d049bb133111ebUL
        z ^^^ (z >>> 31)

    /// A uniformly distributed number in [0, 1).
    // The top 53 bits fill a float's mantissa exactly.
    member this.NextFloat() =
        float (this.NextUInt64() >>> 11) * (1.0 / float (1UL <<< 53))
