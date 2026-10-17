/* The scene used by the tests and benchmark, matching the other versions. */

#ifndef RAYTRACER_TEST_SCENE_H
#define RAYTRACER_TEST_SCENE_H

#include <stddef.h>

#include "raytracer.h"

World scene_world(void);

Camera scene_camera(size_t width, size_t height);

#endif
