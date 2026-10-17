# The scene used by the tests and benchmark, matching the Go, OCaml and Rust
# versions.

(import ../raytracer/camera)
(import ../raytracer/material)
(import ../raytracer/sphere)
(import ../raytracer/vec3)
(import ../raytracer/world)

(defn world []
  (world/new
    [(sphere/new [0 -100.5 -1] 100 (material/lambertian [0.5 0.5 0.5]))
     (sphere/new [0 0 -1] 1 (material/metal [0.8 0.8 0.8] 0.2))
     (sphere/new [1.5 0 -1] 1 (material/dielectric 1.5))]))

(defn camera [width height]
  (def look-from [1 1 1])
  (def look-at [0 0 -1])
  (camera/new
    :look-from look-from
    :look-at look-at
    :v-up [0 1 0]
    :vfov 90
    :aspect (/ width height)
    :aperture 0.01
    :focus-dist (vec3/length (vec3/sub look-from look-at))))
