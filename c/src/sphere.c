#include "sphere.h"

Hit sphere_hit_at(const Sphere *s, Ray r, double t) {
    Vec3 point = ray_at(r, t);
    return (Hit){
        .t = t,
        .point = point,
        .normal = vec3_div(vec3_sub(point, s->center), s->radius),
        .material = &s->material,
    };
}

bool sphere_hit(const Sphere *s, Ray r, double t_min, double t_max, Hit *hit) {
    double t;
    if (!sphere_intersect(s, r, t_min, t_max, &t)) {
        return false;
    }
    *hit = sphere_hit_at(s, r, t);
    return true;
}
