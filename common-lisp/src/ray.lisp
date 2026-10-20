(in-package #:raytracer)

(declaim (inline ray hit))
(defstruct (ray (:constructor ray (origin direction)) (:copier nil))
  (origin +zero+ :type vec3 :read-only t)
  (direction +zero+ :type vec3 :read-only t))

;;; The other versions call a distance along a ray t, but T is taken in Lisp.

(declaim (inline ray-at))
(defun ray-at (r distance)
  (declare (double-float distance))
  (v+ (ray-origin r) (vscale distance (ray-direction r))))

;;; DISTANCE is in multiples of the ray's direction, and MATERIAL is one of
;;; the structures in material.lisp.
(defstruct (hit (:constructor hit (distance point normal material)) (:copier nil))
  (distance 0d0 :type double-float :read-only t)
  (point +zero+ :type vec3 :read-only t)
  (normal +zero+ :type vec3 :read-only t)
  (material nil :read-only t))
