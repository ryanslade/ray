# An 8-bit RGB image. Row 0 is the top.

(defn new [width height]
  @{:width width
    :height height
    :pixels (buffer/new-filled (* width height 3))})

(defn- to-byte [v]
  (max 0 (math/floor (* 255.99 (min v 1)))))

(defn push-pixel
  "Appends a colour to an RGB byte buffer, clamping each channel to [0, 1]."
  [buf [r g b]]
  (buffer/push-byte buf (to-byte r) (to-byte g) (to-byte b)))

(defn- index [image x y]
  (assert (and (< -1 x (image :width)) (< -1 y (image :height)))
          "pixel out of bounds")
  (* 3 (+ x (* y (image :width)))))

(defn set-pixel
  "Stores a colour, clamping each channel to [0, 1]."
  [image x y c]
  (def px (push-pixel @"" c))
  (buffer/blit (image :pixels) px (index image x y)))

(defn get-pixel
  "The pixel at (x, y), as a tuple of bytes."
  [image x y]
  (def i (index image x y))
  (def pixels (image :pixels))
  [(pixels i) (pixels (+ i 1)) (pixels (+ i 2))])

(defn set-row
  "Overwrites row y with a buffer of width * 3 bytes."
  [image y row]
  (assert (= (length row) (* 3 (image :width))) "wrong row length")
  (buffer/blit (image :pixels) row (index image 0 y)))

(defn to-ppm
  "Binary (P6) PPM encoding."
  [image]
  (buffer (string/format "P6\n%d %d\n255\n" (image :width) (image :height))
          (image :pixels)))

(defn save-ppm [image path]
  (spit path (to-ppm image)))
