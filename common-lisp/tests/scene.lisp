;;;; The scene used by the tests and benchmark, matching the other versions.

(in-package #:raytracer-tests)

(defun scene-world ()
  (make-world
   (list (sphere (vec3 0d0 -100.5d0 -1d0) 100d0
                 (lambertian (vec3 0.5d0 0.5d0 0.5d0)))
         (sphere (vec3 0d0 0d0 -1d0) 1d0 (metal (vec3 0.8d0 0.8d0 0.8d0) 0.2d0))
         (sphere (vec3 1.5d0 0d0 -1d0) 1d0 (dielectric 1.5d0)))))

(defun scene-camera (width height)
  (let ((look-from (vec3 1d0 1d0 1d0))
        (look-at (vec3 0d0 0d0 -1d0)))
    (make-camera :look-from look-from
                 :look-at look-at
                 :v-up (vec3 0d0 1d0 0d0)
                 :vfov 90
                 :aspect (/ (float width 1d0) height)
                 :aperture 0.01d0
                 :focus-dist (vlength (v- look-from look-at)))))
