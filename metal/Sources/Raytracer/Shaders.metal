// The GPU half of the ray tracer. Each thread traces one pixel: a pass of
// samples whose colours are added to that pixel's running total.
//
// The structs shared with the host are mirrored in GPUTypes.swift.

#include <metal_stdlib>

using namespace metal;

constant uint max_depth = 50;

struct Sphere {
    packed_float3 center;
    float radius;
};

enum MaterialKind : uint {
    lambertian = 0,
    metallic = 1,
    dielectric = 2,
};

struct Material {
    float3 albedo;
    // The fuzz of a metal, or the refractive index of a dielectric.
    float param;
    MaterialKind kind;
};

struct Camera {
    float3 origin;
    float3 lower_left;
    float3 horizontal;
    float3 vertical;
    float3 u;
    float3 v;
    float lens_radius;
};

struct Params {
    uint width;
    uint height;
    uint sphere_count;
    // The number of samples in this pass.
    uint samples;
};

struct Ray {
    float3 origin;
    float3 direction;
};

// SplitMix64, the same generator as the CPU versions. Apple GPUs emulate
// 64-bit multiplies, but it is cheap next to the intersection tests.
inline ulong next_u64(thread ulong &state) {
    state += 0x9e3779b97f4a7c15ul;
    ulong z = state;
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ul;
    z = (z ^ (z >> 27)) * 0x94d049bb133111ebul;
    return z ^ (z >> 31);
}

// A uniformly distributed float in [0, 1). The top 24 bits fill a float's
// mantissa exactly.
inline float next_float(thread ulong &state) {
    return float(next_u64(state) >> 40) * (1.0f / 16777216.0f);
}

// Rejection sampling: pick points in the enclosing cube until one lands
// inside.
inline float3 random_in_unit_sphere(thread ulong &rng) {
    for (;;) {
        float x = 2 * next_float(rng) - 1;
        float y = 2 * next_float(rng) - 1;
        float z = 2 * next_float(rng) - 1;
        float3 p = float3(x, y, z);
        if (length_squared(p) < 1) {
            return p;
        }
    }
}

inline float3 random_in_unit_disk(thread ulong &rng) {
    for (;;) {
        float x = 2 * next_float(rng) - 1;
        float y = 2 * next_float(rng) - 1;
        float3 p = float3(x, y, 0);
        if (length_squared(p) < 1) {
            return p;
        }
    }
}

// Stores in `t` the nearest point in (`t_min`, `t_max`) at which the ray
// meets the sphere, or returns false if there is none.
inline bool sphere_intersect(Sphere s, Ray r, float t_min, float t_max, thread float &t) {
    float3 oc = r.origin - float3(s.center);
    float a = dot(r.direction, r.direction);
    float b = dot(oc, r.direction);
    float c = dot(oc, oc) - s.radius * s.radius;
    float discriminant = b * b - a * c;
    if (discriminant < 0) {
        return false;
    }
    float sqrt_d = sqrt(discriminant);
    float near = (-b - sqrt_d) / a;
    if (near < t_max && near > t_min) {
        t = near;
        return true;
    }
    float far = (-b + sqrt_d) / a;
    if (far < t_max && far > t_min) {
        t = far;
        return true;
    }
    return false;
}

// Stores the index of and distance to the closest sphere the ray hits, or
// returns false if it misses everything. Only the closest sphere's hit point
// and normal are ever needed, so the caller works those out.
inline bool world_hit(constant Sphere *spheres, uint count, Ray r, float t_min, float t_max,
                      thread uint &index, thread float &t) {
    bool hit = false;
    t = t_max;
    for (uint i = 0; i < count; i++) {
        float ti;
        if (sphere_intersect(spheres[i], r, t_min, t, ti)) {
            hit = true;
            index = i;
            t = ti;
        }
    }
    return hit;
}

// Returns false on total internal reflection. Unlike Metal's refract, `v`
// needn't be a unit vector.
inline bool try_refract(float3 v, float3 n, float ni_over_nt, thread float3 &out) {
    float3 uv = normalize(v);
    float dt = dot(uv, n);
    float discriminant = 1 - ni_over_nt * ni_over_nt * (1 - dt * dt);
    if (discriminant > 0) {
        out = (uv - n * dt) * ni_over_nt - n * sqrt(discriminant);
        return true;
    }
    return false;
}

