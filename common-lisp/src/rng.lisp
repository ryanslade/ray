;;;; A small, fast pseudo-random number generator (SplitMix64), the same as the
;;;; other versions use, so that scenes and renders are identical.

(in-package #:raytracer)

(deftype u64 () '(unsigned-byte 64))

;;; The state is a raw slot, so it is never boxed.
(defstruct (rng (:constructor make-rng (state)))
  "A generator seeded with STATE. Not safe to share between threads."
  (state 0 :type u64))

(declaim (inline next-u64 next-f64))

(defun next-u64 (rng)
  (declare (optimize speed (safety 0)))
  ;; SBCL compiles arithmetic wrapped in (ldb (byte 64 0) ...) to plain
  ;; wrapping machine instructions, rather than making bignums.
  (flet ((wrap (n) (ldb (byte 64 0) n)))
    (declare (inline wrap))
    (let* ((z (setf (rng-state rng) (wrap (+ (rng-state rng) #x9e3779b97f4a7c15))))
           (z (wrap (* (logxor z (ash z -30)) #xbf58476d1ce4e5b9)))
           (z (wrap (* (logxor z (ash z -27)) #x94d049bb133111eb))))
      (logxor z (ash z -31)))))

(defun next-f64 (rng)
  "A uniformly distributed double in [0, 1)."
  (declare (optimize speed (safety 0)))
  ;; The top 53 bits fill a double's mantissa exactly.
  (* (float (ash (next-u64 rng) -11) 1d0) #.(scale-float 1d0 -53)))
