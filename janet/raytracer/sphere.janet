(import ./ray)
(import ./vec3)

(defn new [center radius material]
  {:center center :radius radius :material material})

(defn intersect
  "The nearest t in (t-min, t-max) at which the ray meets the sphere, or nil."
  [sphere [origin direction] t-min t-max]
  (def oc (vec3/sub origin (sphere :center)))
  (def a (vec3/dot direction direction))
  (def b (vec3/dot oc direction))
  (def c (- (vec3/dot oc oc) (* (sphere :radius) (sphere :radius))))
  (def discriminant (- (* b b) (* a c)))
  (when (>= discriminant 0)
    (def sqrt-d (math/sqrt discriminant))
    (def near (/ (- (- b) sqrt-d) a))
    (def far (/ (+ (- b) sqrt-d) a))
    (cond
      (and (< near t-max) (> near t-min)) near
      (and (< far t-max) (> far t-min)) far)))

(defn hit-at
  "The hit record for a t returned by intersect."
  [sphere r t]
  (def point (ray/at r t))
  {:t t
   :point point
   :normal (vec3/div (vec3/sub point (sphere :center)) (sphere :radius))
   :material (sphere :material)})

(defn hit [sphere r t-min t-max]
  (when-let [t (intersect sphere r t-min t-max)]
    (hit-at sphere r t)))
