(ns raytracer.render
  (:require [raytracer.camera :as camera]
            [raytracer.hit :as hit]
            [raytracer.image :as image]
            [raytracer.material :as material]
            [raytracer.ray :as ray]
            [raytracer.rng :as rng]
            [raytracer.vec3 :as v]
            [raytracer.world :as world])
  (:import (java.util.concurrent.atomic AtomicLong)
           (raytracer.image Image)
           (raytracer.ray Ray)
           (raytracer.rng Rng)
           (raytracer.vec3 Vec3)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(def ^:private ^:const max-depth 50)
(def ^:private sky-blue (v/vec3 0.5 0.7 1.0))

(defn- sky ^Vec3 [^Ray r]
  (let [t (* 0.5 (+ (v/y (v/unit (ray/direction r))) 1.0))]
    (v/add (v/scale (- 1.0 t) v/white) (v/scale t sky-blue))))

(defn ray-color
  "The colour seen along a ray, following up to 50 bounces."
  ^Vec3 [world ^Ray r ^Rng rng]
  ;; `attenuation` is the product of the attenuations of every surface hit so
  ;; far.
  (loop [r r
         attenuation v/white
         depth 0]
    (if-let [h (world/hit world r 0.001 Double/MAX_VALUE)]
      (let [m (hit/material h)
            scattered (when (< depth max-depth) (material/scatter m r h rng))]
        (if scattered
          (recur scattered (v/mul attenuation (material/attenuation m)) (inc depth))
          v/black))
      (v/mul attenuation (sky r)))))

(defn- render-row [^bytes pixels y width height samples camera world]
  ;; Functions of more than four arguments can't take primitives.
  (let [y (long y)
        width (long width)
        height (long height)
        samples (long samples)
        ^Rng rng (rng/rng (inc y))]
    (dotimes [x width]
      (loop [s 0, r 0.0, g 0.0, b 0.0]
        (if (< s samples)
          (let [u (/ (+ (double x) (.nextF64 rng)) (double width))
                v (/ (+ (double (- height 1 y)) (.nextF64 rng)) (double height))
                c (ray-color world (camera/get-ray camera u v rng) rng)]
            (recur (inc s) (+ r (v/x c)) (+ g (v/y c)) (+ b (v/z c))))
          (image/write-color! pixels (* 3 (+ (* y width) x))
                              (v/div (v/vec3 r g b) (double samples))))))))

(defn render-with-threads
  "Renders the world with `samples` rays per pixel on `threads` threads.

  Each row uses its own random state seeded from the row index, so the image
  is identical regardless of the number of threads."
  ^Image [threads width height samples camera world]
  (let [threads (long threads)
        height (long height)
        _ (when-not (pos? threads)
            (throw (IllegalArgumentException. "threads must be positive")))
        ^Image img (image/image width height)
        pixels (.-pixels img)
        next-row (AtomicLong.)
        ;; Rows vary a lot in cost (sky is cheap, spheres are expensive), so
        ;; threads take rows one at a time rather than a fixed block each.
        worker (fn []
                 (loop []
                   (let [y (.getAndIncrement next-row)]
                     (when (< y height)
                       (render-row pixels y width height samples camera world)
                       (recur)))))
        others (doall (repeatedly (dec threads) #(future (worker))))]
    (worker)
    ;; Waits for the other threads, rethrowing anything they threw.
    (run! deref others)
    img))

(defn render
  "Renders the world with `samples` rays per pixel, in parallel across all
  available cores."
  ^Image [width height samples camera world]
  (render-with-threads (.availableProcessors (Runtime/getRuntime))
                       width height samples camera world))
