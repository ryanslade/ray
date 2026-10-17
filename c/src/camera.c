#include "camera.h"

#include <math.h>

/* M_PI isn't part of standard C. */
static const double pi = 3.14159265358979323846;

Camera camera_new(CameraSettings s) {
    double theta = s.vfov * (pi / 180.0);
    double half_height = tan(theta / 2);
    double half_width = s.aspect * half_height;
    Vec3 w = vec3_unit(vec3_sub(s.look_from, s.look_at));
    Vec3 u = vec3_unit(vec3_cross(s.v_up, w));
    Vec3 v = vec3_cross(w, u);
    Vec3 lower_left =
        vec3_sub(vec3_sub(vec3_sub(s.look_from, vec3_scale(u, half_width * s.focus_dist)),
                          vec3_scale(v, half_height * s.focus_dist)),
                 vec3_scale(w, s.focus_dist));
    return (Camera){
        .origin = s.look_from,
        .lower_left = lower_left,
        .horizontal = vec3_scale(u, 2 * half_width * s.focus_dist),
        .vertical = vec3_scale(v, 2 * half_height * s.focus_dist),
        .u = u,
        .v = v,
        .lens_radius = s.aperture / 2,
    };
}

Ray camera_get_ray(const Camera *c, double s, double t, Rng *rng) {
    Vec3 rd = vec3_scale(vec3_random_in_unit_disk(rng), c->lens_radius);
    Vec3 offset = vec3_add(vec3_scale(c->u, rd.x), vec3_scale(c->v, rd.y));
    Vec3 direction = vec3_add(c->lower_left, vec3_scale(c->horizontal, s));
    direction = vec3_add(direction, vec3_scale(c->vertical, t));
    direction = vec3_sub(vec3_sub(direction, c->origin), offset);
    return ray_new(vec3_add(c->origin, offset), direction);
}
