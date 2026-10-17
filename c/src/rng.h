#ifndef RAYTRACER_RNG_H
#define RAYTRACER_RNG_H

#include <stdint.h>

/* A small, fast pseudo-random number generator (SplitMix64), the same as the
 * Rust version's.
 *
 * It is seedable, so renders are reproducible, and cheap to create per row. */
typedef struct {
    uint64_t state;
} Rng;

static inline Rng rng_new(uint64_t seed) { return (Rng){.state = seed}; }

static inline uint64_t rng_next_u64(Rng *rng) {
    rng->state += UINT64_C(0x9e3779b97f4a7c15);
    uint64_t z = rng->state;
    z = (z ^ (z >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)) * UINT64_C(0x94d049bb133111eb);
    return z ^ (z >> 31);
}

/* A uniformly distributed double in [0, 1). */
static inline double rng_next(Rng *rng) {
    /* The top 53 bits fill a double's mantissa exactly. */
    return (double)(rng_next_u64(rng) >> 11) * (1.0 / (double)(UINT64_C(1) << 53));
}

#endif
