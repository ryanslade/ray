(ns raytracer.ray
  "Rays, and where they hit things."
  (:require [raytracer.vec3 :as v]))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(defrecord Ray [origin direction])

;; Unlike ->Ray, a function defined with defn is direct linked.
(defn ray [origin direction] (Ray. origin direction))

(defn at [^Ray r ^double t] (v/add (.-origin r) (v/scale t (.-direction r))))

;; `material` is a raytracer.material/Material.
(defrecord Hit [^double t point normal material])

(defn hit [^double t point normal material] (Hit. t point normal material))
