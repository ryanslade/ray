(in-package #:raytracer)

(defstruct (sphere (:constructor %sphere (center radius material)) (:copier nil))
  (center +zero+ :type vec3 :read-only t)
  (radius 0d0 :type double-float :read-only t)
  (material nil :type material :read-only t))

(defun sphere (center radius material)
  (%sphere center (float radius 1d0) material))

(defun sphere-intersect (s r t-min t-max)
  "The nearest distance in (T-MIN, T-MAX) at which the ray meets the sphere, or
NIL if there is none."
  (declare (double-float t-min t-max))
  (let* ((origin (ray-origin r))
         (direction (ray-direction r))
         (oc (v- origin (sphere-center s)))
         (a (dot direction direction))
         (b (dot oc direction))
         (c (- (dot oc oc) (* (sphere-radius s) (sphere-radius s))))
         (discriminant (- (* b b) (* a c))))
    (unless (< discriminant 0d0)
      (flet ((in-range (distance)
               (and (< distance t-max) (> distance t-min))))
        (declare (inline in-range))
        (let ((sqrt-d (fsqrt discriminant)))
          (let ((near (/ (- (- b) sqrt-d) a)))
            (if (in-range near)
                near
                (let ((far (/ (+ (- b) sqrt-d) a)))
                  (when (in-range far)
                    far)))))))))

(declaim (inline sphere-hit-at))
(defun sphere-hit-at (s r distance)
  "The hit record for a distance returned by SPHERE-INTERSECT."
  (let ((point (ray-at r distance)))
    (hit distance point (v/ (v- point (sphere-center s)) (sphere-radius s))
         (sphere-material s))))

(defun sphere-hit (s r t-min t-max)
  "The hit record for the nearest point in (T-MIN, T-MAX) at which the ray
meets the sphere, or NIL."
  (let ((distance (sphere-intersect s r t-min t-max)))
    (when distance
      (sphere-hit-at s r distance))))
