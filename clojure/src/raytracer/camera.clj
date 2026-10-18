(ns raytracer.camera
  (:require [raytracer.ray :as ray]
            [raytracer.rng]
            [raytracer.vec3 :as v])
  (:import (raytracer.ray Ray)
           (raytracer.rng Rng)
           (raytracer.vec3 Vec3)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(deftype Camera [^Vec3 origin ^Vec3 lower-left ^Vec3 horizontal ^Vec3 vertical
                 ^Vec3 u ^Vec3 v ^double lens-radius])

(defn camera
  "A camera at `look-from` facing `look-at`. `vfov` is the vertical field of
  view in degrees."
  ^Camera [{:keys [look-from look-at v-up vfov aspect aperture focus-dist]}]
  (let [vfov (double vfov)
        aspect (double aspect)
        focus-dist (double focus-dist)
        theta (Math/toRadians vfov)
        ;; StrictMath gives the same result on every JVM.
        half-height (StrictMath/tan (/ theta 2.0))
        half-width (* aspect half-height)
        w (v/unit (v/sub look-from look-at))
        u (v/unit (v/cross v-up w))
        v (v/cross w u)]
    (Camera. look-from
             (-> look-from
                 (v/sub (v/scale (* half-width focus-dist) u))
                 (v/sub (v/scale (* half-height focus-dist) v))
                 (v/sub (v/scale focus-dist w)))
             (v/scale (* 2.0 half-width focus-dist) u)
             (v/scale (* 2.0 half-height focus-dist) v)
             u
             v
             (/ (double aperture) 2.0))))

(defn get-ray
  "A ray through the viewport at normalised coordinates (`s`, `t`), with its
  origin jittered across the lens."
  ^Ray [^Camera c ^double s ^double t ^Rng rng]
  (let [rd (v/scale (.-lens-radius c) (v/random-in-unit-disk rng))
        offset (v/add (v/scale (v/x rd) (.-u c)) (v/scale (v/y rd) (.-v c)))
        origin (.-origin c)]
    (ray/ray (v/add origin offset)
             (-> (.-lower-left c)
                 (v/add (v/scale s (.-horizontal c)))
                 (v/add (v/scale t (.-vertical c)))
                 (v/sub origin)
                 (v/sub offset)))))
