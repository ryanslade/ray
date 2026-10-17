#ifndef RAYTRACER_RENDER_H
#define RAYTRACER_RENDER_H

#include <stdbool.h>
#include <stddef.h>

#include "camera.h"
#include "color.h"
#include "image.h"
#include "ray.h"
#include "rng.h"
#include "world.h"

/* The colour seen along a ray, following up to 50 bounces. */
Color ray_color(const World *world, Ray r, Rng *rng);

/* The number of threads `render` uses: one per online CPU. */
size_t default_threads(void);

/* Renders the world into `img` with `samples` rays per pixel, in parallel
 * across all available cores. The caller frees the image with `image_free`.
 * Returns false and sets errno if the image can't be allocated. */
bool render(Image *img, size_t width, size_t height, unsigned samples, const Camera *camera,
            const World *world);

/* Like `render`, but on `threads` threads.
 *
 * Each row uses its own random state seeded from the row index, so the image
 * is identical regardless of the number of threads. */
bool render_with_threads(Image *img, size_t threads, size_t width, size_t height, unsigned samples,
                         const Camera *camera, const World *world);

#endif
