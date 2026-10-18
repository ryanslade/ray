(ns raytracer.main
  (:require [raytracer.camera :as camera]
            [raytracer.image :as image]
            [raytracer.material :as material]
            [raytracer.render :as render]
            [raytracer.rng :as rng]
            [raytracer.sphere :as sphere]
            [raytracer.vec3 :as v]
            [raytracer.world :as world])
  (:import (raytracer.rng Rng))
  (:gen-class))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(def ^:private width 800)
(def ^:private height 450)
(def ^:private samples 100)

(defn- small-sphere
  "A small sphere in the grid square at (`a`, `b`), or nil if it would be too
  close to the metal sphere."
  [^Rng rng ^double a ^double b]
  (let [x (+ a (* 0.9 (.nextF64 rng)))
        z (+ b (* 0.9 (.nextF64 rng)))
        center (v/vec3 x 0.2 z)]
    (when (> (v/length (v/sub center (v/vec3 4.0 0.2 0.0))) 0.9)
      (let [channel #(* (.nextF64 rng) (.nextF64 rng))
            ;; Bound in order, since the channels draw from the same generator.
            r (channel)
            g (channel)
            b (channel)]
        (sphere/sphere center 0.2 (material/lambertian (v/vec3 r g b)))))))

(defn- random-world [^Rng rng]
  (world/world
   (concat
    [(sphere/sphere (v/vec3 0.0 -1000.0 -1.0) 1000.0
                    (material/lambertian (v/vec3 0.5 0.5 0.5)))]
    ;; doall, so all the random numbers are drawn here and in order.
    (doall (for [a (range -11 11), b (range -11 11)
                 :let [s (small-sphere rng a b)]
                 :when s]
             s))
    [(sphere/sphere (v/vec3 4.0 1.0 0.0) 1.0
                    (material/metal (v/vec3 0.8 0.6 0.2) 0.1))
     (sphere/sphere (v/vec3 0.0 1.0 0.0) 1.0 (material/dielectric 1.5))
     (sphere/sphere (v/vec3 -4.0 1.0 0.0) 1.0
                    (material/metal (v/vec3 0.8 0.8 0.8) 0.2))])))

(defn -main [& args]
  (let [output (or (first args) "out.ppm")
        _ (binding [*out* *err*] (println "Generating world"))
        world (random-world (rng/rng 1))
        look-from (v/vec3 3.0 2.0 3.0)
        look-at (v/vec3 0.0 0.0 -1.0)
        cam (camera/camera {:look-from look-from
                            :look-at look-at
                            :v-up (v/vec3 0.0 1.0 0.0)
                            :vfov 90.0
                            :aspect (/ (double width) (double height))
                            :aperture 0.01
                            :focus-dist (v/length (v/sub look-from look-at))})
        threads (.availableProcessors (Runtime/getRuntime))]
    (binding [*out* *err*] (println "Rendering on" threads "threads"))
    (let [img (render/render width height samples cam world)]
      (try
        (image/save-ppm img output)
        (binding [*out* *err*] (println "Wrote" output))
        (catch java.io.IOException e
          (binding [*out* *err*] (println (str "Writing " output ": " (.getMessage e))))
          (shutdown-agents)
          (System/exit 1))))
    ;; The render's futures run on the agent thread pool, which would
    ;; otherwise keep the JVM alive for another minute.
    (shutdown-agents)))
