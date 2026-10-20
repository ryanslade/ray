(in-package #:raytracer)

(defstruct (camera (:constructor %make-camera) (:copier nil))
  (origin +zero+ :type vec3 :read-only t)
  (lower-left +zero+ :type vec3 :read-only t)
  (horizontal +zero+ :type vec3 :read-only t)
  (vertical +zero+ :type vec3 :read-only t)
  (u +zero+ :type vec3 :read-only t)
  (v +zero+ :type vec3 :read-only t)
  (lens-radius 0d0 :type double-float :read-only t))

(defun make-camera (&key look-from look-at v-up vfov aspect aperture focus-dist)
  "A camera at LOOK-FROM facing LOOK-AT. VFOV is the vertical field of view in
degrees."
  (let* ((vfov (float vfov 1d0))
         (aspect (float aspect 1d0))
         (focus-dist (float focus-dist 1d0))
         ;; The same constant as Rust's to_radians.
         (theta (* vfov (/ pi 180d0)))
         ;; TAN calls the C library's tan, as Rust does.
         (half-height (tan (/ theta 2d0)))
         (half-width (* aspect half-height))
         (w (unit (v- look-from look-at)))
         (u (unit (cross v-up w)))
         (v (cross w u)))
    (%make-camera
     :origin look-from
     :lower-left (v- (v- (v- look-from (vscale (* half-width focus-dist) u))
                         (vscale (* half-height focus-dist) v))
                     (vscale focus-dist w))
     :horizontal (vscale (* (* 2d0 half-width) focus-dist) u)
     :vertical (vscale (* (* 2d0 half-height) focus-dist) v)
     :u u
     :v v
     :lens-radius (/ (float aperture 1d0) 2d0))))

(declaim (inline get-ray))
(defun get-ray (c s tt rng)
  "A ray through the viewport at normalised coordinates (S, TT), with its
origin jittered across the lens."
  (declare (double-float s tt))
  (let* ((rd (vscale (camera-lens-radius c) (random-in-unit-disk rng)))
         (offset (v+ (vscale (vx rd) (camera-u c)) (vscale (vy rd) (camera-v c))))
         (origin (camera-origin c)))
    (ray (v+ origin offset)
         (v- (v- (v+ (v+ (camera-lower-left c) (vscale s (camera-horizontal c)))
                     (vscale tt (camera-vertical c)))
                 origin)
             offset))))
