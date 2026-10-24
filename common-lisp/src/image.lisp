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

(defun octets (&rest octets)
  (make-array (length octets) :element-type '(unsigned-byte 8)
                              :initial-contents octets))

(defun u32-be (n)
  "N as four big-endian bytes."
  (octets (ldb (byte 8 24) n) (ldb (byte 8 16) n)
          (ldb (byte 8 8) n) (ldb (byte 8 0) n)))

(defparameter *crc-table*
  (let ((table (make-array 256 :element-type '(unsigned-byte 32))))
    (dotimes (n 256 table)
      (let ((c n))
        (dotimes (k 8)
          (setf c (if (logbitp 0 c) (logxor #xEDB88320 (ash c -1)) (ash c -1))))
        (setf (aref table n) c)))))

(defun crc32 (&rest sequences)
  "The CRC-32 of the concatenation of SEQUENCES of bytes."
  (let ((c #xFFFFFFFF))
    (dolist (bytes sequences (logxor c #xFFFFFFFF))
      (loop for byte across bytes
            do (setf c (logxor (aref *crc-table* (logand (logxor c byte) #xFF))
                               (ash c -8)))))))

(defun adler32 (bytes)
  (let ((a 1) (b 0))
    (loop for byte across bytes
          do (setf a (mod (+ a byte) 65521)
                   b (mod (+ b a) 65521)))
    (logior (ash b 16) a)))

(defun zlib-stored (data)
  "A zlib stream holding DATA in uncompressed (stored) deflate blocks, which
can be at most 65535 bytes each. SBCL has no compressor, and this keeps the
encoder small at the cost of file size."
  (let* ((len (length data))
         (blocks (max 1 (ceiling len 65535)))
         (out (make-array (+ 2 (* 5 blocks) len 4)
                          :element-type '(unsigned-byte 8)))
         (pos 2))
    (setf (aref out 0) #x78
          (aref out 1) #x01)
    (dotimes (i blocks)
      (let* ((start (* i 65535))
             (n (min 65535 (- len start))))
        (setf (aref out pos) (if (= i (1- blocks)) 1 0)
              (aref out (+ pos 1)) (ldb (byte 8 0) n)
              (aref out (+ pos 2)) (ldb (byte 8 8) n)
              (aref out (+ pos 3)) (ldb (byte 8 0) (lognot n))
              (aref out (+ pos 4)) (ldb (byte 8 8) (lognot n)))
        (replace out data :start1 (+ pos 5) :start2 start :end2 (+ start n))
        (incf pos (+ 5 n))))
    (replace out (u32-be (adler32 data)) :start1 pos)
    out))

(defun png-chunk (type data)
  (let ((type (map 'pixels #'char-code type)))
    (concatenate 'pixels (u32-be (length data)) type data (u32-be (crc32 type data)))))

(defun to-png (img)
  "PNG encoding. The pixel data is stored uncompressed, so the file is about
the same size as the PPM."
  (let* ((width (image-width img))
         (height (image-height img))
         (row-bytes (* 3 width))
         ;; Each scanline starts with its filter type, 0 for none.
         (raw (make-array (* (1+ row-bytes) height)
                          :element-type '(unsigned-byte 8) :initial-element 0)))
    (dotimes (y height)
      (replace raw (image-pixels img)
               :start1 (1+ (* y (1+ row-bytes)))
               :start2 (* y row-bytes) :end2 (* (1+ y) row-bytes)))
    (concatenate 'pixels
                 (octets #x89 80 78 71 13 10 26 10)
                 (png-chunk "IHDR"
                            (concatenate 'pixels (u32-be width) (u32-be height)
                                         ;; 8 bits per channel, RGB, deflate,
                                         ;; no filtering, no interlacing.
                                         (octets 8 2 0 0 0)))
                 (png-chunk "IDAT" (zlib-stored raw))
                 (png-chunk "IEND" (octets)))))

(defun save-png (img path)
  (with-open-file (out path :direction :output :element-type '(unsigned-byte 8)
                            :if-exists :supersede)
    (write-sequence (to-png img) out))
  img)
