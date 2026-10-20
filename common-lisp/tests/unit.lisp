(in-package #:raytracer-tests)

(defconstant +infinity+ sb-ext:double-float-positive-infinity)
;;; A quiet NaN, made from its bits, since computing one signals an error.
(defconstant +nan+ (sb-kernel:make-double-float #x7ff80000 0))

(defun close-p (a b)
  (< (vlength (v- a b)) 1d-9))

(deftest vec3-arithmetic
  (let ((a (vec3 1d0 2d0 3d0))
        (b (vec3 4d0 5d0 6d0)))
    (check (close-p (vec3 5d0 7d0 9d0) (v+ a b)))
    (check (close-p (vec3 2d0 4d0 6d0) (vscale 2d0 a)))
    (check (= 32 (dot a b)))
    (check (close-p (vec3 -3d0 6d0 -3d0) (cross a b)))
    (check (< (abs (- (vlength (unit b)) 1d0)) 1d-9))))

(deftest rng-floats-in-unit-interval
  (let ((r (make-rng 1)))
    (check (loop repeat 10000
                 for f = (next-f64 r)
                 always (and (>= f 0) (< f 1))))))

(deftest rng-same-seed-same-sequence
  (let ((a (make-rng 42))
        (b (make-rng 42)))
    (check (equal (loop repeat 100 collect (next-u64 a))
                  (loop repeat 100 collect (next-u64 b))))))

(deftest rng-matches-splitmix64
  ;; The first outputs for seed 0 from the reference implementation.
  (let ((r (make-rng 0)))
    (check (= #xe220a8397b1dcdaf (next-u64 r)))
    (check (= #x6e789e6aa1b965f4 (next-u64 r)))))

(deftest sphere-hits
  (let* ((m (dielectric 1.5d0))
         (s (sphere (vec3 0d0 0d0 -1d0) 0.5d0 m))
         (towards (ray +zero+ (vec3 0d0 0d0 -1d0)))
         (h (sphere-hit s towards 0d0 +infinity+)))
    (check h)
    (when h
      (check (= 0.5d0 (hit-distance h)))
      (check (equalp (vec3 0d0 0d0 1d0) (hit-normal h)))
      (check (eq m (hit-material h))))
    (let ((far (sphere-hit s towards 0.6d0 +infinity+)))
      (check (and far (= 1.5d0 (hit-distance far))) "far side"))
    (check (null (sphere-hit s (ray +zero+ (vec3 0d0 1d0 0d0)) 0d0 +infinity+)))))

(deftest world-closest-hit
  (let* ((m (dielectric 1.5d0))
         (w (make-world (list (sphere (vec3 0d0 0d0 -5d0) 1d0 m)
                              (sphere (vec3 0d0 0d0 -2d0) 0.5d0 m))))
         (h (world-hit w (ray +zero+ (vec3 0d0 0d0 -1d0)) 0d0 +infinity+)))
    (check (and h (= 1.5d0 (hit-distance h))))
    (check (null (world-hit w (ray +zero+ (vec3 0d0 1d0 0d0)) 0d0 +infinity+)))))

(defun coord (rng scale)
  (* scale (- (* 2d0 (next-f64 rng)) 1d0)))

(deftest world-matches-sphere-by-sphere
  ;; WORLD-HIT has its own copy of the intersection arithmetic, which must
  ;; find exactly the hit that SPHERE-HIT on each sphere in turn would.
  (let* ((rng (make-rng 1))
         (m (dielectric 1.5d0))
         (spheres (loop repeat 23
                        collect (sphere (vec3 (coord rng 3) (coord rng 3) (coord rng 3))
                                        (+ 0.1d0 (abs (coord rng 1)))
                                        m)))
         (rays (loop repeat 2000
                     collect (ray (vec3 (coord rng 5) (coord rng 5) (coord rng 5))
                                  (vec3 (coord rng 1) (coord rng 1) (coord rng 1)))))
         (world (make-world spheres))
         (mismatches 0))
    (dolist (r rays)
      (let ((want nil)
            (t-max most-positive-double-float))
        (dolist (s spheres)
          (let ((h (sphere-hit s r 0.001d0 t-max)))
            (when h
              (setf want h
                    t-max (hit-distance h)))))
        (unless (equalp want (world-hit world r 0.001d0 most-positive-double-float))
          (incf mismatches))))
    (check (zerop mismatches))))

(deftest total-internal-reflection
  (check (null (raytracer::refract (vec3 1d0 -0.1d0 0d0) (vec3 0d0 1d0 0d0) 1.5d0))))

(deftest refracts-head-on
  (let* ((down (vec3 0d0 -1d0 0d0))
         (r (raytracer::refract down (vec3 0d0 1d0 0d0) (/ 1d0 1.5d0))))
    (check (and r (close-p down r)))))

(deftest metal-fuzz-is-clamped
  (check (= 1 (metal-fuzz (metal +white+ 2d0))))
  (check (= 0 (metal-fuzz (metal +white+ -1d0)))))

(deftest image-set-clamps
  (let ((img (make-image 3 1)))
    (set-pixel img 1 0 (vec3 2d0 0.5d0 -1d0))
    ;; f64::min in Rust ignores NaN, so NaN becomes 255. Comparing a NaN
    ;; signals an error unless the trap is masked, as RENDER does.
    (sb-int:with-float-traps-masked (:invalid)
      (set-pixel img 2 0 (vec3 +nan+ 0d0 0d0)))
    (check (equal '(0 0 0) (pixel img 0 0)))
    (check (equal '(255 127 0) (pixel img 1 0)))
    (check (equal '(255 0 0) (pixel img 2 0)))
    (check (signals error (pixel img 3 0)))))

(deftest ppm-header
  (let ((ppm (to-ppm (make-image 3 2))))
    (check (string= (format nil "P6~%3 2~%255~%")
                    (map 'string #'code-char (subseq ppm 0 11))))
    (check (= (+ 11 (* 3 2 3)) (length ppm)))))
