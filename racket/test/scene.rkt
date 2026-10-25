#lang racket/base

;; The scene used by the tests and benchmark, matching the other versions.

(require "../src/raytracer.rkt")

(provide scene-world scene-camera)

(define (scene-world)
  (make-world
   (list (sphere (vec3 0.0 -100.5 -1.0) 100.0 (lambertian (vec3 0.5 0.5 0.5)))
         (sphere (vec3 0.0 0.0 -1.0) 1.0 (metal (vec3 0.8 0.8 0.8) 0.2))
         (sphere (vec3 1.5 0.0 -1.0) 1.0 (dielectric 1.5)))))

(define (scene-camera width height)
  (define look-from (vec3 1.0 1.0 1.0))
  (define look-at (vec3 0.0 0.0 -1.0))
  (make-camera #:look-from look-from
               #:look-at look-at
               #:v-up (vec3 0.0 1.0 0.0)
               #:vfov 90
               #:aspect (/ width height)
               #:aperture 0.01
               #:focus-dist (vlength (v- look-from look-at))))
