(ns raytracer.image
  "8-bit RGB images. Row 0 is the top."
  (:require [clojure.java.io :as io]
            [raytracer.vec3])
  (:import (java.awt.image BufferedImage)
           (java.util Arrays)
           (javax.imageio ImageIO)
           (raytracer.vec3 Vec3)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(deftype Image [^long width ^long height ^bytes pixels]
  Object
  (equals [_ o]
    (and (instance? Image o)
         (== width (.-width ^Image o))
         (== height (.-height ^Image o))
         (Arrays/equals pixels ^bytes (.-pixels ^Image o))))
  (hashCode [_] (Arrays/hashCode pixels)))

(defn image ^Image [^long width ^long height]
  (Image. width height (byte-array (* width height 3))))

(defn width ^long [^Image img] (.-width img))
(defn height ^long [^Image img] (.-height img))

(defn- to-byte
  "A channel in [0, 1] as a byte; out of range values are clamped."
  ^long [^double c]
  ;; Written so that NaN becomes 255, as in the Rust version.
  (let [b (* 255.99 (if (< c 1.0) c 1.0))]
    (if (> b 0.0) (long b) 0)))

(defn write-color!
  "Stores a colour at byte offset `i` of `pixels`, clamping each channel to
  [0, 1]."
  [^bytes pixels ^long i ^Vec3 c]
  (aset pixels i (unchecked-byte (to-byte (.-x c))))
  (aset pixels (inc i) (unchecked-byte (to-byte (.-y c))))
  (aset pixels (+ i 2) (unchecked-byte (to-byte (.-z c)))))

(defn- index ^long [^Image img ^long x ^long y]
  (when-not (and (< -1 x (.-width img)) (< -1 y (.-height img)))
    (throw (IndexOutOfBoundsException. "pixel out of bounds")))
  (* 3 (+ (* y (.-width img)) x)))

(defn set-pixel!
  "Stores a colour, clamping each channel to [0, 1]."
  [^Image img ^long x ^long y ^Vec3 c]
  (write-color! (.-pixels img) (index img x y) c))

(defn pixel
  "The pixel at (`x`, `y`) as [r g b], each in [0, 255]."
  [^Image img ^long x ^long y]
  (let [i (index img x y)
        ^bytes p (.-pixels img)]
    (mapv #(Byte/toUnsignedInt (aget p (+ i (long %)))) [0 1 2])))

(defn to-ppm
  "Binary (P6) PPM encoding."
  ^bytes [^Image img]
  (let [header (.getBytes (format "P6\n%d %d\n255\n" (.-width img) (.-height img))
                          "US-ASCII")
        ^bytes pixels (.-pixels img)
        out (Arrays/copyOf header (+ (alength header) (alength pixels)))]
    (System/arraycopy pixels 0 out (alength header) (alength pixels))
    out))

(defn to-buffered-image
  "The image as a java.awt BufferedImage, for encoding with ImageIO."
  ^BufferedImage [^Image img]
  (let [w (.-width img)
        h (.-height img)
        ^bytes p (.-pixels img)
        rgb (int-array (* w h))]
    (dotimes [i (alength rgb)]
      (let [j (* 3 i)]
        (aset rgb i (unchecked-int
                     (bit-or (bit-shift-left (Byte/toUnsignedInt (aget p j)) 16)
                             (bit-shift-left (Byte/toUnsignedInt (aget p (inc j))) 8)
                             (Byte/toUnsignedInt (aget p (+ j 2))))))))
    (doto (BufferedImage. w h BufferedImage/TYPE_INT_RGB)
      (.setRGB 0 0 w h rgb 0 w))))

(defn save-png [^Image img path]
  (when-not (ImageIO/write (to-buffered-image img) "png" (io/file path))
    (throw (java.io.IOException. "no PNG encoder"))))
