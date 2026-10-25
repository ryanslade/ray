#lang racket/base

;; Compiled without the checks on primitive operations, such as that flonum
;; operations get flonums and that indices are in bounds; see the README.
(#%declare #:unsafe)

(require racket/contract/base racket/flonum "ray.rkt" "rng.rkt" "vec3.rkt")

(provide (contract-out [lambertian (-> vec3? lambertian?)]
                       [metal (-> vec3? real? metal?)]
                       [dielectric (-> real? dielectric?)])
         lambertian? lambertian-albedo metal? metal-albedo metal-fuzz
         dielectric? dielectric-ref-index material? refract scatter)

;; albedo is the colour that scattered light is multiplied by.
(struct lambertian (albedo) #:authentic)

;; fuzz is clamped to [0, 1]: 0 is a perfect mirror.
(struct metal (albedo fuzz)
  #:authentic
  #:guard (λ (albedo fuzz name)
            (values albedo (flmax 0.0 (flmin (real->double-flonum fuzz) 1.0)))))

(struct dielectric (ref-index)
  #:authentic
  #:guard (λ (ref-index name) (real->double-flonum ref-index)))

(define (material? v)
  (or (lambertian? v) (metal? v) (dielectric? v)))

(define (reflect v n)
  (v- v (vscale (fl* 2.0 (dot v n)) n)))

;; The refracted ray's direction, or #f on total internal reflection.
(define (refract v n ni-over-nt)
  (define uv (unit v))
  (define dt (dot uv n))
  (define discriminant
    (fl- 1.0 (fl* (fl* ni-over-nt ni-over-nt) (fl- 1.0 (fl* dt dt)))))
  (and (fl> discriminant 0.0)
       (v- (vscale ni-over-nt (v- uv (vscale dt n)))
           (vscale (flsqrt discriminant) n))))

;; Schlick's approximation for reflectance at a given angle.
(define (schlick cosine ref-index)
  (let* ([r0 (fl/ (fl- 1.0 ref-index) (fl+ 1.0 ref-index))]
         [r0 (fl* r0 r0)]
         ;; Multiplied out rather than using flexpt, to match the other
         ;; versions' golden image.
         [x (fl- 1.0 cosine)]
         [x2 (fl* x x)])
    (fl+ r0 (fl* (fl* (fl* (fl- 1.0 r0) x2) x2) x))))

;; Two values: the scattered ray and the colour it is multiplied by, or #f and
;; #f if the ray is absorbed.
(define (scatter material ray-in h rng)
  (define point (hit-point h))
  (define normal (hit-normal h))
  (cond
    [(lambertian? material)
     (define target (v+ (v+ point normal) (random-in-unit-sphere rng)))
     (values (ray point (v- target point)) (lambertian-albedo material))]
    [(metal? material)
     (define reflected (reflect (unit (ray-direction ray-in)) normal))
     (define direction
       (v+ reflected (vscale (metal-fuzz material) (random-in-unit-sphere rng))))
     (if (fl> (dot direction normal) 0.0)
         (values (ray point direction) (metal-albedo material))
         (values #f #f))]
    [else
     (define ref-index (dielectric-ref-index material))
     (define d (ray-direction ray-in))
     (define d-dot-n (dot d normal))
     (define outside (fl> d-dot-n 0.0))
     (define refracted
       (if outside
           (refract d (vneg normal) ref-index)
           (refract d normal (fl/ 1.0 ref-index))))
     (define cosine
       (if outside
           (fl/ (fl* ref-index d-dot-n) (vlength d))
           (fl/ (fl- d-dot-n) (vlength d))))
     (values (ray point
                  ;; Only draws a random number when the ray can refract.
                  (if (and refracted (fl>= (next-f64 rng) (schlick cosine ref-index)))
                      refracted
                      (reflect d normal)))
             white)]))
