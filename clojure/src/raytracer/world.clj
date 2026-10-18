(ns raytracer.world
  (:require [raytracer.ray]
            [raytracer.sphere :as sphere])
  (:import (raytracer.ray Ray)
           (raytracer.sphere Sphere)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

;; An array rather than a vector, so that the closest-hit loop indexes it
;; directly without boxing the index or casting each sphere.
(deftype World [^Sphere/1 spheres])

(defn world ^World [spheres]
  (World. (into-array Sphere spheres)))

(defn spheres [^World w] (vec (.-spheres w)))

(defn hit
  "The closest hit in (`t-min`, `t-max`), shrinking `t-max` as nearer spheres
  are found, or nil."
  [^World w ^Ray r ^double t-min ^double t-max]
  ;; Only the hit record for the closest sphere is ever needed, so just track
  ;; which one it is until the end.
  (let [^Sphere/1 spheres (.-spheres w)
        n (alength spheres)]
    (loop [i 0
           closest -1
           t-max t-max]
      (if (< i n)
        (let [t (sphere/intersect (aget spheres i) r t-min t-max)]
          (if (Double/isNaN t)
            (recur (inc i) closest t-max)
            (recur (inc i) i t)))
        (when (>= closest 0)
          (sphere/hit-at (aget spheres closest) r t-max))))))
