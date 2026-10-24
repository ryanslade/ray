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

# Janet's bitwise operators work on 32-bit signed integers, so the CRC is kept
# in that range and converted to unsigned only when it is written.

(defn- shift-right-8 [c]
  (band (brshift c 8) 0xFFFFFF))

(def- crc-table
  (seq [n :range [0 256]]
    (var c n)
    (repeat 8
      (def shifted (band (brshift c 1) 0x7FFFFFFF))
      # 0xEDB88320 as a signed 32-bit integer.
      (set c (if (odd? c) (bxor -306674912 shifted) shifted)))
    c))

(defn- crc32 [& bufs]
  (var c -1)
  (each buf bufs
    (each byte buf
      (set c (bxor (in crc-table (band (bxor c byte) 0xFF))
                   (shift-right-8 c)))))
  (def crc (bnot c))
  (if (neg? crc) (+ crc 0x100000000) crc))

(defn- adler32 [buf]
  (var a 1)
  (var b 0)
  (each byte buf
    (set a (% (+ a byte) 65521))
    (set b (% (+ b a) 65521)))
  (+ (* b 65536) a))

(defn- zlib-stored
  ```A zlib stream holding data in uncompressed (stored) deflate blocks, which
  can be at most 65535 bytes each. Janet has no compressor, and this keeps the
  encoder small at the cost of file size.```
  [data]
  (def len (length data))
  (def out (buffer/new (+ len (* 5 (math/ceil (/ len 65535))) 16)))
  (buffer/push-byte out 0x78 0x01)
  (var pos 0)
  (forever
    (def n (min 65535 (- len pos)))
    (def last? (= (+ pos n) len))
    (buffer/push-byte out (if last? 1 0))
    (buffer/push-uint16 out :le n)
    (buffer/push-uint16 out :le (- 65535 n))
    (buffer/push out (buffer/slice data pos (+ pos n)))
    (+= pos n)
    (when last? (break)))
  (buffer/push-uint32 out :be (adler32 data)))

(defn- push-chunk [buf kind data]
  (buffer/push-uint32 buf :be (length data))
  (buffer/push buf kind data)
  (buffer/push-uint32 buf :be (crc32 kind data)))

(defn to-png
  ```PNG encoding. The pixel data is stored uncompressed, so the file is about
  the same size as the PPM.```
  [image]
  (def {:width width :height height :pixels pixels} image)
  (def header (buffer/new 13))
  (buffer/push-uint32 header :be width)
  (buffer/push-uint32 header :be height)
  # 8 bits per channel, RGB, deflate, no filtering, no interlacing.
  (buffer/push-byte header 8 2 0 0 0)
  # Each scanline starts with its filter type, 0 for none.
  (def row-bytes (* 3 width))
  (def raw (buffer/new (* (+ row-bytes 1) height)))
  (for y 0 height
    (buffer/push-byte raw 0)
    (buffer/push raw (buffer/slice pixels (* y row-bytes) (* (+ y 1) row-bytes))))
  (def png (buffer "\x89PNG\r\n\x1a\n"))
  (push-chunk png "IHDR" header)
  (push-chunk png "IDAT" (zlib-stored raw))
  (push-chunk png "IEND" ""))

(defn save-png [image path]
  (spit path (to-png image)))
