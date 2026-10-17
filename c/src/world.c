#include "world.h"

bool world_hit(const World *w, Ray r, double t_min, double t_max, Hit *hit) {
    /* Only the hit record for the closest sphere is ever needed, so just track
     * which one it is until the end, shrinking the range as nearer ones are
     * found. */
    const Sphere *closest = NULL;
    double t_closest = t_max;
    for (size_t i = 0; i < w->len; i++) {
        double t;
        if (sphere_intersect(&w->spheres[i], r, t_min, t_closest, &t)) {
            closest = &w->spheres[i];
            t_closest = t;
        }
    }
    if (closest == NULL) {
        return false;
    }
    *hit = sphere_hit_at(closest, r, t_closest);
    return true;
}
