#ifndef RAYTRACER_MATERIAL_H
#define RAYTRACER_MATERIAL_H

#include <stdbool.h>

#include "color.h"
#include "ray.h"
#include "rng.h"

typedef enum {
    MATERIAL_LAMBERTIAN,
    MATERIAL_METAL,
    MATERIAL_DIELECTRIC,
} MaterialKind;

typedef struct {
    MaterialKind kind;
    union {
        struct {
            Color albedo;
        } lambertian;
        struct {
            Color albedo;
            double fuzz;
        } metal;
        struct {
            double ref_index;
        } dielectric;
    };
} Material;

typedef struct {
    Color attenuation;
    Ray ray;
} Scatter;

struct Hit;

Material material_lambertian(Color albedo);

/* `fuzz` is clamped to [0, 1]: 0 is a perfect mirror. */
Material material_metal(Color albedo, double fuzz);

Material material_dielectric(double ref_index);

/* Stores the attenuation and scattered ray in `out`, or returns false if the
 * ray is absorbed. */
bool material_scatter(const Material *m, Ray in, const struct Hit *hit, Rng *rng, Scatter *out);

/* Exposed for the tests. Returns false on total internal reflection. */
bool material_refract(Vec3 v, Vec3 n, double ni_over_nt, Vec3 *out);

#endif
