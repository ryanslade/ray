#include "image.h"

#include <assert.h>
#include <errno.h>
#include <stdlib.h>

bool image_init(Image *img, size_t width, size_t height) {
    *img = (Image){.width = width, .height = height};
    if (width == 0 || height == 0) {
        return true;
    }
    if (width > SIZE_MAX / 3 / height) {
        errno = ENOMEM;
        return false;
    }
    img->pixels = calloc(width * height * 3, 1);
    return img->pixels != NULL;
}

void image_free(Image *img) {
    free(img->pixels);
    img->pixels = NULL;
}

static size_t pixel_index(const Image *img, size_t x, size_t y) {
    assert(x < img->width && y < img->height);
    return (y * img->width + x) * 3;
}

void image_set(Image *img, size_t x, size_t y, Color c) {
    image_set_pixel(&img->pixels[pixel_index(img, x, y)], c);
}

const uint8_t *image_get(const Image *img, size_t x, size_t y) {
    return &img->pixels[pixel_index(img, x, y)];
}

uint8_t *image_row(Image *img, size_t y) { return &img->pixels[pixel_index(img, 0, y)]; }

bool image_write_ppm(const Image *img, FILE *f) {
    size_t len = img->width * img->height * 3;
    if (fprintf(f, "P6\n%zu %zu\n255\n", img->width, img->height) < 0) {
        return false;
    }
    return len == 0 || fwrite(img->pixels, 1, len, f) == len;
}

bool image_save_ppm(const Image *img, const char *path) {
    FILE *f = fopen(path, "wb");
    if (f == NULL) {
        return false;
    }
    bool ok = image_write_ppm(img, f);
    int saved = errno;
    if (fclose(f) != 0) {
        return false;
    }
    errno = saved;
    return ok;
}

static uint8_t to_byte(double v) {
    /* Written so that NaN becomes 0, like a saturating cast in Rust. */
    if (!(v > 0)) {
        return 0;
    }
    return (uint8_t)(255.99 * (v < 1 ? v : 1));
}

void image_set_pixel(uint8_t px[3], Color c) {
    px[0] = to_byte(c.r);
    px[1] = to_byte(c.g);
    px[2] = to_byte(c.b);
}
