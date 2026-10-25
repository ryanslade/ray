#lang racket/base

;; Compiled without the checks on primitive operations, such as that flonum
;; operations get flonums and that indices are in bounds; see the README.
(#%declare #:unsafe)

(require racket/contract/base racket/fixnum racket/flonum racket/future
         "camera.rkt" "image.rkt" "material.rkt" "ray.rkt" "rng.rkt" "vec3.rkt"
         "world.rkt")

(provide ray-color
         (contract-out
          [render (-> exact-positive-integer? exact-positive-integer?
                      exact-positive-integer? camera? world? any)]
          [render/threads (-> exact-positive-integer? exact-positive-integer?
                              exact-positive-integer? exact-positive-integer? camera?
                              world? any)]))

(define max-depth 50)
(define sky-blue (vec3 0.5 0.7 1.0))

(define (sky r)
  (define t (fl* 0.5 (fl+ (vy (unit (ray-direction r))) 1.0)))
  (v+ (vscale (fl- 1.0 t) white) (vscale t sky-blue)))

;; The colour seen along a ray, following up to 50 bounces. attenuation is the
;; product of the attenuations of every surface hit so far.
(define (ray-color w r rng)
  (let loop ([r r] [attenuation white] [depth 0])
    (define h (world-hit w r 0.001 max-distance))
    (cond
      [(not h) (v* attenuation (sky r))]
      [(fx= depth max-depth) black]
      [else
       (define-values (scattered albedo) (scatter (hit-material h) r h rng))
       (if scattered
           (loop scattered (v* attenuation albedo) (fx+ depth 1))
           black)])))

(define (render-row! pixels y width height samples camera world)
  (define rng (make-rng (+ y 1)))
  (define fwidth (fx->fl width))
  (define fheight (fx->fl height))
  (define row-v (fx->fl (- height 1 y)))
  ;; The sum of the samples' colours. A flonum passed from one iteration of a
  ;; loop to the next is boxed each time, where a vector holds them unboxed.
  (define sum (make-flvector 3))
  (for ([x (in-range width)])
    (define fx (fx->fl x))
    (flvector-set! sum 0 0.0)
    (flvector-set! sum 1 0.0)
    (flvector-set! sum 2 0.0)
    (for ([s (in-range samples)])
      (let* ([u (fl/ (fl+ fx (next-f64 rng)) fwidth)]
             [v (fl/ (fl+ row-v (next-f64 rng)) fheight)]
             [c (ray-color world (get-ray camera u v rng) rng)])
        (flvector-set! sum 0 (fl+ (vx sum) (vx c)))
        (flvector-set! sum 1 (fl+ (vy sum) (vy c)))
        (flvector-set! sum 2 (fl+ (vz sum) (vz c)))))
    (write-color! pixels (* 3 (+ (* y width) x)) (v/ sum (fx->fl samples)))))

;; The next row to render, counted up atomically by the threads.
(define (take-row! next)
  (define y (unbox* next))
  (if (box-cas! next y (+ y 1))
      y
      (take-row! next)))

;; Renders the world with samples rays per pixel on threads threads: futures,
;; which run in parallel on OS threads.
;;
;; Each row uses its own random state seeded from the row index, so the image
;; is identical regardless of the number of threads.
(define (render/threads threads width height samples camera world)
  (define img (make-image width height))
  (define pixels (image-pixels img))
  (define next (box 0))
  ;; Rows vary a lot in cost (sky is cheap, spheres are expensive), so
  ;; threads take rows one at a time rather than a fixed block each.
  (define (worker)
    (let loop ()
      (define y (take-row! next))
      (when (< y height)
        (render-row! pixels y width height samples camera world)
        (loop))))
  (define others (for/list ([_ (in-range (- threads 1))]) (future worker)))
  ;; Touching a future that raised an exception raises it again here.
  (worker)
  (for-each touch others)
  img)

;; Renders the world with samples rays per pixel, in parallel across all
;; available cores.
(define (render width height samples camera world)
  (render/threads (processor-count) width height samples camera world))
