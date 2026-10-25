#lang s-exp "lang.rkt"

(require "material.rkt" "ray.rkt" "vec3.rkt")

(provide (contract-out [sphere (-> vec3? real? material? sphere?)])
         sphere? sphere-center sphere-radius sphere-material
         sphere-intersect sphere-hit-at sphere-hit)

(struct sphere (center radius material)
  #:authentic
  #:guard (λ (center radius material name)
            (values center (real->double-flonum radius) material)))

;; The nearest distance in (t-min, t-max) at which the ray meets the sphere,
;; or #f if there is none.
(define (sphere-intersect s r t-min t-max)
  (define direction (ray-direction r))
  (define oc (v- (ray-origin r) (sphere-center s)))
  (define a (dot direction direction))
  (define b (dot oc direction))
  (define c (flo (- (dot oc oc) (* (sphere-radius s) (sphere-radius s)))))
  (define discriminant (flo (- (* b b) (* a c))))
  (and (flo (>= discriminant 0))
       (let* ([sqrt-d (flsqrt discriminant)]
              [near (flo (/ (- (- b) sqrt-d) a))]
              [far (flo (/ (+ (- b) sqrt-d) a))])
         (cond [(flo (< t-min near t-max)) near]
               [(flo (< t-min far t-max)) far]
               [else #f]))))

;; The hit record for a distance returned by sphere-intersect.
(define (sphere-hit-at s r distance)
  (define point (ray-at r distance))
  (hit distance point (v/ (v- point (sphere-center s)) (sphere-radius s))
       (sphere-material s)))

;; The hit record for the nearest point in (t-min, t-max) at which the ray
;; meets the sphere, or #f.
(define (sphere-hit s r t-min t-max)
  (define distance (sphere-intersect s r t-min t-max))
  (and distance (sphere-hit-at s r distance)))
