#ifndef RAYTRACER_VEC3_H
#define RAYTRACER_VEC3_H

#include <math.h>

#include "rng.h"

typedef struct {
    double x, y, z;
} Vec3;

static inline Vec3 vec3(double x, double y, double z) { return (Vec3){.x = x, .y = y, .z = z}; }

static inline Vec3 vec3_add(Vec3 a, Vec3 b) { return vec3(a.x + b.x, a.y + b.y, a.z + b.z); }

static inline Vec3 vec3_sub(Vec3 a, Vec3 b) { return vec3(a.x - b.x, a.y - b.y, a.z - b.z); }

static inline Vec3 vec3_scale(Vec3 v, double s) { return vec3(s * v.x, s * v.y, s * v.z); }

static inline Vec3 vec3_div(Vec3 v, double s) { return vec3(v.x / s, v.y / s, v.z / s); }

static inline Vec3 vec3_neg(Vec3 v) { return vec3(-v.x, -v.y, -v.z); }

static inline double vec3_dot(Vec3 a, Vec3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }

static inline Vec3 vec3_cross(Vec3 a, Vec3 b) {
    return vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
}

static inline double vec3_length_squared(Vec3 v) { return vec3_dot(v, v); }

static inline double vec3_length(Vec3 v) { return sqrt(vec3_length_squared(v)); }

static inline Vec3 vec3_unit(Vec3 v) { return vec3_div(v, vec3_length(v)); }

/* Rejection sampling: pick points in the enclosing cube until one lands
 * inside. */
static inline Vec3 vec3_random_in_unit_sphere(Rng *rng) {
    for (;;) {
        double x = 2 * rng_next(rng) - 1;
        double y = 2 * rng_next(rng) - 1;
        double z = 2 * rng_next(rng) - 1;
        Vec3 p = vec3(x, y, z);
        if (vec3_length_squared(p) < 1) {
            return p;
        }
    }
}

static inline Vec3 vec3_random_in_unit_disk(Rng *rng) {
    for (;;) {
        double x = 2 * rng_next(rng) - 1;
        double y = 2 * rng_next(rng) - 1;
        Vec3 p = vec3(x, y, 0);
        if (vec3_length_squared(p) < 1) {
            return p;
        }
    }
}

#endif
