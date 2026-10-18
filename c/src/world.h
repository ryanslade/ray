#ifndef RAYTRACER_WORLD_H
#define RAYTRACER_WORLD_H

#include <stdbool.h>
#include <stddef.h>

#include "hit.h"
#include "ray.h"
#include "sphere.h"

/* How many spheres the closest-hit loop tests at once. */
#define WORLD_LANES 4

/* The number of blocks a world of `len` spheres needs. */
#define WORLD_BLOCKS(len) (((len) + WORLD_LANES - 1) / WORLD_LANES)

/* The centres and squared radii of WORLD_LANES spheres, stored as a structure
 * of arrays so that the closest-hit loop can work on all of them at once with
 * vector instructions. */
typedef struct {
    double x[WORLD_LANES], y[WORLD_LANES], z[WORLD_LANES], radius_squared[WORLD_LANES];
} SphereBlock;

/* The objects in a scene. It owns neither `spheres` nor `blocks`. */
typedef struct {
    const Sphere *spheres;
    size_t len;
    const SphereBlock *blocks;
} World;

/* A world of the `len` spheres in `spheres`, filling in `blocks`, which must
 * have room for WORLD_BLOCKS(len) of them. */
World world_new(const Sphere *spheres, size_t len, SphereBlock *blocks);

/* Stores the closest hit in `hit`, or returns false if the ray misses
 * everything. */
bool world_hit(const World *w, Ray r, double t_min, double t_max, Hit *hit);

#endif
