(ns raytracer.vec3
  "Vectors of three doubles, also used for colours (as r, g and b)."
  {:clj-kondo/config '{:lint-as {raytracer.vec3/defop clojure.core/defn}}}
  (:require [clojure.walk :as walk]
            [raytracer.rng :as rng]))

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

(defmacro ^:private defop
  "Defines a function returning the Vec3 whose components are `expr`, in which
  each ^Vec3 argument stands for the matching component of that vector."
  [name args expr]
  (let [vecs (filter #(= 'Vec3 (:tag (meta %))) args)]
    `(defn ~name ~(with-meta args {:tag 'Vec3})
       (Vec3. ~@(for [field '[.-x .-y .-z]]
                  (walk/postwalk-replace (zipmap vecs (map #(list field %) vecs)) expr))))))

(defop add [^Vec3 a ^Vec3 b] (+ a b))
(defop sub [^Vec3 a ^Vec3 b] (- a b))
(defop mul [^Vec3 a ^Vec3 b] (* a b))
(defop scale [^double s ^Vec3 v] (* s v))
(defop div [^Vec3 v ^double s] (/ v s))
(defop neg [^Vec3 v] (- v))

(defn dot ^double [^Vec3 a ^Vec3 b]
  (+ (* (.-x a) (.-x b)) (* (.-y a) (.-y b)) (* (.-z a) (.-z b))))

(defn cross ^Vec3 [^Vec3 a ^Vec3 b]
  (Vec3. (- (* (.-y a) (.-z b)) (* (.-z a) (.-y b)))
         (- (* (.-z a) (.-x b)) (* (.-x a) (.-z b)))
         (- (* (.-x a) (.-y b)) (* (.-y a) (.-x b)))))

(defn length ^double [v] (Math/sqrt (dot v v)))

(defn unit ^Vec3 [v] (div v (length v)))

(defn- coordinate ^double [rng] (- (* 2.0 (rng/next-f64 rng)) 1.0))

(defn random-in-unit-sphere
  "Rejection sampling: pick points in the enclosing cube until one lands
  inside."
  ^Vec3 [rng]
  (let [x (coordinate rng), y (coordinate rng), z (coordinate rng)]
    (if (< (+ (* x x) (* y y) (* z z)) 1.0) (Vec3. x y z) (recur rng))))

(defn random-in-unit-disk ^Vec3 [rng]
  (let [x (coordinate rng), y (coordinate rng)]
    (if (< (+ (* x x) (* y y)) 1.0) (Vec3. x y 0.0) (recur rng))))
