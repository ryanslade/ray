#include "material.h"

#include <math.h>

#include "hit.h"

Material material_lambertian(Color albedo) {
    return (Material){.kind = MATERIAL_LAMBERTIAN, .lambertian = {.albedo = albedo}};
}

Material material_metal(Color albedo, double fuzz) {
    double clamped = fuzz < 0 ? 0 : fuzz > 1 ? 1 : fuzz;
    return (Material){.kind = MATERIAL_METAL, .metal = {.albedo = albedo, .fuzz = clamped}};
}

Material material_dielectric(double ref_index) {
    return (Material){.kind = MATERIAL_DIELECTRIC, .dielectric = {.ref_index = ref_index}};
}

static Vec3 reflect(Vec3 v, Vec3 n) { return vec3_sub(v, vec3_scale(n, 2 * vec3_dot(v, n))); }

bool material_refract(Vec3 v, Vec3 n, double ni_over_nt, Vec3 *out) {
    Vec3 uv = vec3_unit(v);
    double dt = vec3_dot(uv, n);
    double discriminant = 1 - ni_over_nt * ni_over_nt * (1 - dt * dt);
    if (discriminant > 0) {
        *out = vec3_sub(vec3_scale(vec3_sub(uv, vec3_scale(n, dt)), ni_over_nt),
                        vec3_scale(n, sqrt(discriminant)));
        return true;
    }
    return false;
}

/* Schlick's approximation for reflectance at a given angle. */
static double schlick(double cosine, double ref_index) {
    double r0 = (1 - ref_index) / (1 + ref_index);
    r0 = r0 * r0;
    /* Multiplied out rather than using pow, so that the result matches the
     * Rust version exactly. */
    double x = 1 - cosine;
    double x2 = x * x;
    return r0 + (1 - r0) * x2 * x2 * x;
}

bool material_scatter(const Material *m, Ray in, const Hit *hit, Rng *rng, Scatter *out) {
    Vec3 point = hit->point;
    Vec3 normal = hit->normal;
    switch (m->kind) {
    case MATERIAL_LAMBERTIAN: {
        Vec3 target = vec3_add(vec3_add(point, normal), vec3_random_in_unit_sphere(rng));
        *out = (Scatter){.attenuation = m->lambertian.albedo,
                         .ray = ray_new(point, vec3_sub(target, point))};
        return true;
    }
    case MATERIAL_METAL: {
        Vec3 reflected = reflect(vec3_unit(in.direction), normal);
        Vec3 direction =
            vec3_add(reflected, vec3_scale(vec3_random_in_unit_sphere(rng), m->metal.fuzz));
        if (vec3_dot(direction, normal) > 0) {
            *out = (Scatter){.attenuation = m->metal.albedo, .ray = ray_new(point, direction)};
            return true;
        }
        return false;
    }
    case MATERIAL_DIELECTRIC: {
        double ref_index = m->dielectric.ref_index;
        Vec3 d = in.direction;
        double d_dot_n = vec3_dot(d, normal);
        Vec3 outward_normal;
        double ni_over_nt, cosine;
        if (d_dot_n > 0) {
            outward_normal = vec3_neg(normal);
            ni_over_nt = ref_index;
            cosine = ref_index * d_dot_n / vec3_length(d);
        } else {
            outward_normal = normal;
            ni_over_nt = 1 / ref_index;
            cosine = -d_dot_n / vec3_length(d);
        }
        Vec3 refracted;
        Vec3 direction = material_refract(d, outward_normal, ni_over_nt, &refracted) &&
                                 rng_next(rng) >= schlick(cosine, ref_index)
                             ? refracted
                             : reflect(d, normal);
        *out = (Scatter){.attenuation = COLOR_WHITE, .ray = ray_new(point, direction)};
        return true;
    }
    }
    return false;
}
