#ifndef RAYTRACER_SPHERE_H
#define RAYTRACER_SPHERE_H

#include <math.h>
#include <stdbool.h>

#include "hit.h"
#include "material.h"
#include "ray.h"
#include "vec3.h"

typedef struct {
    Vec3 center;
    double radius;
    Material material;
} Sphere;

static inline Sphere sphere(Vec3 center, double radius, Material material) {
    return (Sphere){.center = center, .radius = radius, .material = material};
}

/* Stores in `t` the nearest point in (`t_min`, `t_max`) at which the ray meets
 * the sphere, or returns false if there is none.
 *
 * Defined here so it can be inlined into the closest-hit loop. */
static inline bool sphere_intersect(const Sphere *s, Ray r, double t_min, double t_max, double *t) {
    Vec3 oc = vec3_sub(r.origin, s->center);
    double a = vec3_dot(r.direction, r.direction);
    double b = vec3_dot(oc, r.direction);
    double c = vec3_dot(oc, oc) - s->radius * s->radius;
    double discriminant = b * b - a * c;
    if (discriminant < 0) {
        return false;
    }
    double sqrt_d = sqrt(discriminant);
    double near = (-b - sqrt_d) / a;
    if (near < t_max && near > t_min) {
        *t = near;
        return true;
    }
    double far = (-b + sqrt_d) / a;
    if (far < t_max && far > t_min) {
        *t = far;
        return true;
    }
    return false;
}

/* The hit record for a `t` found by `sphere_intersect`. */
Hit sphere_hit_at(const Sphere *s, Ray r, double t);

bool sphere_hit(const Sphere *s, Ray r, double t_min, double t_max, Hit *hit);

#endif
