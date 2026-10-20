;;;; 8-bit RGB images. Row 0 is the top.

(in-package #:raytracer)

(deftype pixels () '(simple-array (unsigned-byte 8) (*)))

(defstruct (image (:constructor %make-image (width height pixels)) (:copier nil))
  (width 0 :type (and fixnum unsigned-byte) :read-only t)
  (height 0 :type (and fixnum unsigned-byte) :read-only t)
  (pixels nil :type pixels :read-only t))

(defun make-image (width height)
  (%make-image width height
               (make-array (* width height 3) :element-type '(unsigned-byte 8))))

(declaim (inline write-color))
(defun write-color (pixels i c)
  "Stores a colour at byte offset I of PIXELS, clamping each channel to [0, 1]."
  (declare (type pixels pixels) (fixnum i))
  (flet ((to-byte (c)
           (declare (double-float c))
           ;; Written so that NaN becomes 255, as in the Rust version.
           (let ((b (* 255.99d0 (if (< c 1d0) c 1d0))))
             (if (> b 0d0) (truncate b) 0))))
    (setf (aref pixels i) (to-byte (vx c))
          (aref pixels (+ i 1)) (to-byte (vy c))
          (aref pixels (+ i 2)) (to-byte (vz c)))))

(defun pixel-index (img x y)
  (unless (and (< -1 x (image-width img)) (< -1 y (image-height img)))
    (error "Pixel (~D, ~D) is out of bounds." x y))
  (* 3 (+ (* y (image-width img)) x)))

(defun set-pixel (img x y c)
  "Stores a colour, clamping each channel to [0, 1]."
  (write-color (image-pixels img) (pixel-index img x y) c))

(defun pixel (img x y)
  "The pixel at (X, Y) as a list (r g b), each in [0, 255]."
  (let ((i (pixel-index img x y)))
    (coerce (subseq (image-pixels img) i (+ i 3)) 'list)))

(defun to-ppm (img)
  "Binary (P6) PPM encoding."
  (let ((header (map 'pixels #'char-code
                     (format nil "P6~%~D ~D~%255~%"
                             (image-width img) (image-height img)))))
    (concatenate 'pixels header (image-pixels img))))

(defun save-ppm (img path)
  (with-open-file (out path :direction :output :element-type '(unsigned-byte 8)
                            :if-exists :supersede)
    (write-sequence (to-ppm img) out))
  img)