// Schlick's approximation for reflectance at a given angle.
inline float schlick(float cosine, float ref_index) {
    float r0 = (1 - ref_index) / (1 + ref_index);
    r0 = r0 * r0;
    float x = 1 - cosine;
    float x2 = x * x;
    return r0 + (1 - r0) * x2 * x2 * x;
}

// Sets the attenuation and scattered ray, or returns false if the ray is
// absorbed.
inline bool scatter(Material m, Ray in, float3 point, float3 normal, thread ulong &rng,
                    thread float3 &attenuation, thread Ray &scattered) {
    switch (m.kind) {
    case lambertian: {
        float3 target = point + normal + random_in_unit_sphere(rng);
        attenuation = m.albedo;
        scattered = Ray{point, target - point};
        return true;
    }
    case metallic: {
        float3 reflected = reflect(normalize(in.direction), normal);
        float3 direction = reflected + random_in_unit_sphere(rng) * m.param;
        attenuation = m.albedo;
        scattered = Ray{point, direction};
        return dot(direction, normal) > 0;
    }
    case dielectric: {
        float ref_index = m.param;
        float3 d = in.direction;
        float d_dot_n = dot(d, normal);
        float3 outward_normal;
        float ni_over_nt, cosine;
        if (d_dot_n > 0) {
            outward_normal = -normal;
            ni_over_nt = ref_index;
            cosine = ref_index * d_dot_n / length(d);
        } else {
            outward_normal = normal;
            ni_over_nt = 1 / ref_index;
            cosine = -d_dot_n / length(d);
        }
        float3 refracted;
        bool refracts = try_refract(d, outward_normal, ni_over_nt, refracted) &&
                        next_float(rng) >= schlick(cosine, ref_index);
        attenuation = float3(1);
        scattered = Ray{point, refracts ? refracted : reflect(d, normal)};
        return true;
    }
    }
    return false;
}

// The colour seen along a ray, following up to `max_depth` bounces.
inline float3 ray_color(constant Sphere *spheres, constant Material *materials, uint count, Ray r,
                        thread ulong &rng) {
    // The product of the attenuations of every surface hit so far.
    float3 attenuation = float3(1);
    for (uint depth = 0; depth <= max_depth; depth++) {
        uint i;
        float t;
        if (!world_hit(spheres, count, r, 0.001f, FLT_MAX, i, t)) {
            float sky_t = 0.5f * (normalize(r.direction).y + 1);
            return attenuation * ((1 - sky_t) * float3(1) + sky_t * float3(0.5f, 0.7f, 1));
        }
        if (depth == max_depth) {
            break;
        }
        float3 point = r.origin + r.direction * t;
        float3 normal = (point - float3(spheres[i].center)) / spheres[i].radius;
        float3 a;
        if (!scatter(materials[i], r, point, normal, rng, a, r)) {
            break;
        }
        attenuation *= a;
    }
    return float3(0);
}

// A ray through the viewport at normalised coordinates `(s, t)`, with its
// origin jittered across the lens.
inline Ray get_ray(constant Camera &c, float s, float t, thread ulong &rng) {
    float3 rd = random_in_unit_disk(rng) * c.lens_radius;
    float3 offset = c.u * rd.x + c.v * rd.y;
    float3 direction = c.lower_left + c.horizontal * s + c.vertical * t - c.origin - offset;
    return Ray{c.origin + offset, direction};
}

// Adds `params.samples` samples to each pixel's total in `accum`, carrying
// each pixel's random state over in `rng_states` so that the image doesn't
// depend on how the samples are split into passes.
kernel void render(constant Params &params [[buffer(0)]], constant Camera &camera [[buffer(1)]],
                   constant Sphere *spheres [[buffer(2)]],
                   constant Material *materials [[buffer(3)]], device float4 *accum [[buffer(4)]],
                   device ulong *rng_states [[buffer(5)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= params.width || gid.y >= params.height) {
        return;
    }
    uint i = gid.y * params.width + gid.x;
    ulong rng = rng_states[i];
    float3 total = accum[i].rgb;
    float fx = float(gid.x);
    // Row 0 is the top of the image.
    float fy = float(params.height - 1 - gid.y);
    float fw = float(params.width);
    float fh = float(params.height);
    for (uint s = 0; s < params.samples; s++) {
        float u = (fx + next_float(rng)) / fw;
        float v = (fy + next_float(rng)) / fh;
        Ray r = get_ray(camera, u, v, rng);
        total += ray_color(spheres, materials, params.sphere_count, r, rng);
    }
    accum[i] = float4(total, 0);
    rng_states[i] = rng;
}
