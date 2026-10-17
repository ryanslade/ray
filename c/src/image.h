#ifndef RAYTRACER_IMAGE_H
#define RAYTRACER_IMAGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "color.h"

/* An 8-bit RGB image. Row 0 is the top. */
typedef struct {
    size_t width;
    size_t height;
    uint8_t *pixels;
} Image;

/* Allocates a black image. Returns false if it is too large to allocate. */
bool image_init(Image *img, size_t width, size_t height);

void image_free(Image *img);

/* Stores a colour, clamping each channel to [0, 1]. */
void image_set(Image *img, size_t x, size_t y, Color c);

/* The RGB bytes of the pixel at (x, y). */
const uint8_t *image_get(const Image *img, size_t x, size_t y);

/* The RGB bytes of row `y`. */
uint8_t *image_row(Image *img, size_t y);

/* Writes the image in binary (P6) PPM format. Returns false on a write
 * error. */
bool image_write_ppm(const Image *img, FILE *f);

/* Writes the image to `path`. Returns false and sets errno on failure. */
bool image_save_ppm(const Image *img, const char *path);

/* Writes a colour to an RGB pixel, clamping each channel to [0, 1]. */
void image_set_pixel(uint8_t px[3], Color c);

#endif
