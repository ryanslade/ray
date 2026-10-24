(in-package #:raytracer)

(defconstant +width+ 800)
(defconstant +height+ 450)
(defconstant +samples+ 100)

(defun small-sphere (rng a b)
  "A small sphere in the grid square at (A, B), or NIL if it would be too close
to the metal sphere."
  (let* ((x (+ a (* 0.9d0 (next-f64 rng))))
         (z (+ b (* 0.9d0 (next-f64 rng))))
         (center (vec3 x 0.2d0 z)))
    (when (> (vlength (v- center (vec3 4d0 0.2d0 0d0))) 0.9d0)
      (flet ((channel () (* (next-f64 rng) (next-f64 rng))))
        ;; Arguments are evaluated left to right, so the channels draw from
        ;; the generator in order.
        (sphere center 0.2d0 (lambertian (vec3 (channel) (channel) (channel))))))))

(defun random-world (rng)
  (make-world
   (append
    (list (sphere (vec3 0d0 -1000d0 -1d0) 1000d0
                  (lambertian (vec3 0.5d0 0.5d0 0.5d0))))
    (loop for a from -11d0 below 11d0
          nconc (loop for b from -11d0 below 11d0
                      for s = (small-sphere rng a b)
                      when s collect s))
    (list (sphere (vec3 4d0 1d0 0d0) 1d0 (metal (vec3 0.8d0 0.6d0 0.2d0) 0.1d0))
          (sphere (vec3 0d0 1d0 0d0) 1d0 (dielectric 1.5d0))
          (sphere (vec3 -4d0 1d0 0d0) 1d0 (metal (vec3 0.8d0 0.8d0 0.8d0) 0.2d0))))))

(defun main (&optional (output "out.png"))
  "Renders the example scene to OUTPUT."
  (use-large-nursery)
  (format *error-output* "Generating world~%")
  (let* ((world (random-world (make-rng 1)))
         (look-from (vec3 3d0 2d0 3d0))
         (look-at (vec3 0d0 0d0 -1d0))
         (camera (make-camera :look-from look-from
                              :look-at look-at
                              :v-up (vec3 0d0 1d0 0d0)
                              :vfov 90
                              :aspect (/ (float +width+ 1d0) +height+)
                              :aperture 0.01d0
                              :focus-dist (vlength (v- look-from look-at))))
         (threads (cpu-count)))
    (format *error-output* "Rendering on ~D threads~%" threads)
    (let ((img (render-with-threads threads +width+ +height+ +samples+ camera world)))
      (handler-case (save-png img output)
        ((or file-error stream-error) (e)
          (format *error-output* "Writing ~A: ~A~%" output
                  (let ((*print-pretty* nil)) (princ-to-string e)))
          (sb-ext:exit :code 1 :abort t))))
    (format *error-output* "Wrote ~A~%" output)))
