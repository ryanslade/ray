(ns raytracer.sphere
  (:require [raytracer.hit :as hit]
            [raytracer.ray :as ray]
            [raytracer.vec3 :as v])
  (:import (raytracer.hit Hit)
           (raytracer.ray Ray)
           (raytracer.vec3 Vec3)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(deftype Sphere [^Vec3 center ^double radius material])

(defn sphere ^Sphere [^Vec3 center ^double radius material]
  (Sphere. center radius material))

(defn intersect
  "The nearest t in (`t-min`, `t-max`) at which the ray meets the sphere, or
  NaN if there is none. NaN rather than nil keeps the result unboxed."
  ^double [^Sphere s ^Ray r ^double t-min ^double t-max]
  (let [origin (ray/origin r)
        direction (ray/direction r)
        oc (v/sub origin (.-center s))
        a (v/dot direction direction)
        b (v/dot oc direction)
        c (- (v/dot oc oc) (* (.-radius s) (.-radius s)))
        discriminant (- (* b b) (* a c))]
    (if (< discriminant 0.0)
      ##NaN
      (let [sqrt-d (Math/sqrt discriminant)
            near (/ (- (- b) sqrt-d) a)]
        (if (and (< near t-max) (> near t-min))
          near
          (let [far (/ (+ (- b) sqrt-d) a)]
            (if (and (< far t-max) (> far t-min))
              far
              ##NaN)))))))

(defn hit-at
  "The hit record for a t returned by `intersect`."
  ^Hit [^Sphere s ^Ray r ^double t]
  (let [point (ray/at r t)]
    (Hit. t point (v/div (v/sub point (.-center s)) (.-radius s)) (.-material s))))

(defn hit
  "The hit record for the nearest point in (`t-min`, `t-max`) at which the ray
  meets the sphere, or nil."
  [^Sphere s ^Ray r ^double t-min ^double t-max]
  (let [t (intersect s r t-min t-max)]
    (when-not (Double/isNaN t)
      (hit-at s r t))))
