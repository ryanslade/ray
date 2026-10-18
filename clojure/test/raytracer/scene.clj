(ns raytracer.scene
  "The scene used by the tests and benchmark, matching the other versions."
  (:require [raytracer.camera :as camera]
            [raytracer.material :as material]
            [raytracer.sphere :as sphere]
            [raytracer.vec3 :as v]
            [raytracer.world :as world]))

(defn world []
  (world/world
   [(sphere/sphere (v/vec3 0.0 -100.5 -1.0) 100.0
                   (material/lambertian (v/vec3 0.5 0.5 0.5)))
    (sphere/sphere (v/vec3 0.0 0.0 -1.0) 1.0
                   (material/metal (v/vec3 0.8 0.8 0.8) 0.2))
    (sphere/sphere (v/vec3 1.5 0.0 -1.0) 1.0 (material/dielectric 1.5))]))

(defn camera [width height]
  (let [look-from (v/vec3 1.0 1.0 1.0)
        look-at (v/vec3 0.0 0.0 -1.0)]
    (camera/camera {:look-from look-from
                    :look-at look-at
                    :v-up (v/vec3 0.0 1.0 0.0)
                    :vfov 90.0
                    :aspect (/ (double width) (double height))
                    :aperture 0.01
                    :focus-dist (v/length (v/sub look-from look-at))})))
