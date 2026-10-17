/* Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with 50
 * samples per pixel. Usage: bench [iterations] [threads] */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "raytracer.h"
#include "scene.h"

#define WIDTH 100
#define HEIGHT 100

static void run(size_t threads, const Camera *camera, const World *world) {
    Image img;
    if (!render_with_threads(&img, threads, WIDTH, HEIGHT, 50, camera, world)) {
        fprintf(stderr, "Rendering: %s\n", strerror(errno));
        exit(EXIT_FAILURE);
    }
    image_free(&img);
}

static size_t parse_count(const char *s) {
    char *end;
    errno = 0;
    unsigned long long n = strtoull(s, &end, 10);
    if (errno != 0 || end == s || *end != '\0' || n == 0) {
        fprintf(stderr, "Invalid count: %s\n", s);
        exit(EXIT_FAILURE);
    }
    return (size_t)n;
}

int main(int argc, char **argv) {
    size_t iterations = argc > 1 ? parse_count(argv[1]) : 20;
    size_t threads = argc > 2 ? parse_count(argv[2]) : default_threads();

    World world = scene_world();
    Camera camera = scene_camera(WIDTH, HEIGHT);
    run(threads, &camera, &world);
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    for (size_t i = 0; i < iterations; i++) {
        run(threads, &camera, &world);
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    double ns = (double)(end.tv_sec - start.tv_sec) * 1e9 + (double)(end.tv_nsec - start.tv_nsec);
    fprintf(stderr, "%zu iterations on %zu threads: %.2f ms/op\n", iterations, threads,
            ns / 1e6 / (double)iterations);
    return EXIT_SUCCESS;
}
