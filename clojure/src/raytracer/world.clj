(ns raytracer.world
  (:require [raytracer.sphere :as sphere]
            [raytracer.vec3 :as v])
  (:import (raytracer.ray Ray)
           (raytracer.sphere Sphere)
           (raytracer.vec3 Vec3)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

;; Alongside the spheres, the closest-hit loop gets each one's centre and
;; squared radius packed four to a sphere in one array of doubles, so that it
;; reads them without following a pointer per sphere.
(deftype World [^Sphere/1 spheres ^doubles geometry])

(defn world [spheres]
  (World. (into-array Sphere spheres)
          (double-array (mapcat (fn [^Sphere s]
                                  [(v/x (.-center s)) (v/y (.-center s)) (v/z (.-center s))
                                   (* (.-radius s) (.-radius s))])
                                spheres))))

(defn hit
  "The closest hit in (`t-min`, `t-max`), shrinking `t-max` as nearer spheres
  are found, or nil."
  [^World w ^Ray r ^double t-min ^double t-max]
  ;; The same sums as sphere/intersect, with the ray's parts and d.d worked out
  ;; once per ray rather than once per sphere.
  (let [^doubles g (.-geometry w)
        ^Vec3 o (.-origin r), ^Vec3 d (.-direction r)
        ox (.-x o), oy (.-y o), oz (.-z o)
        dx (.-x d), dy (.-y d), dz (.-z d)
        a (v/dot d d)]
    ;; Only the hit record for the closest sphere is ever needed, so just
    ;; track which one it is until the end.
    (loop [i 0, closest -1, t-max t-max]
      (if (< i (alength g))
        (let [ocx (- ox (aget g i)), ocy (- oy (aget g (+ i 1))), ocz (- oz (aget g (+ i 2)))
              b (+ (* ocx dx) (* ocy dy) (* ocz dz))
              c (- (+ (* ocx ocx) (* ocy ocy) (* ocz ocz)) (aget g (+ i 3)))
              discriminant (- (* b b) (* a c))]
          (if (< discriminant 0.0)
            (recur (+ i 4) closest t-max)
            (let [sqrt-d (Math/sqrt discriminant)
                  near (/ (- (- b) sqrt-d) a)]
              (if (and (< near t-max) (> near t-min))
                (recur (+ i 4) i near)
                (let [far (/ (+ (- b) sqrt-d) a)]
                  (if (and (< far t-max) (> far t-min))
                    (recur (+ i 4) i far)
                    (recur (+ i 4) closest t-max)))))))
        (when (>= closest 0)
          (sphere/hit-at (aget ^Sphere/1 (.-spheres w) (quot closest 4)) r t-max))))))
