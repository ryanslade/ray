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

(defn uint32-be [buf pos]
  (+ (* 16777216 (buf pos)) (* 65536 (buf (+ pos 1)))
     (* 256 (buf (+ pos 2))) (buf (+ pos 3))))

(defn uint16-le [buf pos]
  (+ (buf pos) (* 256 (buf (+ pos 1)))))

(defn png-chunks
  "Splits a PNG into its chunks, as [type data] pairs."
  [png]
  (def chunks @[])
  (var pos 8)
  (while (< pos (length png))
    (def len (uint32-be png pos))
    (array/push chunks [(string/slice png (+ pos 4) (+ pos 8))
                        (string/slice png (+ pos 8) (+ pos 8 len))])
    (+= pos (+ 12 len)))
  chunks)

(defn inflate-stored
  "Decodes a zlib stream made of stored deflate blocks, the only kind
  image/to-png writes."
  [z]
  (def out @"")
  (var pos 2)
  (forever
    (def header (z pos))
    (assert (zero? (band (brshift header 1) 3)) "expected a stored block")
    (def len (uint16-le z (+ pos 1)))
    (assert (= (uint16-le z (+ pos 3)) (- 65535 len)) "NLEN")
    (buffer/push out (string/slice z (+ pos 5) (+ pos 5 len)))
    (+= pos (+ 5 len))
    (when (odd? header) (break)))
  out)

# Big enough for the pixel data to need more than one stored block.
(let [width 200
      height 120
      img (image/new width height)]
  (for y 0 height
    (for x 0 width
      (image/set-pixel img x y [(/ x width) (/ y height) (/ (% (+ x y) 7) 7)])))
  (def png (image/to-png img))
  (assert (string/has-prefix? "\x89PNG\r\n\x1a\n" png))
  # IEND's CRC is the same in every PNG, which checks the CRC code.
  (assert (string/has-suffix? "\0\0\0\0IEND\xAE\x42\x60\x82" png))
  (def chunks (png-chunks png))
  (assert (deep= (map first chunks) @["IHDR" "IDAT" "IEND"]))
  (def [[_ header] [_ data]] chunks)
  (assert (= (uint32-be header 0) width))
  (assert (= (uint32-be header 4) height))
  (assert (= (string/slice header 8) "\x08\x02\0\0\0") "8-bit RGB")
  (def raw (inflate-stored data))
  (def row-bytes (+ 1 (* 3 width)))
  (assert (= (length raw) (* row-bytes height)))
  (for y 0 height
    (assert (zero? (raw (* y row-bytes))) "no filter")
    (for x 0 width
      (def i (+ (* y row-bytes) 1 (* 3 x)))
      (assert (deep= [(raw i) (raw (+ i 1)) (raw (+ i 2))]
                     (image/get-pixel img x y))
              (string/format "pixel (%d, %d)" x y)))))
