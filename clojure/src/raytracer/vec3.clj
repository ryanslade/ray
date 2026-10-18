(ns raytracer.vec3
  "Vectors of three doubles, also used for colours (as r, g and b)."
  (:require [raytracer.rng])
  (:import (raytracer.rng Rng)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

;; A deftype rather than a vector or record keeps the components unboxed, and
;; the JIT can often avoid allocating short-lived ones at all.
(deftype Vec3 [^double x ^double y ^double z]
  Object
  (equals [_ o]
    (and (instance? Vec3 o)
         (== x (.-x ^Vec3 o)) (== y (.-y ^Vec3 o)) (== z (.-z ^Vec3 o))))
  (hashCode [_] (hash [x y z]))
  (toString [_] (str "#vec3[" x " " y " " z "]")))

(defn vec3 ^Vec3 [^double x ^double y ^double z] (Vec3. x y z))

(def zero (Vec3. 0.0 0.0 0.0))
(def black zero)
(def white (Vec3. 1.0 1.0 1.0))

(defn x ^double [^Vec3 v] (.-x v))
(defn y ^double [^Vec3 v] (.-y v))
(defn z ^double [^Vec3 v] (.-z v))

(defn add ^Vec3 [^Vec3 a ^Vec3 b]
  (Vec3. (+ (.-x a) (.-x b)) (+ (.-y a) (.-y b)) (+ (.-z a) (.-z b))))

(defn sub ^Vec3 [^Vec3 a ^Vec3 b]
  (Vec3. (- (.-x a) (.-x b)) (- (.-y a) (.-y b)) (- (.-z a) (.-z b))))

(defn mul
  "Component-wise multiplication."
  ^Vec3 [^Vec3 a ^Vec3 b]
  (Vec3. (* (.-x a) (.-x b)) (* (.-y a) (.-y b)) (* (.-z a) (.-z b))))

(defn scale
  "`v` multiplied by the scalar `s`."
  ^Vec3 [^double s ^Vec3 v]
  (Vec3. (* s (.-x v)) (* s (.-y v)) (* s (.-z v))))

(defn div ^Vec3 [^Vec3 v ^double s]
  (Vec3. (/ (.-x v) s) (/ (.-y v) s) (/ (.-z v) s)))

(defn neg ^Vec3 [^Vec3 v]
  (Vec3. (- (.-x v)) (- (.-y v)) (- (.-z v))))

(defn dot ^double [^Vec3 a ^Vec3 b]
  (+ (* (.-x a) (.-x b)) (* (.-y a) (.-y b)) (* (.-z a) (.-z b))))

(defn cross ^Vec3 [^Vec3 a ^Vec3 b]
  (Vec3. (- (* (.-y a) (.-z b)) (* (.-z a) (.-y b)))
         (- (* (.-z a) (.-x b)) (* (.-x a) (.-z b)))
         (- (* (.-x a) (.-y b)) (* (.-y a) (.-x b)))))

(defn length-squared ^double [^Vec3 v] (dot v v))

(defn length ^double [^Vec3 v] (Math/sqrt (length-squared v)))

(defn unit ^Vec3 [^Vec3 v] (div v (length v)))

(defn random-in-unit-sphere
  "Rejection sampling: pick points in the enclosing cube until one lands
  inside."
  ^Vec3 [^Rng rng]
  (let [x (- (* 2.0 (.nextF64 rng)) 1.0)
        y (- (* 2.0 (.nextF64 rng)) 1.0)
        z (- (* 2.0 (.nextF64 rng)) 1.0)]
    (if (< (+ (* x x) (* y y) (* z z)) 1.0)
      (Vec3. x y z)
      (recur rng))))

(defn random-in-unit-disk ^Vec3 [^Rng rng]
  (let [x (- (* 2.0 (.nextF64 rng)) 1.0)
        y (- (* 2.0 (.nextF64 rng)) 1.0)]
    (if (< (+ (* x x) (* y y)) 1.0)
      (Vec3. x y 0.0)
      (recur rng))))
