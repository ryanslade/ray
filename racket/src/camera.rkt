#lang racket/base

;; Compiled without the checks on primitive operations, such as that flonum
;; operations get flonums and that indices are in bounds; see the README.
(#%declare #:unsafe)

(require racket/contract/base racket/flonum racket/math "ray.rkt" "vec3.rkt")

(provide (contract-out
          [make-camera (-> #:look-from vec3? #:look-at vec3? #:v-up vec3? #:vfov real?
                           #:aspect real? #:aperture real? #:focus-dist real?
                           camera?)])
         camera? get-ray)

(struct camera (origin lower-left horizontal vertical u v lens-radius) #:authentic)

;; A camera at look-from facing look-at. vfov is the vertical field of view in
;; degrees.
(define (make-camera #:look-from look-from
                     #:look-at look-at
                     #:v-up v-up
                     #:vfov vfov
                     #:aspect aspect
                     #:aperture aperture
                     #:focus-dist focus-dist)
  (let* ([vfov (real->double-flonum vfov)]
         [aspect (real->double-flonum aspect)]
         [focus-dist (real->double-flonum focus-dist)]
         ;; The same constant as Rust's to_radians.
         [theta (fl* vfov (fl/ pi 180.0))]
         ;; fltan calls the C library's tan, as Rust does.
         [half-height (fltan (fl/ theta 2.0))]
         [half-width (fl* aspect half-height)]
         [w (unit (v- look-from look-at))]
         [u (unit (cross v-up w))]
         [v (cross w u)])
    (camera look-from
            (v- (v- (v- look-from (vscale (fl* half-width focus-dist) u))
                    (vscale (fl* half-height focus-dist) v))
                (vscale focus-dist w))
            (vscale (fl* (fl* 2.0 half-width) focus-dist) u)
            (vscale (fl* (fl* 2.0 half-height) focus-dist) v)
            u
            v
            (fl/ (real->double-flonum aperture) 2.0))))

;; A ray through the viewport at normalised coordinates (s, t), with its
;; origin jittered across the lens.
(define (get-ray c s t rng)
  ;; The x and y of (vscale lens-radius p), without making the vector.
  (define p (random-in-unit-disk rng))
  (define rdx (fl* (camera-lens-radius c) (vx p)))
  (define rdy (fl* (camera-lens-radius c) (vy p)))
  (define offset (v+ (vscale rdx (camera-u c)) (vscale rdy (camera-v c))))
  (define origin (camera-origin c))
  (ray (v+ origin offset)
       (v- (v- (v+ (v+ (camera-lower-left c) (vscale s (camera-horizontal c)))
                   (vscale t (camera-vertical c)))
               origin)
           offset)))
