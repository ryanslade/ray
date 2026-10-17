(import ./sphere)

(defn new [spheres]
  # The centres and squared radii are also flattened into one array, so that
  # the hit loop is plain arithmetic: it runs for every sphere on every bounce,
  # and calling sphere/intersect there instead makes the example scene about
  # five times slower.
  (def packed @[])
  (each {:center [x y z] :radius r} spheres
    (array/push packed x y z (* r r)))
  {:spheres spheres :packed packed})

(defn hit
  "Returns the closest hit, shrinking t-max as nearer objects are found."
  [world r t-min t-max]
  (def [[ox oy oz] [dx dy dz]] r)
  (def packed (world :packed))
  (def a (+ (* dx dx) (* dy dy) (* dz dz)))
  # Only the hit record for the closest sphere is ever needed, so just track
  # which one it is until the end.
  (var closest nil)
  (var t-max t-max)
  (var i 0)
  (def n (length packed))
  (while (< i n)
    # Same as sphere/intersect.
    (def ocx (- ox (in packed i)))
    (def ocy (- oy (in packed (+ i 1))))
    (def ocz (- oz (in packed (+ i 2))))
    (def b (+ (* ocx dx) (* ocy dy) (* ocz dz)))
    (def c (- (+ (* ocx ocx) (* ocy ocy) (* ocz ocz)) (in packed (+ i 3))))
    (def discriminant (- (* b b) (* a c)))
    (when (>= discriminant 0)
      (def sqrt-d (math/sqrt discriminant))
      (def near (/ (- (- b) sqrt-d) a))
      (if (and (< near t-max) (> near t-min))
        (do (set closest i) (set t-max near))
        (let [far (/ (+ (- b) sqrt-d) a)]
          (when (and (< far t-max) (> far t-min))
            (set closest i)
            (set t-max far)))))
    (+= i 4))
  (when closest
    (sphere/hit-at (in (world :spheres) (/ closest 4)) r t-max)))
