(ns raytracer.image
  "8-bit RGB images. Row 0 is the top."
  (:require [clojure.java.io :as io]
            [raytracer.vec3 :as v])
  (:import (java.awt.image BufferedImage)
           (javax.imageio ImageIO)))

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

(deftype Image [^long width ^long height ^bytes pixels])

(defn image [^long width ^long height]
  (Image. width height (byte-array (* width height 3))))

(defn- to-byte
  "A channel in [0, 1] as a byte; out of range values are clamped."
  ^long [^double c]
  ;; Written so that NaN becomes 255, as in the Rust version.
  (let [b (* 255.99 (if (< c 1.0) c 1.0))]
    (if (> b 0.0) (long b) 0)))

(defn- index ^long [^Image img ^long x ^long y]
  (when-not (and (< -1 x (.-width img)) (< -1 y (.-height img)))
    (throw (IndexOutOfBoundsException. "pixel out of bounds")))
  (* 3 (+ (* y (.-width img)) x)))

(defn set-pixel!
  "Stores a colour, clamping each channel to [0, 1]."
  [^Image img ^long x ^long y c]
  (let [i (index img x y)
        ^bytes p (.-pixels img)]
    (aset p i (unchecked-byte (to-byte (v/x c))))
    (aset p (inc i) (unchecked-byte (to-byte (v/y c))))
    (aset p (+ i 2) (unchecked-byte (to-byte (v/z c))))))

(defn pixel
  "The pixel at (`x`, `y`) as [r g b], each in [0, 255]."
  [^Image img ^long x ^long y]
  (let [i (index img x y)]
    (mapv #(Byte/toUnsignedInt (aget ^bytes (.-pixels img) (+ i (long %)))) [0 1 2])))

(defn to-ppm
  "Binary (P6) PPM encoding."
  ^bytes [^Image img]
  (byte-array (concat (.getBytes (format "P6\n%d %d\n255\n" (.-width img) (.-height img)))
                      (.-pixels img))))

(defn to-buffered-image
  "The image as a java.awt BufferedImage, for encoding with ImageIO."
  ^BufferedImage [^Image img]
  (doto (BufferedImage. (.-width img) (.-height img) BufferedImage/TYPE_INT_RGB)
    (-> .getRaster (.setPixels 0 0 (.-width img) (.-height img)
                               (int-array (map #(Byte/toUnsignedInt %) (.-pixels img)))))))

(defn save-png [img path]
  (when-not (ImageIO/write (to-buffered-image img) "png" (io/file path))
    (throw (java.io.IOException. "no PNG encoder"))))
