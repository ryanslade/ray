const std = @import("std");

/// A small, fast pseudo-random number generator (SplitMix64), the same as the
/// Rust version's.
///
/// It is seedable, so renders are reproducible, and cheap to create per row.
pub const Rng = struct {
    state: u64,

    pub fn init(seed: u64) Rng {
        return .{ .state = seed };
    }

    pub fn nextU64(self: *Rng) u64 {
        self.state +%= 0x9e37_79b9_7f4a_7c15;
        var z = self.state;
        z = (z ^ (z >> 30)) *% 0xbf58_476d_1ce4_e5b9;
        z = (z ^ (z >> 27)) *% 0x94d0_49bb_1331_11eb;
        return z ^ (z >> 31);
    }

    /// A uniformly distributed float in [0, 1).
    pub fn next(self: *Rng) f64 {
        // The top 53 bits fill an f64 mantissa exactly.
        const bits: f64 = @floatFromInt(self.nextU64() >> 11);
        return bits * (1.0 / @as(f64, 1 << 53));
    }
};

test "floats in unit interval" {
    var rng: Rng = .init(1);
    for (0..10_000) |_| {
        const f = rng.next();
        try std.testing.expect(f >= 0 and f < 1);
    }
}

test "same seed same sequence" {
    var a: Rng = .init(42);
    var b: Rng = .init(42);
    for (0..100) |_| try std.testing.expectEqual(a.nextU64(), b.nextU64());
}
