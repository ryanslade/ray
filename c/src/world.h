#ifndef RAYTRACER_WORLD_H
#define RAYTRACER_WORLD_H

#include <stdbool.h>
#include <stddef.h>

#include "hit.h"
#include "ray.h"
#include "sphere.h"

/* The objects in a scene. It doesn't own `spheres`. */
typedef struct {
    const Sphere *spheres;
    size_t len;
} World;

/* Stores the closest hit in `hit`, or returns false if the ray misses
 * everything. */
bool world_hit(const World *w, Ray r, double t_min, double t_max, Hit *hit);

#endif
