// The ray tracer's C++ types. jank can't yet define types of its own, so they
// are declared here, and all of the code that works with them is jank.
#pragma once

#include <cmath>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

// Not `raytracer`: jank compiles the namespace raytracer.rng to the C++
// namespace raytracer::rng, for example.
namespace rt
{
  // Also used for colours, as r, g and b.
  struct vec3
  {
    double x, y, z;
  };

  struct ray
  {
    vec3 origin, direction;
  };

  // SplitMix64's state.
  struct rng
  {
    std::uint64_t state;
  };

  enum class surface
  {
    lambertian,
    metal,
    dielectric
  };

  struct material
  {
    rt::surface surface;
    // The colour that scattered light is multiplied by.
    vec3 albedo;
    // Metal only: 0 is a perfect mirror.
    double fuzz;
    // Dielectric only.
    double ref_index;
  };

  struct sphere
  {
    vec3 center;
    double radius;
    rt::material material;
  };

  struct hit
  {
    double t;
    vec3 point, normal;
    rt::material const *material;
  };

  struct camera
  {
    vec3 origin, lower_left, horizontal, vertical, u, v;
    double lens_radius;
  };

  struct world
  {
    std::vector<sphere> spheres;
  };

  // 8-bit RGB. Row 0 is the top.
  struct image
  {
    std::int64_t width, height;
    std::string pixels;
  };

  using maybe_vec3 = std::optional<vec3>;
  using maybe_ray = std::optional<ray>;
  using maybe_hit = std::optional<hit>;
}
