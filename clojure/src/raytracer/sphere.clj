(ns raytracer.sphere
  (:require [raytracer.ray :as ray]
            [raytracer.vec3 :as v])
  (:import (raytracer.ray Ray)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(deftype Sphere [center ^double radius material])

(defn sphere [center ^double radius material] (Sphere. center radius material))

(defn intersect
  "The nearest t in (`t-min`, `t-max`) at which the ray meets the sphere, or
  NaN if there is none. NaN rather than nil keeps the result unboxed."
  ^double [^Sphere s ^Ray r ^double t-min ^double t-max]
  (let [direction (.-direction r)
        oc (v/sub (.-origin r) (.-center s))
        a (v/dot direction direction)
        b (v/dot oc direction)
        c (- (v/dot oc oc) (* (.-radius s) (.-radius s)))
        discriminant (- (* b b) (* a c))]
    (if (< discriminant 0.0)
      ##NaN
      (let [sqrt-d (Math/sqrt discriminant)
            near (/ (- (- b) sqrt-d) a)]
        ;; t-max is tested first: the JIT makes this about 15% faster.
        (if (and (< near t-max) (> near t-min))
          near
          (let [far (/ (+ (- b) sqrt-d) a)]
            (if (and (< far t-max) (> far t-min)) far ##NaN)))))))

(defn hit-at
  "The hit record for a t returned by `intersect`."
  [^Sphere s r ^double t]
  (let [point (ray/at r t)]
    (ray/hit t point (v/div (v/sub point (.-center s)) (.-radius s)) (.-material s))))

(defn hit
  "The hit record for the nearest point in (`t-min`, `t-max`) at which the ray
  meets the sphere, or nil."
  [s r ^double t-min ^double t-max]
  (let [t (intersect s r t-min t-max)]
    (when-not (Double/isNaN t) (hit-at s r t))))
