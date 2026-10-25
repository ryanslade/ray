#lang racket/base

;; Renders the example scene to its argument, or to out.png.

(require racket/fixnum racket/flonum racket/future "src/raytracer.rkt")

(define width 800)
(define height 450)
(define samples 100)

;; A small sphere in the grid square at (a, b), or #f if it would be too close
;; to the metal sphere.
(define (small-sphere rng a b)
  (let* ([x (fl+ a (fl* 0.9 (next-f64 rng)))]
         [z (fl+ b (fl* 0.9 (next-f64 rng)))]
         [center (vec3 x 0.2 z)])
    (and (fl> (vlength (v- center (vec3 4.0 0.2 0.0))) 0.9)
         (let ([channel (λ () (fl* (next-f64 rng) (next-f64 rng)))])
           ;; Arguments are evaluated left to right, so the channels draw from
           ;; the generator in order.
           (sphere center 0.2 (lambertian (vec3 (channel) (channel) (channel))))))))

(define (random-world rng)
  (make-world
   (append
    (list (sphere (vec3 0.0 -1000.0 -1.0) 1000.0 (lambertian (vec3 0.5 0.5 0.5))))
    (for*/list ([a (in-range -11 11)]
                [b (in-range -11 11)]
                [s (in-value (small-sphere rng (fx->fl a) (fx->fl b)))]
                #:when s)
      s)
    (list (sphere (vec3 4.0 1.0 0.0) 1.0 (metal (vec3 0.8 0.6 0.2) 0.1))
          (sphere (vec3 0.0 1.0 0.0) 1.0 (dielectric 1.5))
          (sphere (vec3 -4.0 1.0 0.0) 1.0 (metal (vec3 0.8 0.8 0.8) 0.2))))))

(define (main output)
  (eprintf "Generating world\n")
  (define world (random-world (make-rng 1)))
  (define look-from (vec3 3.0 2.0 3.0))
  (define look-at (vec3 0.0 0.0 -1.0))
  (define camera (make-camera #:look-from look-from
                              #:look-at look-at
                              #:v-up (vec3 0.0 1.0 0.0)
                              #:vfov 90
                              #:aspect (fl/ (fx->fl width) (fx->fl height))
                              #:aperture 0.01
                              #:focus-dist (vlength (v- look-from look-at))))
  (define threads (processor-count))
  (eprintf "Rendering on ~a threads\n" threads)
  (define img (render/threads threads width height samples camera world))
  (with-handlers ([exn:fail:filesystem?
                   (λ (e)
                     (eprintf "Writing ~a: ~a\n" output (exn-message e))
                     (exit 1))])
    (save-png img output))
  (eprintf "Wrote ~a\n" output))

(module+ main
  (require racket/cmdline)
  (command-line #:args ([output "out.png"]) (main output)))
