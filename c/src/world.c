#include <math.h>
#include <stdint.h>

#include "world.h"

World world_new(const Sphere *spheres, size_t len, SphereBlock *blocks) {
    for (size_t i = 0; i < WORLD_BLOCKS(len); i++) {
        for (size_t l = 0; l < WORLD_LANES; l++) {
            size_t j = i * WORLD_LANES + l;
            /* A partly filled block is padded with spheres of radius squared
             * -infinity, whose discriminant is -infinity (or NaN for a
             * zero-length ray), so they never hit. */
            if (j >= len) {
                blocks[i].x[l] = blocks[i].y[l] = blocks[i].z[l] = 0;
                blocks[i].radius_squared[l] = -INFINITY;
                continue;
            }
            const Sphere *s = &spheres[j];
            blocks[i].x[l] = s->center.x;
            blocks[i].y[l] = s->center.y;
            blocks[i].z[l] = s->center.z;
            blocks[i].radius_squared[l] = s->radius * s->radius;
        }
    }
    return (World){.spheres = spheres, .len = len, .blocks = blocks};
}

/* This finds the same hit as calling sphere_intersect on each sphere in turn,
 * with the same arithmetic, so renders are unchanged. */
bool world_hit(const World *w, Ray r, double t_min, double t_max, Hit *hit) {
    Vec3 o = r.origin, d = r.direction;
    double a = vec3_dot(d, d);
    /* Only the hit record for the closest sphere is ever needed, so just track
     * which one it is until the end, shrinking the range as nearer ones are
     * found. */
    size_t closest = SIZE_MAX;
    double t_closest = t_max;
    for (size_t i = 0; i < WORLD_BLOCKS(w->len); i++) {
        const SphereBlock *block = &w->blocks[i];
        /* The discriminants don't depend on t_closest, so all four are
         * computed together, in straight-line code that the compiler
         * vectorises. */
        double b[WORLD_LANES], discriminant[WORLD_LANES];
        bool all_miss = true;
        for (size_t l = 0; l < WORLD_LANES; l++) {
            double ox = o.x - block->x[l], oy = o.y - block->y[l], oz = o.z - block->z[l];
            b[l] = ox * d.x + oy * d.y + oz * d.z;
            double c = (ox * ox + oy * oy + oz * oz) - block->radius_squared[l];
            discriminant[l] = b[l] * b[l] - a * c;
            all_miss &= discriminant[l] < 0;
        }
        /* Most rays miss most spheres. */
        if (all_miss) {
            continue;
        }
        /* The distances do depend on t_closest, so they are checked one sphere
         * at a time, in order. */
        for (size_t l = 0; l < WORLD_LANES; l++) {
            if (discriminant[l] < 0) {
                continue;
            }
            double sqrt_d = sqrt(discriminant[l]);
            double t = (-b[l] - sqrt_d) / a;
            if (!(t < t_closest && t > t_min)) {
                t = (-b[l] + sqrt_d) / a;
                if (!(t < t_closest && t > t_min)) {
                    continue;
                }
            }
            closest = i * WORLD_LANES + l;
            t_closest = t;
        }
    }
    if (closest == SIZE_MAX) {
        return false;
    }
    *hit = sphere_hit_at(&w->spheres[closest], r, t_closest);
    return true;
}
