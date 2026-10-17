# Renders the example scene. Usage: janet main.janet [output.ppm]

(import ./raytracer/camera)
(import ./raytracer/image)
(import ./raytracer/material)
(import ./raytracer/render)
(import ./raytracer/sphere)
(import ./raytracer/vec3)
(import ./raytracer/world)

(def width 800)
(def height 450)
(def samples 100)

(defn random-world [rng]
  (defn rand [] (math/rng-uniform rng))
  (def ground (sphere/new [0 -1000 -1] 1000 (material/lambertian [0.5 0.5 0.5])))
  (def small-spheres
    (seq [a :range [-11 11]
          b :range [-11 11]
          :let [x (+ a (* 0.9 (rand)))
                z (+ b (* 0.9 (rand)))
                center [x 0.2 z]]
          :when (> (vec3/length (vec3/sub center [4 0.2 0])) 0.9)
          :let [albedo (seq [_ :range [0 3]] (* (rand) (rand)))]]
      (sphere/new center 0.2 (material/lambertian (tuple ;albedo)))))
  (def large-spheres
    [(sphere/new [4 1 0] 1 (material/metal [0.8 0.6 0.2] 0.1))
     (sphere/new [0 1 0] 1 (material/dielectric 1.5))
     (sphere/new [-4 1 0] 1 (material/metal [0.8 0.8 0.8] 0.2))])
  (world/new [ground ;small-spheres ;large-spheres]))

(defn main [_ &opt output]
  (default output "out.ppm")
  (eprint "Generating world")
  (def w (random-world (math/rng 1)))
  (def look-from [3 2 3])
  (def look-at [0 0 -1])
  (def cam (camera/new
             :look-from look-from
             :look-at look-at
             :v-up [0 1 0]
             :vfov 90
             :aspect (/ width height)
             :aperture 0.01
             :focus-dist (vec3/length (vec3/sub look-from look-at))))
  (eprintf "Rendering on %d threads" (render/cpu-count))
  (def img (render/render width height samples cam w))
  (image/save-ppm img output)
  (eprint "Wrote " output))
