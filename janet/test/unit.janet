(import ../raytracer/image)
(import ../raytracer/material)
(import ../raytracer/ray)
(import ../raytracer/sphere)
(import ../raytracer/vec3)
(import ../raytracer/world)

(defn close? [a b]
  (< (vec3/length (vec3/sub a b)) 1e-9))

# vec3
(let [a [1 2 3] b [4 5 6]]
  (assert (close? (vec3/add a b) [5 7 9]))
  (assert (close? (vec3/scale 2 a) [2 4 6]))
  (assert (= (vec3/dot a b) 32))
  (assert (close? (vec3/cross a b) [-3 6 -3]))
  (assert (< (math/abs (- (vec3/length (vec3/unit b)) 1)) 1e-9)))

# rng
(let [rng (math/rng 1)]
  (repeat 10000
    (def f (math/rng-uniform rng))
    (assert (and (>= f 0) (< f 1)))))

# sphere
(let [s (sphere/new [0 0 -1] 0.5 (material/dielectric 1.5))
      towards (ray/new vec3/zero [0 0 -1])
      h (sphere/hit s towards 0 math/inf)]
  (assert h "expected a hit")
  (assert (= (h :t) 0.5))
  (assert (deep= (h :normal) [0 0 1]))
  (assert (= ((sphere/hit s towards 0.6 math/inf) :t) 1.5) "far side")
  (assert (nil? (sphere/hit s (ray/new vec3/zero [0 1 0]) 0 math/inf))))

# world
(let [m (material/dielectric 1.5)
      w (world/new [(sphere/new [0 0 -5] 1 m) (sphere/new [0 0 -2] 0.5 m)])
      h (world/hit w (ray/new vec3/zero [0 0 -1]) 0 math/inf)]
  (assert h "expected a hit")
  (assert (= (h :t) 1.5))
  (assert (close? (h :normal) [0 0 1])))

# material
(let [n [0 1 0]
      down [0 -1 0]]
  (assert (nil? (material/refract [1 -0.1 0] n 1.5)) "total internal reflection")
  (assert (close? (material/refract down n (/ 1 1.5)) down) "refracts head on")
  (assert (= ((material/metal [1 1 1] 2) :fuzz) 1) "fuzz is clamped"))

# image
(let [img (image/new 2 1)]
  (image/set-pixel img 1 0 [2 0.5 -1])
  (assert (deep= (image/get-pixel img 0 0) [0 0 0]))
  (assert (deep= (image/get-pixel img 1 0) [255 127 0])))

(let [ppm (image/to-ppm (image/new 3 2))]
  (assert (string/has-prefix? "P6\n3 2\n255\n" ppm))
  (assert (= (length ppm) (+ 11 (* 3 2 3)))))
