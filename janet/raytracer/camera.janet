(import ./ray)
(import ./vec3)

(defn new
  "A camera at look-from pointing at look-at. vfov is the vertical field of
  view in degrees."
  [&named look-from look-at v-up vfov aspect aperture focus-dist]
  (def theta (* vfov (/ math/pi 180)))
  (def half-height (math/tan (/ theta 2)))
  (def half-width (* aspect half-height))
  (def w (vec3/unit (vec3/sub look-from look-at)))
  (def u (vec3/unit (vec3/cross v-up w)))
  (def v (vec3/cross w u))
  {:origin look-from
   :lower-left (-> look-from
                   (vec3/sub (vec3/scale (* half-width focus-dist) u))
                   (vec3/sub (vec3/scale (* half-height focus-dist) v))
                   (vec3/sub (vec3/scale focus-dist w)))
   :horizontal (vec3/scale (* 2 half-width focus-dist) u)
   :vertical (vec3/scale (* 2 half-height focus-dist) v)
   :u u
   :v v
   :lens-radius (/ aperture 2)})

(defn get-ray
  "A ray through the viewport at normalised coordinates (s, t), with its
  origin jittered across the lens."
  [camera s t rng]
  (def {:origin origin :lower-left lower-left :horizontal horizontal
        :vertical vertical :u u :v v :lens-radius lens-radius} camera)
  (def [rx ry] (vec3/scale lens-radius (vec3/random-in-unit-disk rng)))
  (def offset (vec3/add (vec3/scale rx u) (vec3/scale ry v)))
  (ray/new
    (vec3/add origin offset)
    (-> lower-left
        (vec3/add (vec3/scale s horizontal))
        (vec3/add (vec3/scale t vertical))
        (vec3/sub origin)
        (vec3/sub offset))))
