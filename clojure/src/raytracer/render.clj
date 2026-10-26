(ns raytracer.render
  (:require [raytracer.camera :as camera]
            [raytracer.image :as image]
            [raytracer.material :as material]
            [raytracer.rng :as rng]
            [raytracer.vec3 :as v]
            [raytracer.world :as world])
  (:import (java.util.concurrent.atomic AtomicLong)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(def ^:private ^:const max-depth 50)
(def ^:private sky-blue (v/vec3 0.5 0.7 1.0))

(defn- sky [r]
  (let [t (* 0.5 (+ (v/y (v/unit (:direction r))) 1.0))]
    (v/add (v/scale (- 1.0 t) v/white) (v/scale t sky-blue))))

(defn ray-color
  "The colour seen along a ray, following up to 50 bounces."
  [world r rng]
  ;; `attenuation` is the product of the attenuations of every surface hit so
  ;; far.
  (loop [r r, attenuation v/white, depth 0]
    (if-let [h (world/hit world r 0.001 Double/MAX_VALUE)]
      (let [m (:material h)]
        (if-let [scattered (when (< depth max-depth) (material/scatter m r h rng))]
          (recur scattered (v/mul attenuation (material/attenuation m)) (inc depth))
          v/black))
      (v/mul attenuation (sky r)))))

(defn- render-row [img y width height samples camera world]
  ;; Functions of more than four arguments can't take primitives.
  (let [y (long y), width (long width), height (long height), samples (long samples)
        rng (rng/rng (inc y))]
    (dotimes [x width]
      (loop [s 0, r 0.0, g 0.0, b 0.0]
        (if (< s samples)
          (let [u (/ (+ (double x) (rng/next-f64 rng)) (double width))
                v (/ (+ (double (- height 1 y)) (rng/next-f64 rng)) (double height))
                c (ray-color world (camera/get-ray camera u v rng) rng)]
            (recur (inc s) (+ r (v/x c)) (+ g (v/y c)) (+ b (v/z c))))
          (image/set-pixel! img x y (v/div (v/vec3 r g b) (double samples))))))))

(defn render-with-threads
  "Renders the world with `samples` rays per pixel on `threads` threads.

  Each row uses its own random state seeded from the row index, so the image
  is identical regardless of the number of threads."
  [threads width height samples camera world]
  {:pre [(pos? (long threads))]}
  (let [img (image/image width height)
        next-row (AtomicLong.)
        ;; Rows vary a lot in cost (sky is cheap, spheres are expensive), so
        ;; threads take rows one at a time rather than a fixed block each.
        worker #(loop [y (.getAndIncrement next-row)]
                  (when (< y (long height))
                    (render-row img y width height samples camera world)
                    (recur (.getAndIncrement next-row))))
        others (doall (repeatedly (dec (long threads)) #(future (worker))))]
    (worker)
    ;; Waits for the other threads, rethrowing anything they threw.
    (run! deref others)
    img))

(defn render
  "Renders the world with `samples` rays per pixel, in parallel across all
  available cores."
  [width height samples camera world]
  (render-with-threads (.availableProcessors (Runtime/getRuntime))
                       width height samples camera world))
