(in-package #:raytracer)

;;; CENTERS-AND-RADII holds each sphere's centre and squared radius in turn, as
;;; four unboxed doubles, so that the closest-hit loop reads them in order
;;; without following a pointer to each sphere and its centre.
(defstruct (world (:constructor %make-world (spheres centers-and-radii))
                  (:copier nil))
  (spheres #() :type simple-vector :read-only t)
  (centers-and-radii (make-array 0 :element-type 'double-float)
   :type (simple-array double-float (*)) :read-only t))

(defun make-world (spheres)
  (let* ((spheres (coerce spheres 'simple-vector))
         (data (make-array (* 4 (length spheres)) :element-type 'double-float)))
    (loop for s across spheres
          for i from 0 by 4
          for center = (sphere-center s)
          do (setf (aref data i) (vx center)
                   (aref data (+ i 1)) (vy center)
                   (aref data (+ i 2)) (vz center)
                   (aref data (+ i 3)) (* (sphere-radius s) (sphere-radius s))))
    (%make-world spheres data)))

(defun world-hit (w r t-min t-max)
  "The closest hit in (T-MIN, T-MAX), shrinking T-MAX as nearer spheres are
found, or NIL.

This finds the same hit as calling SPHERE-INTERSECT on each sphere in turn,
with the same arithmetic, so renders are unchanged; but it works on plain
doubles, so it allocates nothing until it has found the closest sphere."
  (declare (type world w) (type ray r) (double-float t-min t-max)
           (optimize speed))
  (let* ((data (world-centers-and-radii w))
         (o (ray-origin r))
         (d (ray-direction r))
         (ox (vx o)) (oy (vy o)) (oz (vz o))
         (dx (vx d)) (dy (vy d)) (dz (vz d))
         (a (dot d d))
         ;; Only the hit record for the closest sphere is ever needed, so just
         ;; track which one it is until the end.
         (closest -1))
    (declare (fixnum closest))
    ;; The loop stays within DATA, whose length is a multiple of four, so it
    ;; leaves out the bounds checks, which make it about 15% slower.
    (locally (declare (optimize (safety 0)))
      (do ((i 0 (+ i 4)))
          ((>= i (length data)))
        (declare (fixnum i))
        ;; OC is the vector from the sphere's centre to the ray's origin.
        (let* ((ocx (- ox (aref data i)))
               (ocy (- oy (aref data (+ i 1))))
               (ocz (- oz (aref data (+ i 2))))
               (b (+ (+ (* ocx dx) (* ocy dy)) (* ocz dz)))
               (c (- (+ (+ (* ocx ocx) (* ocy ocy)) (* ocz ocz)) (aref data (+ i 3))))
               (discriminant (- (* b b) (* a c))))
          ;; Most rays miss most spheres.
          (unless (< discriminant 0d0)
            (flet ((in-range (distance)
                     (and (< distance t-max) (> distance t-min))))
              (declare (inline in-range))
              (let* ((sqrt-d (fsqrt discriminant))
                     (near (/ (- (- b) sqrt-d) a)))
                (if (in-range near)
                    (setf closest i t-max near)
                    (let ((far (/ (+ (- b) sqrt-d) a)))
                      (when (in-range far)
                        (setf closest i t-max far))))))))))
    (when (>= closest 0)
      (sphere-hit-at (svref (world-spheres w) (floor closest 4)) r t-max))))
