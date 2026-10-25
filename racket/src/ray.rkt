#lang racket/base

;; Compiled without the checks on primitive operations, such as that flonum
;; operations get flonums and that indices are in bounds; see the README.
(#%declare #:unsafe)

(require racket/flonum "vec3.rkt")

(provide (struct-out ray) ray-at (struct-out hit) max-distance)

(struct ray (origin direction) #:authentic #:transparent)

;; The point at distance t, in multiples of the ray's direction.
(define (ray-at r t)
  (v+ (ray-origin r) (vscale t (ray-direction r))))

;; The largest flonum, Rust's f64::MAX, the farthest a hit can be.
(define max-distance 1.7976931348623157e308)

;; material is one of the structures in material.rkt.
(struct hit (distance point normal material) #:authentic #:transparent)
