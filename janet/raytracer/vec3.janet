# Vectors are 3-tuples of numbers. Colours use the same representation, with
# the channels in the order r, g, b.

(def zero [0 0 0])

(defn add [[ax ay az] [bx by bz]]
  [(+ ax bx) (+ ay by) (+ az bz)])

(defn sub [[ax ay az] [bx by bz]]
  [(- ax bx) (- ay by) (- az bz)])

(defn scale
  "Multiplies each component by the number s."
  [s [x y z]]
  [(* s x) (* s y) (* s z)])

(defn mul
  "Component-wise multiplication."
  [[ax ay az] [bx by bz]]
  [(* ax bx) (* ay by) (* az bz)])

(defn div [[x y z] s]
  [(/ x s) (/ y s) (/ z s)])

(defn neg [[x y z]]
  [(- x) (- y) (- z)])

(defn dot [[ax ay az] [bx by bz]]
  (+ (* ax bx) (* ay by) (* az bz)))

(defn cross [[ax ay az] [bx by bz]]
  [(- (* ay bz) (* az by))
   (- (* az bx) (* ax bz))
   (- (* ax by) (* ay bx))])

(defn length-squared [v]
  (dot v v))

(defn length [v]
  (math/sqrt (dot v v)))

(defn unit [v]
  (div v (length v)))

(defn random-in-unit-sphere
  "Rejection sampling: pick points in the enclosing cube until one lands
  inside."
  [rng]
  (var p nil)
  (while (nil? p)
    (def x (- (* 2 (math/rng-uniform rng)) 1))
    (def y (- (* 2 (math/rng-uniform rng)) 1))
    (def z (- (* 2 (math/rng-uniform rng)) 1))
    (when (< (+ (* x x) (* y y) (* z z)) 1)
      (set p [x y z])))
  p)

(defn random-in-unit-disk [rng]
  (var p nil)
  (while (nil? p)
    (def x (- (* 2 (math/rng-uniform rng)) 1))
    (def y (- (* 2 (math/rng-uniform rng)) 1))
    (when (< (+ (* x x) (* y y)) 1)
      (set p [x y 0])))
  p)
