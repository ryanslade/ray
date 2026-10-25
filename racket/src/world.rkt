#lang racket/base

;; Compiled without the checks on primitive operations, such as that flonum
;; operations get flonums and that indices are in bounds; see the README.
(#%declare #:unsafe)

(require racket/contract/base racket/flonum "ray.rkt" "sphere.rkt" "vec3.rkt")

(provide (contract-out [make-world (-> (listof sphere?) world?)]) world? world-hit)

;; centers-and-radii holds each sphere's centre and squared radius in turn, as
;; four unboxed flonums, so that the closest-hit loop reads them in order
;; without following a pointer to each sphere and its centre.
(struct world (spheres centers-and-radii) #:authentic)

(define (make-world spheres)
  (define data (make-flvector (* 4 (length spheres))))
  (for ([s (in-list spheres)]
        [i (in-naturals)])
    (define center (sphere-center s))
    (flvector-set! data (* 4 i) (vx center))
    (flvector-set! data (+ (* 4 i) 1) (vy center))
    (flvector-set! data (+ (* 4 i) 2) (vz center))
    (flvector-set! data (+ (* 4 i) 3) (fl* (sphere-radius s) (sphere-radius s))))
  (world (list->vector spheres) data))

;; The closest hit in (t-min, t-max), shrinking t-max as nearer spheres are
;; found, or #f.
;;
;; This finds the same hit as calling sphere-intersect on each sphere in turn,
;; with the same arithmetic, so renders are unchanged; but it works on plain
;; flonums, so it allocates nothing but one flvector until it has found the
;; closest sphere.
(define (world-hit w r t-min t-max)
  (define data (world-centers-and-radii w))
  (define o (ray-origin r))
  (define d (ray-direction r))
  (define ox (vx o))
  (define oy (vy o))
  (define oz (vz o))
  (define dx (vx d))
  (define dy (vy d))
  (define dz (vz d))
  (define a (dot d d))
  (define n (flvector-length data))
  ;; A flonum passed from one iteration of a loop to the next is boxed each
  ;; time, so the distance to the closest hit so far is kept in an flvector,
  ;; which holds it unboxed.
  (define best (make-flvector 1 t-max))
  ;; Only the hit record for the closest sphere is ever needed, so this just
  ;; tracks which one it is until the end.
  (let loop ([i 0] [closest -1])
    (cond
      [(< i n)
       ;; oc is the vector from the sphere's centre to the ray's origin.
       (define ocx (fl- ox (flvector-ref data i)))
       (define ocy (fl- oy (flvector-ref data (+ i 1))))
       (define ocz (fl- oz (flvector-ref data (+ i 2))))
       (define b (fl+ (fl+ (fl* ocx dx) (fl* ocy dy)) (fl* ocz dz)))
       (define c (fl- (fl+ (fl+ (fl* ocx ocx) (fl* ocy ocy)) (fl* ocz ocz))
                      (flvector-ref data (+ i 3))))
       (define discriminant (fl- (fl* b b) (fl* a c)))
       ;; Most rays miss most spheres.
       (if (fl< discriminant 0.0)
           (loop (+ i 4) closest)
           (let* ([t-max (flvector-ref best 0)]
                  [sqrt-d (flsqrt discriminant)]
                  [near (fl/ (fl- (fl- b) sqrt-d) a)])
             (if (and (fl< near t-max) (fl> near t-min))
                 (begin (flvector-set! best 0 near) (loop (+ i 4) i))
                 (let ([far (fl/ (fl+ (fl- b) sqrt-d) a)])
                   (if (and (fl< far t-max) (fl> far t-min))
                       (begin (flvector-set! best 0 far) (loop (+ i 4) i))
                       (loop (+ i 4) closest))))))]
      [(>= closest 0)
       (sphere-hit-at (vector-ref (world-spheres w) (quotient closest 4)) r
                      (flvector-ref best 0))]
      [else #f])))
