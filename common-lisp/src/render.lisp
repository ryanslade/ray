(in-package #:raytracer)

(defconstant +max-depth+ 50)
(sb-ext:define-load-time-global +sky-blue+ (vec3 0.5d0 0.7d0 1d0))
(declaim (type vec3 +sky-blue+))

(declaim (inline sky))
(defun sky (r)
  (let ((tt (* 0.5d0 (+ (vy (unit (ray-direction r))) 1d0))))
    (v+ (vscale (- 1d0 tt) +white+) (vscale tt +sky-blue+))))

(defun ray-color (world r rng)
  "The colour seen along a ray, following up to 50 bounces."
  (declare (optimize speed))
  ;; ATTENUATION is the product of the attenuations of every surface hit so
  ;; far.
  (let ((attenuation +white+))
    (dotimes (depth (1+ +max-depth+) +black+)
      (let ((hit (world-hit world r 0.001d0 most-positive-double-float)))
        (unless hit
          (return (v* attenuation (sky r))))
        (let* ((material (hit-material hit))
               (scattered (and (< depth +max-depth+)
                               (scatter material r hit rng))))
          (unless scattered
            (return +black+))
          (setf attenuation (v* attenuation (material-albedo material))
                r scattered))))))

(defun render-row (pixels y width height samples camera world)
  (declare (type pixels pixels)
           (type (and fixnum unsigned-byte) y width height samples)
           (optimize speed))
  (let ((rng (make-rng (1+ y))))
    (dotimes (x width)
      (let ((r 0d0) (g 0d0) (b 0d0))
        (declare (double-float r g b))
        (dotimes (s samples)
          (let* ((u (/ (+ (float x 1d0) (next-f64 rng)) (float width 1d0)))
                 (v (/ (+ (float (- height 1 y) 1d0) (next-f64 rng))
                       (float height 1d0)))
                 (c (ray-color world (get-ray camera u v rng) rng)))
            (incf r (vx c))
            (incf g (vy c))
            (incf b (vz c))))
        (write-color pixels (the fixnum (* 3 (+ (* y width) x)))
                     (v/ (vec3 r g b) (float samples 1d0)))))))

;;; A word-sized slot, which SB-EXT:ATOMIC-INCF can update.
(defstruct (row-counter (:copier nil))
  (next 0 :type sb-ext:word))

(defun render-with-threads (threads width height samples camera world)
  "Renders the world with SAMPLES rays per pixel on THREADS threads.

Each row uses its own random state seeded from the row index, so the image is
identical regardless of the number of threads."
  (check-type threads (integer 1))
  (let* ((img (make-image width height))
         (pixels (image-pixels img))
         (rows (make-row-counter))
         ;; Rows vary a lot in cost (sky is cheap, spheres are expensive), so
         ;; threads take rows one at a time rather than a fixed block each.
         (worker (lambda ()
                   ;; Infinities and NaNs are results, as in the other
                   ;; versions, not errors.
                   (sb-int:with-float-traps-masked
                       (:overflow :invalid :divide-by-zero)
                     (loop for y = (sb-ext:atomic-incf (row-counter-next rows))
                           while (< y height)
                           do (render-row pixels y width height samples
                                          camera world)))))
         ;; Each thread returns any error it signals, so that it can be
         ;; signalled again here.
         (others (loop repeat (1- threads)
                       collect (sb-thread:make-thread
                                (lambda () (handler-case (progn (funcall worker) nil)
                                             (error (e) e)))
                                :name "render"))))
    (unwind-protect (funcall worker)
      (dolist (e (mapcar #'sb-thread:join-thread others))
        (when e (error e))))
    img))

(defun cpu-count ()
  "The number of online processors."
  (sb-alien:alien-funcall
   (sb-alien:extern-alien "sysconf" (function sb-alien:long sb-alien:int))
   ;; _SC_NPROCESSORS_ONLN
   #+darwin 58 #+linux 84))

(defun use-large-nursery ()
  "Lets 256 MB be allocated between garbage collections, rather than SBCL's
default of about 50 MB. Rendering allocates hundreds of megabytes a second,
nearly all of it garbage by the next collection, so a collection costs about
the same however much was allocated before it; but each one stops every
thread. Programs that render call this first."
  (setf (sb-ext:bytes-consed-between-gcs) (* 256 1024 1024)))

(defun render (width height samples camera world)
  "Renders the world with SAMPLES rays per pixel, in parallel across all
available cores."
  (render-with-threads (cpu-count) width height samples camera world))
