(ns raytracer.hit
  (:require [raytracer.vec3])
  (:import (raytracer.vec3 Vec3)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

;; `material` is a raytracer.material/Material.
(deftype Hit [^double t ^Vec3 point ^Vec3 normal material])

(defn t ^double [^Hit h] (.-t h))
(defn point ^Vec3 [^Hit h] (.-point h))
(defn normal ^Vec3 [^Hit h] (.-normal h))
(defn material [^Hit h] (.-material h))
