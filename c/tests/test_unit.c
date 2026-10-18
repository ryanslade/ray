#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "check.h"
#include "raytracer.h"

static bool close_to(Vec3 expected, Vec3 actual) {
    return vec3_length(vec3_sub(expected, actual)) < 1e-9;
}

static void test_vec3_arithmetic(void) {
    Vec3 a = vec3(1, 2, 3);
    Vec3 b = vec3(4, 5, 6);
    CHECK(close_to(vec3(5, 7, 9), vec3_add(a, b)));
    CHECK(close_to(vec3(2, 4, 6), vec3_scale(a, 2)));
    CHECK(vec3_dot(a, b) == 32);
    CHECK(close_to(vec3(-3, 6, -3), vec3_cross(a, b)));
    CHECK(fabs(vec3_length(vec3_unit(b)) - 1) < 1e-9);
}

static void test_rng_floats_in_unit_interval(void) {
    Rng rng = rng_new(1);
    for (int i = 0; i < 10000; i++) {
        double f = rng_next(&rng);
        CHECK(f >= 0 && f < 1);
    }
}

static void test_rng_same_seed_same_sequence(void) {
    Rng a = rng_new(42);
    Rng b = rng_new(42);
    for (int i = 0; i < 100; i++) {
        CHECK(rng_next_u64(&a) == rng_next_u64(&b));
    }
}

static void test_sphere_hit(void) {
    Sphere s = sphere(vec3(0, 0, -1), 0.5, material_dielectric(1.5));
    Ray towards = ray_new(vec3(0, 0, 0), vec3(0, 0, -1));
    Hit h;

    CHECK(sphere_hit(&s, towards, 0, INFINITY, &h));
    CHECK(h.t == 0.5);
    CHECK(h.normal.x == 0 && h.normal.y == 0 && h.normal.z == 1);
    CHECK(h.material == &s.material);

    CHECK(sphere_hit(&s, towards, 0.6, INFINITY, &h));
    CHECK(h.t == 1.5);

    Ray away = ray_new(vec3(0, 0, 0), vec3(0, 1, 0));
    CHECK(!sphere_hit(&s, away, 0, INFINITY, &h));
}

static void test_world_closest_hit(void) {
    Material m = material_dielectric(1.5);
    Sphere spheres[] = {
        sphere(vec3(0, 0, -5), 1, m),
        sphere(vec3(0, 0, -2), 0.5, m),
    };
    SphereBlock blocks[WORLD_BLOCKS(2)];
    World world = world_new(spheres, 2, blocks);
    Hit h;
    CHECK(world_hit(&world, ray_new(vec3(0, 0, 0), vec3(0, 0, -1)), 0, INFINITY, &h));
    CHECK(h.t == 1.5);
}

/* A random number in (-scale, scale). */
static double random_coord(Rng *rng, double scale) { return scale * (2 * rng_next(rng) - 1); }

/* The blocked loop finds exactly the hit that testing each sphere in turn
 * would, for every number of spheres modulo the block size. */
static void test_world_matches_sphere_by_sphere(void) {
    enum { SPHERES = 23, RAYS = 2000 };
    Rng rng = rng_new(1);
    Material m = material_dielectric(1.5);
    Sphere spheres[SPHERES];
    for (size_t i = 0; i < SPHERES; i++) {
        Vec3 center = vec3(random_coord(&rng, 3), random_coord(&rng, 3), random_coord(&rng, 3));
        spheres[i] = sphere(center, 0.1 + fabs(random_coord(&rng, 1)), m);
    }
    static Ray rays[RAYS];
    for (size_t i = 0; i < RAYS; i++) {
        Vec3 origin = vec3(random_coord(&rng, 5), random_coord(&rng, 5), random_coord(&rng, 5));
        rays[i] = ray_new(
            origin, vec3(random_coord(&rng, 1), random_coord(&rng, 1), random_coord(&rng, 1)));
    }
    for (size_t n = 0; n < SPHERES; n++) {
        SphereBlock blocks[WORLD_BLOCKS(SPHERES)];
        World world = world_new(spheres, n, blocks);
        for (size_t i = 0; i < RAYS; i++) {
            const Sphere *want = NULL;
            double want_t = DBL_MAX, t;
            for (size_t j = 0; j < n; j++) {
                if (sphere_intersect(&spheres[j], rays[i], 0.001, want_t, &t)) {
                    want = &spheres[j];
                    want_t = t;
                }
            }
            Hit h;
            bool got = world_hit(&world, rays[i], 0.001, DBL_MAX, &h);
            CHECK(got == (want != NULL));
            if (got && want != NULL) {
                Hit expected = sphere_hit_at(want, rays[i], want_t);
                CHECK(h.t == expected.t && h.material == expected.material &&
                      memcmp(&h.point, &expected.point, sizeof h.point) == 0 &&
                      memcmp(&h.normal, &expected.normal, sizeof h.normal) == 0);
            }
        }
    }
}

static void test_total_internal_reflection(void) {
    Vec3 out;
    CHECK(!material_refract(vec3(1, -0.1, 0), vec3(0, 1, 0), 1.5, &out));
}

static void test_refracts_head_on(void) {
    Vec3 down = vec3(0, -1, 0);
    Vec3 r;
    CHECK(material_refract(down, vec3(0, 1, 0), 1.0 / 1.5, &r));
    CHECK(close_to(down, r));
}

static void test_metal_fuzz_is_clamped(void) {
    CHECK(material_metal(COLOR_WHITE, 2).metal.fuzz == 1);
    CHECK(material_metal(COLOR_WHITE, -1).metal.fuzz == 0);
}

static void test_image_set_clamps(void) {
    Image img;
    CHECK(image_init(&img, 2, 1));
    image_set(&img, 1, 0, color(2, 0.5, -1));
    image_set(&img, 0, 0, color(NAN, 0, 0));
    CHECK(memcmp(image_get(&img, 0, 0), (uint8_t[]){0, 0, 0}, 3) == 0);
    CHECK(memcmp(image_get(&img, 1, 0), (uint8_t[]){255, 127, 0}, 3) == 0);
    image_free(&img);
}

static void test_ppm_header(void) {
    Image img;
    CHECK(image_init(&img, 3, 2));
    char buf[64];
    FILE *f = tmpfile();
    CHECK(f != NULL);
    if (f == NULL) {
        image_free(&img);
        return;
    }
    CHECK(image_write_ppm(&img, f));
    long len = ftell(f);
    rewind(f);
    size_t n = fread(buf, 1, sizeof buf, f);
    fclose(f);
    CHECK(len == 11 + 3 * 2 * 3);
    CHECK(n == 11 + 3 * 2 * 3);
    CHECK(memcmp(buf, "P6\n3 2\n255\n", 11) == 0);
    image_free(&img);
}

int main(void) {
    RUN_TEST(test_vec3_arithmetic);
    RUN_TEST(test_rng_floats_in_unit_interval);
    RUN_TEST(test_rng_same_seed_same_sequence);
    RUN_TEST(test_sphere_hit);
    RUN_TEST(test_world_closest_hit);
    RUN_TEST(test_world_matches_sphere_by_sphere);
    RUN_TEST(test_total_internal_reflection);
    RUN_TEST(test_refracts_head_on);
    RUN_TEST(test_metal_fuzz_is_clamped);
    RUN_TEST(test_image_set_clamps);
    RUN_TEST(test_ppm_header);
    return CHECK_EXIT();
}
