(ns raytracer.ray
  (:require [raytracer.vec3 :as v])
  (:import (raytracer.vec3 Vec3)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(deftype Ray [^Vec3 origin ^Vec3 direction])

(defn ray ^Ray [^Vec3 origin ^Vec3 direction] (Ray. origin direction))

(defn origin ^Vec3 [^Ray r] (.-origin r))
(defn direction ^Vec3 [^Ray r] (.-direction r))

(defn at ^Vec3 [^Ray r ^double t]
  (v/add (.-origin r) (v/scale t (.-direction r))))
