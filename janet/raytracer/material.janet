# Materials are structs tagged by :kind.

(import ./ray)
(import ./vec3)

(defn lambertian [albedo]
  {:kind :lambertian :albedo albedo})

(defn metal
  "fuzz is clamped to [0, 1]: 0 is a perfect mirror."
  [albedo fuzz]
  {:kind :metal :albedo albedo :fuzz (max 0 (min 1 fuzz))})

(defn dielectric [ref-index]
  {:kind :dielectric :ref-index ref-index})

(defn reflect [v n]
  (vec3/sub v (vec3/scale (* 2 (vec3/dot v n)) n)))

(defn refract
  "The refracted direction, or nil on total internal reflection."
  [v n ni-over-nt]
  (def uv (vec3/unit v))
  (def dt (vec3/dot uv n))
  (def discriminant (- 1 (* ni-over-nt ni-over-nt (- 1 (* dt dt)))))
  (when (> discriminant 0)
    (vec3/sub (vec3/scale ni-over-nt (vec3/sub uv (vec3/scale dt n)))
              (vec3/scale (math/sqrt discriminant) n))))

(defn schlick
  "Schlick's approximation for reflectance at a given angle."
  [cosine ref-index]
  (def r0 (let [r (/ (- 1 ref-index) (+ 1 ref-index))] (* r r)))
  # Multiplied out rather than using math/pow, whose result can vary by
  # platform and would break the golden image test.
  (def x (- 1 cosine))
  (def x2 (* x x))
  (+ r0 (* (- 1 r0) x2 x2 x)))

(defn scatter
  "Returns a tuple of the attenuation and scattered ray, or nil if the ray is
  absorbed."
  [material ray-in hit rng]
  (def {:point point :normal normal} hit)
  (def [_ d] ray-in)
  (case (material :kind)
    :lambertian
    (let [target (vec3/add (vec3/add point normal)
                           (vec3/random-in-unit-sphere rng))]
      [(material :albedo) (ray/new point (vec3/sub target point))])

    :metal
    (let [reflected (reflect (vec3/unit d) normal)
          direction (vec3/add reflected
                              (vec3/scale (material :fuzz)
                                          (vec3/random-in-unit-sphere rng)))]
      (when (> (vec3/dot direction normal) 0)
        [(material :albedo) (ray/new point direction)]))

    :dielectric
    (let [ref-index (material :ref-index)
          d-dot-n (vec3/dot d normal)
          [outward-normal ni-over-nt cosine]
          (if (> d-dot-n 0)
            [(vec3/neg normal) ref-index (/ (* ref-index d-dot-n) (vec3/length d))]
            [normal (/ 1 ref-index) (/ (- d-dot-n) (vec3/length d))])
          refracted (refract d outward-normal ni-over-nt)
          direction (if (and refracted
                             (>= (math/rng-uniform rng) (schlick cosine ref-index)))
                      refracted
                      (reflect d normal))]
      [[1 1 1] (ray/new point direction)])

    (errorf "unknown material %v" (material :kind))))
