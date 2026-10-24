#include "image.h"

#include <assert.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>

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

static bool save(const Image *img, const char *path, bool (*write)(const Image *, FILE *)) {
    FILE *f = fopen(path, "wb");
    if (f == NULL) {
        return false;
    }
    bool ok = write(img, f);
    int saved = errno;
    if (fclose(f) != 0) {
        return false;
    }
    errno = saved;
    return ok;
}

bool image_save_ppm(const Image *img, const char *path) { return save(img, path, image_write_ppm); }

static uint32_t crc32_update(uint32_t crc, const uint8_t *bytes, size_t len) {
    crc = ~crc;
    for (size_t i = 0; i < len; i++) {
        crc ^= bytes[i];
        for (int k = 0; k < 8; k++) {
            crc = crc & 1 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
        }
    }
    return ~crc;
}

static uint32_t adler32(const uint8_t *bytes, size_t len) {
    uint32_t a = 1, b = 0;
    for (size_t i = 0; i < len; i++) {
        a = (a + bytes[i]) % 65521;
        b = (b + a) % 65521;
    }
    return b << 16 | a;
}

static void put_u32_be(uint8_t *p, uint32_t n) {
    p[0] = (uint8_t)(n >> 24);
    p[1] = (uint8_t)(n >> 16);
    p[2] = (uint8_t)(n >> 8);
    p[3] = (uint8_t)n;
}

static bool write_chunk(FILE *f, const char kind[4], const uint8_t *data, size_t len) {
    uint8_t buf[4];
    put_u32_be(buf, (uint32_t)len);
    if (fwrite(buf, 1, 4, f) != 4 || fwrite(kind, 1, 4, f) != 4 ||
        (len > 0 && fwrite(data, 1, len, f) != len)) {
        return false;
    }
    put_u32_be(buf, crc32_update(crc32_update(0, (const uint8_t *)kind, 4), data, len));
    return fwrite(buf, 1, 4, f) == 4;
}

/* Stored deflate blocks can hold at most 65535 bytes each. */
#define STORED_MAX 65535

/* A zlib stream holding `data` in uncompressed (stored) deflate blocks. The C
 * library has no compressor, and this keeps the encoder small at the cost of
 * file size. Returns NULL if it can't be allocated. */
static uint8_t *zlib_stored(const uint8_t *data, size_t len, size_t *out_len) {
    size_t blocks = len == 0 ? 1 : (len + STORED_MAX - 1) / STORED_MAX;
    *out_len = 2 + blocks * 5 + len + 4;
    uint8_t *out = malloc(*out_len);
    if (out == NULL) {
        return NULL;
    }
    uint8_t *p = out;
    *p++ = 0x78;
    *p++ = 0x01;
    for (size_t pos = 0, i = 0; i < blocks; i++) {
        size_t n = len - pos < STORED_MAX ? len - pos : STORED_MAX;
        *p++ = i == blocks - 1;
        *p++ = (uint8_t)n;
        *p++ = (uint8_t)(n >> 8);
        *p++ = (uint8_t)~n;
        *p++ = (uint8_t)(~n >> 8);
        memcpy(p, data + pos, n);
        p += n;
        pos += n;
    }
    put_u32_be(p, adler32(data, len));
    return out;
}

/* PNG chunks hold at most 2^31 - 1 bytes. */
#define CHUNK_MAX 0x7FFFFFFF

bool image_write_png(const Image *img, FILE *f) {
    size_t row_bytes = img->width * 3;
    if (img->height > 0 && row_bytes + 1 > CHUNK_MAX / img->height) {
        errno = EOVERFLOW;
        return false;
    }
    uint8_t header[13];
    put_u32_be(header, (uint32_t)img->width);
    put_u32_be(header + 4, (uint32_t)img->height);
    /* 8 bits per channel, RGB, deflate, no filtering, no interlacing. */
    memcpy(header + 8, (uint8_t[]){8, 2, 0, 0, 0}, 5);

    /* Each scanline starts with its filter type, 0 for none. */
    size_t raw_len = (row_bytes + 1) * img->height;
    uint8_t *raw = malloc(raw_len == 0 ? 1 : raw_len);
    if (raw == NULL) {
        return false;
    }
    for (size_t y = 0; y < img->height; y++) {
        raw[y * (row_bytes + 1)] = 0;
        memcpy(&raw[y * (row_bytes + 1) + 1], &img->pixels[y * row_bytes], row_bytes);
    }
    size_t data_len;
    uint8_t *data = zlib_stored(raw, raw_len, &data_len);
    free(raw);
    if (data == NULL) {
        return false;
    }
    bool ok = false;
    if (data_len > CHUNK_MAX) {
        errno = EOVERFLOW;
    } else {
        ok = fwrite("\x89PNG\r\n\x1a\n", 1, 8, f) == 8 && write_chunk(f, "IHDR", header, 13) &&
             write_chunk(f, "IDAT", data, data_len) && write_chunk(f, "IEND", NULL, 0);
    }
    free(data);
    return ok;
}

bool image_save_png(const Image *img, const char *path) { return save(img, path, image_write_png); }

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
