#ifndef RAYTRACER_HIT_H
#define RAYTRACER_HIT_H

#include "material.h"
#include "vec3.h"

typedef struct Hit {
    double t;
    Vec3 point;
    Vec3 normal;
    const Material *material;
} Hit;

#endif
