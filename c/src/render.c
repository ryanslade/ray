/* For _SC_NPROCESSORS_ONLN, which isn't in POSIX. */
#define _DARWIN_C_SOURCE
#define _DEFAULT_SOURCE

#include "render.h"

#include <assert.h>
#include <float.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <unistd.h>

#define MAX_DEPTH 50

Color ray_color(const World *world, Ray r, Rng *rng) {
    /* The product of the attenuations of every surface hit so far. */
    Color attenuation = COLOR_WHITE;
    for (int depth = 0; depth <= MAX_DEPTH; depth++) {
        Hit hit;
        if (!world_hit(world, r, 0.001, DBL_MAX, &hit)) {
            double t = 0.5 * (vec3_unit(r.direction).y + 1);
            Color sky =
                color_add(color_scale(COLOR_WHITE, 1 - t), color_scale(color(0.5, 0.7, 1), t));
            return color_mul(attenuation, sky);
        }
        if (depth == MAX_DEPTH) {
            break;
        }
        Scatter s;
        if (!material_scatter(hit.material, r, &hit, rng, &s)) {
            break;
        }
        attenuation = color_mul(attenuation, s.attenuation);
        r = s.ray;
    }
    return COLOR_BLACK;
}

size_t default_threads(void) {
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? (size_t)n : 1;
}

bool render(Image *img, size_t width, size_t height, unsigned samples, const Camera *camera,
            const World *world) {
    return render_with_threads(img, default_threads(), width, height, samples, camera, world);
}

typedef struct {
    Image *img;
    unsigned samples;
    const Camera *camera;
    const World *world;
    /* Rows vary a lot in cost (sky is cheap, spheres are expensive), so
     * threads take rows one at a time rather than a fixed block each. */
    atomic_size_t next_row;
} Job;

static void render_row(const Job *job, size_t y) {
    size_t width = job->img->width;
    size_t height = job->img->height;
    Rng rng = rng_new(y + 1);
    double fw = (double)width;
    double fh = (double)height;
    double fy = (double)(height - 1 - y);
    uint8_t *pixels = image_row(job->img, y);
    for (size_t x = 0; x < width; x++) {
        double fx = (double)x;
        Color c = COLOR_BLACK;
        for (unsigned i = 0; i < job->samples; i++) {
            double u = (fx + rng_next(&rng)) / fw;
            double v = (fy + rng_next(&rng)) / fh;
            Ray r = camera_get_ray(job->camera, u, v, &rng);
            c = color_add(c, ray_color(job->world, r, &rng));
        }
        image_set_pixel(&pixels[x * 3], color_div(c, (double)job->samples));
    }
}

static void *work(void *arg) {
    Job *job = arg;
    for (;;) {
        size_t y = atomic_fetch_add_explicit(&job->next_row, 1, memory_order_relaxed);
        if (y >= job->img->height) {
            return NULL;
        }
        render_row(job, y);
    }
}

bool render_with_threads(Image *img, size_t threads, size_t width, size_t height, unsigned samples,
                         const Camera *camera, const World *world) {
    assert(threads > 0);
    if (!image_init(img, width, height)) {
        return false;
    }
    if (width == 0 || height == 0) {
        return true;
    }

    Job job = {.img = img, .samples = samples, .camera = camera, .world = world};
    atomic_init(&job.next_row, 0);
    pthread_t *handles = malloc((threads - 1) * sizeof *handles);
    size_t spawned = 0;
    /* Threads that can't be created (or the array for them) are simply done
     * without: this thread and any others still render every row. */
    for (; handles != NULL && spawned < threads - 1; spawned++) {
        if (pthread_create(&handles[spawned], NULL, work, &job) != 0) {
            break;
        }
    }
    work(&job);
    for (size_t i = 0; i < spawned; i++) {
        pthread_join(handles[i], NULL);
    }
    free(handles);
    return true;
}
