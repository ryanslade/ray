(ns raytracer.material
  (:require [raytracer.hit :as hit]
            [raytracer.ray :as ray]
            [raytracer.rng]
            [raytracer.vec3 :as v])
  (:import (raytracer.rng Rng)
           (raytracer.vec3 Vec3)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(defprotocol Material
  (attenuation [m] "The colour that scattered light is multiplied by.")
  (scatter [m ray-in hit rng]
    "The scattered ray, or nil if the ray is absorbed."))

(defn- reflect ^Vec3 [^Vec3 v ^Vec3 n]
  (v/sub v (v/scale (* 2.0 (v/dot v n)) n)))

(defn- refract
  "The refracted ray's direction, or nil on total internal reflection."
  [^Vec3 v ^Vec3 n ^double ni-over-nt]
  (let [uv (v/unit v)
        dt (v/dot uv n)
        discriminant (- 1.0 (* ni-over-nt ni-over-nt (- 1.0 (* dt dt))))]
    (when (> discriminant 0.0)
      (v/sub (v/scale ni-over-nt (v/sub uv (v/scale dt n)))
             (v/scale (Math/sqrt discriminant) n)))))

(defn- schlick
  "Schlick's approximation for reflectance at a given angle."
  ^double [^double cosine ^double ref-index]
  (let [r0 (/ (- 1.0 ref-index) (+ 1.0 ref-index))
        r0 (* r0 r0)
        ;; Multiplied out rather than using Math/pow, to match the other
        ;; versions' golden image.
        x (- 1.0 cosine)
        x2 (* x x)]
    (+ r0 (* (- 1.0 r0) x2 x2 x))))

(defrecord Lambertian [^Vec3 albedo]
  Material
  (attenuation [_] albedo)
  (scatter [_ _ hit rng]
    (let [p (hit/point hit)
          target (-> p (v/add (hit/normal hit)) (v/add (v/random-in-unit-sphere rng)))]
      (ray/ray p (v/sub target p)))))

(defrecord Metal [^Vec3 albedo ^double fuzz]
  Material
  (attenuation [_] albedo)
  (scatter [_ ray-in hit rng]
    (let [normal (hit/normal hit)
          reflected (reflect (v/unit (ray/direction ray-in)) normal)
          direction (v/add reflected (v/scale fuzz (v/random-in-unit-sphere rng)))]
      (when (> (v/dot direction normal) 0.0)
        (ray/ray (hit/point hit) direction)))))

(defrecord Dielectric [^double ref-index]
  Material
  (attenuation [_] v/white)
  (scatter [_ ray-in hit rng]
    (let [d (ray/direction ray-in)
          normal (hit/normal hit)
          d-dot-n (v/dot d normal)
          outside? (> d-dot-n 0.0)
          refracted (if outside?
                      (refract d (v/neg normal) ref-index)
                      (refract d normal (/ 1.0 ref-index)))
          cosine (if outside?
                   (/ (* ref-index d-dot-n) (v/length d))
                   (/ (- d-dot-n) (v/length d)))]
      (ray/ray (hit/point hit)
               ;; Only draws a random number when the ray can refract.
               (if (and refracted
                        (>= (.nextF64 ^Rng rng) (schlick cosine ref-index)))
                 refracted
                 (reflect d normal))))))

(defn lambertian [albedo] (->Lambertian albedo))

(defn metal
  "`fuzz` is clamped to [0, 1]: 0 is a perfect mirror."
  [albedo ^double fuzz]
  (->Metal albedo (max 0.0 (min fuzz 1.0))))

(defn dielectric [^double ref-index] (->Dielectric ref-index))
