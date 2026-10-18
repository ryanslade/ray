#include "scene.h"

World scene_world(void) {
    static Sphere spheres[3];
    static SphereBlock blocks[WORLD_BLOCKS(3)];
    spheres[0] = sphere(vec3(0, -100.5, -1), 100, material_lambertian(color(0.5, 0.5, 0.5)));
    spheres[1] = sphere(vec3(0, 0, -1), 1, material_metal(color(0.8, 0.8, 0.8), 0.2));
    spheres[2] = sphere(vec3(1.5, 0, -1), 1, material_dielectric(1.5));
    return world_new(spheres, 3, blocks);
}

Camera scene_camera(size_t width, size_t height) {
    Vec3 look_from = vec3(1, 1, 1);
    Vec3 look_at = vec3(0, 0, -1);
    return camera_new((CameraSettings){
        .look_from = look_from,
        .look_at = look_at,
        .v_up = vec3(0, 1, 0),
        .vfov = 90,
        .aspect = (double)width / (double)height,
        .aperture = 0.01,
        .focus_dist = vec3_length(vec3_sub(look_from, look_at)),
    });
}
