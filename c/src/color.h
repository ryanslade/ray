#ifndef RAYTRACER_COLOR_H
#define RAYTRACER_COLOR_H

typedef struct {
    double r, g, b;
} Color;

static inline Color color(double r, double g, double b) { return (Color){.r = r, .g = g, .b = b}; }

#define COLOR_BLACK ((Color){.r = 0, .g = 0, .b = 0})
#define COLOR_WHITE ((Color){.r = 1, .g = 1, .b = 1})

static inline Color color_add(Color a, Color o) { return color(a.r + o.r, a.g + o.g, a.b + o.b); }

/* Component-wise multiplication. */
static inline Color color_mul(Color a, Color o) { return color(a.r * o.r, a.g * o.g, a.b * o.b); }

static inline Color color_scale(Color c, double s) { return color(s * c.r, s * c.g, s * c.b); }

static inline Color color_div(Color c, double s) { return color(c.r / s, c.g / s, c.b / s); }

#endif
