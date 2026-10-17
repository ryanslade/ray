#ifndef RAYTRACER_CAMERA_H
#define RAYTRACER_CAMERA_H

#include "ray.h"
#include "rng.h"
#include "vec3.h"

/* Settings for `camera_new`. */
typedef struct {
    Vec3 look_from;
    Vec3 look_at;
    Vec3 v_up;
    /* Vertical field of view in degrees. */
    double vfov;
    double aspect;
    double aperture;
    double focus_dist;
} CameraSettings;

typedef struct {
    Vec3 origin;
    Vec3 lower_left;
    Vec3 horizontal;
    Vec3 vertical;
    Vec3 u, v;
    double lens_radius;
} Camera;

Camera camera_new(CameraSettings s);

/* A ray through the viewport at normalised coordinates `(s, t)`, with its
 * origin jittered across the lens. */
Ray camera_get_ray(const Camera *c, double s, double t, Rng *rng);

#endif
