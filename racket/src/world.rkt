#lang s-exp "lang.rkt"

(require "ray.rkt" "sphere.rkt" "vec3.rkt")

(provide (contract-out [make-world (-> (listof sphere?) world?)]) world? world-hit)

;; centers-and-radii holds each sphere's centre and squared radius in turn, as
;; four unboxed flonums, so that the closest-hit loop reads them in order
;; without following a pointer to each sphere and its centre.
(struct world (spheres centers-and-radii) #:authentic)

(define (make-world spheres)
  (world (list->vector spheres)
         (for*/flvector ([s (in-list spheres)]
                         [x (let ([c (sphere-center s)] [r (sphere-radius s)])
                              (in-list (list (vx c) (vy c) (vz c) (flo (* r r)))))])
           x)))

;; The closest hit in (t-min, t-max), shrinking t-max as nearer spheres are
;; found, or #f.
;;
;; This finds the same hit as calling sphere-intersect on each sphere in turn,
;; with the same arithmetic, so renders are unchanged; but it works on plain
;; flonums, so it allocates nothing but one flvector until it has found the
;; closest sphere.
(define (world-hit w r t-min t-max)
  (define data (world-centers-and-radii w))
  (define-xyz (ox oy oz) (ray-origin r))
  (define-xyz (dx dy dz) (ray-direction r))
  (define a (flo (+ (* dx dx) (* dy dy) (* dz dz))))
  ;; A flonum passed from one iteration of a loop to the next is boxed each
  ;; time, so the distance to the closest hit so far is kept in an flvector,
  ;; which holds it unboxed.
  (define best (make-flvector 1 t-max))
  ;; Only the hit record for the closest sphere is ever needed, so this just
  ;; tracks which one it is until the end.
  (let loop ([i 0] [closest -1])
    (cond
      [(< i (flvector-length data))
       ;; oc is the vector from the sphere's centre to the ray's origin.
       (define ocx (flo (- ox (flvector-ref data i))))
       (define ocy (flo (- oy (flvector-ref data (+ i 1)))))
       (define ocz (flo (- oz (flvector-ref data (+ i 2)))))
       (define b (flo (+ (* ocx dx) (* ocy dy) (* ocz dz))))
       (define radius² (flvector-ref data (+ i 3)))
       (define c (flo (- (+ (* ocx ocx) (* ocy ocy) (* ocz ocz)) radius²)))
       (define discriminant (flo (- (* b b) (* a c))))
       ;; Most rays miss most spheres.
       (if (flo (< discriminant 0))
           (loop (+ i 4) closest)
           (let* ([t-max (flvector-ref best 0)]
                  [sqrt-d (flsqrt discriminant)]
                  [near (flo (/ (- (- b) sqrt-d) a))])
             (cond [(flo (< t-min near t-max))
                    (flvector-set! best 0 near)
                    (loop (+ i 4) i)]
                   [(let ([far (flo (/ (+ (- b) sqrt-d) a))])
                      (and (flo (< t-min far t-max)) (flvector-set! best 0 far)))
                    (loop (+ i 4) i)]
                   [else (loop (+ i 4) closest)])))]
      [(>= closest 0)
       (sphere-hit-at (vector-ref (world-spheres w) (quotient closest 4)) r
                      (flvector-ref best 0))]
      [else #f])))
