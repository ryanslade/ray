#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "check.h"
#include "raytracer.h"
#include "scene.h"

/* Relative to c/, where `make test` runs the tests. */
#define GOLDEN_PATH "tests/golden.ppm"
#define ACTUAL_PATH "tests/golden.actual.ppm"

static void test_deterministic_across_threads(void) {
    size_t width = 40, height = 30;
    World world = scene_world();
    Camera camera = scene_camera(width, height);
    Image expected;
    CHECK(render_with_threads(&expected, 1, width, height, 8, &camera, &world));
    size_t thread_counts[] = {2, 4, 7};
    for (size_t i = 0; i < sizeof thread_counts / sizeof thread_counts[0]; i++) {
        Image img;
        CHECK(render_with_threads(&img, thread_counts[i], width, height, 8, &camera, &world));
        CHECK(memcmp(expected.pixels, img.pixels, width * height * 3) == 0);
        image_free(&img);
    }
    image_free(&expected);
}

/* Reads a whole file into a malloc'd buffer, or returns NULL. */
static char *read_file(const char *path, size_t *len) {
    FILE *f = fopen(path, "rb");
    if (f == NULL) {
        return NULL;
    }
    char *data = NULL;
    size_t cap = 0;
    *len = 0;
    for (;;) {
        if (*len == cap) {
            cap = cap ? cap * 2 : 64 * 1024;
            char *grown = realloc(data, cap);
            if (grown == NULL) {
                free(data);
                fclose(f);
                return NULL;
            }
            data = grown;
        }
        size_t n = fread(data + *len, 1, cap - *len, f);
        *len += n;
        if (n == 0) {
            break;
        }
    }
    bool failed = ferror(f);
    fclose(f);
    if (failed) {
        free(data);
        return NULL;
    }
    return data;
}

/* Renders the test scene and compares it with `tests/golden.ppm`.
 *
 * After an intentional change to the output, run with `UPDATE_GOLDEN=1` to
 * accept it. On a mismatch the rendered image is written to
 * `tests/golden.actual.ppm` for inspection. */
static void test_golden_image(void) {
    size_t width = 200, height = 200;
    World world = scene_world();
    Camera camera = scene_camera(width, height);
    Image img;
    CHECK(render(&img, width, height, 100, &camera, &world));

    if (getenv("UPDATE_GOLDEN") != NULL) {
        CHECK(image_save_ppm(&img, GOLDEN_PATH));
        image_free(&img);
        return;
    }

    char header[32];
    int header_len = snprintf(header, sizeof header, "P6\n%zu %zu\n255\n", width, height);
    size_t pixels_len = width * height * 3;
    size_t len;
    char *expected = read_file(GOLDEN_PATH, &len);
    CHECK(expected != NULL);
    bool same = expected != NULL && len == (size_t)header_len + pixels_len &&
                memcmp(expected, header, (size_t)header_len) == 0 &&
                memcmp(expected + header_len, img.pixels, pixels_len) == 0;
    if (!same) {
        CHECK(image_save_ppm(&img, ACTUAL_PATH));
        fprintf(stderr, "rendered image doesn't match %s; wrote it to %s\n", GOLDEN_PATH,
                ACTUAL_PATH);
    }
    CHECK(same);
    free(expected);
    image_free(&img);
}

int main(void) {
    RUN_TEST(test_deterministic_across_threads);
    RUN_TEST(test_golden_image);
    return CHECK_EXIT();
}
