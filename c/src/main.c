#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "raytracer.h"

#define WIDTH 800
#define HEIGHT 450
#define SAMPLES 100

/* The ground, a 22x22 grid of small spheres (less any too close to the metal
 * one at (4, 1, 0)) and three large ones. */
#define MAX_SPHERES (1 + 22 * 22 + 3)

/* The product of two random numbers, drawn in a fixed order. */
static double random_channel(Rng *rng) {
    double a = rng_next(rng);
    return a * rng_next(rng);
}

static World random_world(Sphere spheres[MAX_SPHERES], Rng *rng) {
    size_t n = 0;
    spheres[n++] = sphere(vec3(0, -1000, -1), 1000, material_lambertian(color(0.5, 0.5, 0.5)));

    for (double a = -11; a < 11; a += 1) {
        for (double b = -11; b < 11; b += 1) {
            double x = a + 0.9 * rng_next(rng);
            double z = b + 0.9 * rng_next(rng);
            Vec3 center = vec3(x, 0.2, z);
            if (vec3_length(vec3_sub(center, vec3(4, 0.2, 0))) <= 0.9) {
                continue;
            }
            double r = random_channel(rng);
            double g = random_channel(rng);
            double bl = random_channel(rng);
            spheres[n++] = sphere(center, 0.2, material_lambertian(color(r, g, bl)));
        }
    }

    spheres[n++] = sphere(vec3(4, 1, 0), 1, material_metal(color(0.8, 0.6, 0.2), 0.1));
    spheres[n++] = sphere(vec3(0, 1, 0), 1, material_dielectric(1.5));
    spheres[n++] = sphere(vec3(-4, 1, 0), 1, material_metal(color(0.8, 0.8, 0.8), 0.2));
    return (World){.spheres = spheres, .len = n};
}

int main(int argc, char **argv) {
    const char *output = argc > 1 ? argv[1] : "out.ppm";

    fprintf(stderr, "Generating world\n");
    static Sphere spheres[MAX_SPHERES];
    Rng rng = rng_new(1);
    World world = random_world(spheres, &rng);
    Vec3 look_from = vec3(3, 2, 3);
    Vec3 look_at = vec3(0, 0, -1);
    Camera camera = camera_new((CameraSettings){
        .look_from = look_from,
        .look_at = look_at,
        .v_up = vec3(0, 1, 0),
        .vfov = 90,
        .aspect = (double)WIDTH / HEIGHT,
        .aperture = 0.01,
        .focus_dist = vec3_length(vec3_sub(look_from, look_at)),
    });

    fprintf(stderr, "Rendering on %zu threads\n", default_threads());
    Image img;
    if (!render(&img, WIDTH, HEIGHT, SAMPLES, &camera, &world)) {
        fprintf(stderr, "Rendering: %s\n", strerror(errno));
        return EXIT_FAILURE;
    }
    bool saved = image_save_ppm(&img, output);
    int err = errno;
    image_free(&img);
    if (!saved) {
        fprintf(stderr, "Writing %s: %s\n", output, strerror(err));
        return EXIT_FAILURE;
    }
    fprintf(stderr, "Wrote %s\n", output);
    return EXIT_SUCCESS;
}
