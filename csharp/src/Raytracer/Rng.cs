namespace Raytracer;

/// <summary>
/// A small, fast pseudo-random number generator (SplitMix64), the same as the
/// other versions use, so that scenes and renders are identical.
/// System.Random's algorithm is unspecified and has changed between releases.
/// </summary>
public sealed class Rng(ulong seed)
{
    private ulong _state = seed;

    public ulong NextUInt64()
    {
        // ulong arithmetic wraps.
        _state += 0x9e3779b97f4a7c15;
        ulong z = _state;
        z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9;
        z = (z ^ (z >> 27)) * 0x94d049bb133111eb;
        return z ^ (z >> 31);
    }

    /// <summary>A uniformly distributed number in [0, 1).</summary>
    // The top 53 bits fill a double's mantissa exactly.
    public double NextDouble() => (NextUInt64() >> 11) * (1.0 / (1UL << 53));
}
