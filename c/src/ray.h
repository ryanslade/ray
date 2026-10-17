#ifndef RAYTRACER_RAY_H
#define RAYTRACER_RAY_H

#include "vec3.h"

typedef struct {
    Vec3 origin;
    Vec3 direction;
} Ray;

static inline Ray ray_new(Vec3 origin, Vec3 direction) {
    return (Ray){.origin = origin, .direction = direction};
}

static inline Vec3 ray_at(Ray r, double t) {
    return vec3_add(r.origin, vec3_scale(r.direction, t));
}

#endif
