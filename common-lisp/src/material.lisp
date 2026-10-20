(in-package #:raytracer)

;;; ALBEDO is the colour that scattered light is multiplied by.
(defstruct (material (:constructor nil) (:copier nil))
  (albedo +white+ :type vec3 :read-only t))

(defstruct (lambertian (:include material) (:constructor lambertian (albedo))
                       (:copier nil)))

(defstruct (metal (:include material) (:constructor %metal (albedo fuzz))
                  (:copier nil))
  (fuzz 0d0 :type double-float :read-only t))

(defun metal (albedo fuzz)
  "FUZZ is clamped to [0, 1]: 0 is a perfect mirror."
  (%metal albedo (max 0d0 (min (float fuzz 1d0) 1d0))))

(defstruct (dielectric (:include material) (:constructor dielectric (ref-index))
                       (:copier nil))
  (ref-index 1d0 :type double-float :read-only t))

(declaim (inline reflect refract schlick))

(defun reflect (v n)
  (v- v (vscale (* 2d0 (dot v n)) n)))

(defun refract (v n ni-over-nt)
  "The refracted ray's direction, or NIL on total internal reflection."
  (declare (double-float ni-over-nt))
  (let* ((uv (unit v))
         (dt (dot uv n))
         (discriminant (- 1d0 (* (* ni-over-nt ni-over-nt) (- 1d0 (* dt dt))))))
    (when (> discriminant 0d0)
      (v- (vscale ni-over-nt (v- uv (vscale dt n)))
          (vscale (fsqrt discriminant) n)))))

(defun schlick (cosine ref-index)
  "Schlick's approximation for reflectance at a given angle."
  (declare (double-float cosine ref-index))
  (let* ((r0 (/ (- 1d0 ref-index) (+ 1d0 ref-index)))
         (r0 (* r0 r0))
         ;; Multiplied out rather than using EXPT, to match the other
         ;; versions' golden image.
         (x (- 1d0 cosine))
         (x2 (* x x)))
    (+ r0 (* (* (* (- 1d0 r0) x2) x2) x))))

(defun scatter (material ray-in hit rng)
  "The scattered ray, or NIL if the ray is absorbed."
  (declare (optimize speed))
  (let ((point (hit-point hit))
        (normal (hit-normal hit)))
    (etypecase material
      (lambertian
       (let ((target (v+ (v+ point normal) (random-in-unit-sphere rng))))
         (ray point (v- target point))))
      (metal
       (let* ((reflected (reflect (unit (ray-direction ray-in)) normal))
              (direction (v+ reflected (vscale (metal-fuzz material)
                                               (random-in-unit-sphere rng)))))
         (when (> (dot direction normal) 0d0)
           (ray point direction))))
      (dielectric
       (let* ((ref-index (dielectric-ref-index material))
              (d (ray-direction ray-in))
              (d-dot-n (dot d normal))
              (outside (> d-dot-n 0d0))
              (refracted (if outside
                             (refract d (vneg normal) ref-index)
                             (refract d normal (/ 1d0 ref-index))))
              (cosine (if outside
                          (/ (* ref-index d-dot-n) (vlength d))
                          (/ (- d-dot-n) (vlength d)))))
         (ray point
              ;; Only draws a random number when the ray can refract.
              (if (and refracted
                       (>= (next-f64 rng) (schlick cosine ref-index)))
                  refracted
                  (reflect d normal))))))))
