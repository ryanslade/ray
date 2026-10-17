# A ray is a tuple of its origin and direction.

(import ./vec3)

(defn new [origin direction]
  [origin direction])

(defn at [[origin direction] t]
  (vec3/add origin (vec3/scale t direction)))
