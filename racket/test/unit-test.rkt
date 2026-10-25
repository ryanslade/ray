#lang racket/base

(require file/gunzip racket/flonum rackunit "../src/raytracer.rkt")

(define (close? a b)
  (fl< (vlength (v- a b)) 1e-9))

(test-case "vec3 arithmetic"
  (define a (vec3 1.0 2.0 3.0))
  (define b (vec3 4.0 5.0 6.0))
  (check close? (v+ a b) (vec3 5.0 7.0 9.0))
  (check close? (vscale 2.0 a) (vec3 2.0 4.0 6.0))
  (check-equal? (dot a b) 32.0)
  (check close? (cross a b) (vec3 -3.0 6.0 -3.0))
  (check-= (vlength (unit b)) 1.0 1e-9))

(test-case "the generator's floats are in [0, 1)"
  (define r (make-rng 1))
  (for ([_ (in-range 10000)])
    (define f (next-f64 r))
    (check-true (and (>= f 0.0) (< f 1.0)))))

(test-case "the same seed gives the same sequence"
  (define a (make-rng 42))
  (define b (make-rng 42))
  (check-equal? (for/list ([_ 100]) (next-u64 a))
                (for/list ([_ 100]) (next-u64 b))))

(test-case "the generator matches SplitMix64"
  ;; The first outputs for seed 0 from the reference implementation.
  (define r (make-rng 0))
  (check-equal? (next-u64 r) #xe220a8397b1dcdaf)
  (check-equal? (next-u64 r) #x6e789e6aa1b965f4))

(test-case "sphere hits"
  (define m (dielectric 1.5))
  (define s (sphere (vec3 0.0 0.0 -1.0) 0.5 m))
  (define towards (ray zero (vec3 0.0 0.0 -1.0)))
  (define h (sphere-hit s towards 0.0 +inf.0))
  (check-pred hit? h)
  (check-equal? (hit-distance h) 0.5)
  (check-equal? (hit-normal h) (vec3 0.0 0.0 1.0))
  (check-eq? (hit-material h) m)
  (define far (sphere-hit s towards 0.6 +inf.0))
  (check-equal? (and far (hit-distance far)) 1.5 "far side")
  (check-false (sphere-hit s (ray zero (vec3 0.0 1.0 0.0)) 0.0 +inf.0)))

(test-case "the world finds the closest hit"
  (define m (dielectric 1.5))
  (define w (make-world (list (sphere (vec3 0.0 0.0 -5.0) 1.0 m)
                              (sphere (vec3 0.0 0.0 -2.0) 0.5 m))))
  (define h (world-hit w (ray zero (vec3 0.0 0.0 -1.0)) 0.0 +inf.0))
  (check-equal? (and h (hit-distance h)) 1.5)
  (check-false (world-hit w (ray zero (vec3 0.0 1.0 0.0)) 0.0 +inf.0)))

(define (coord rng scale)
  (fl* scale (fl- (fl* 2.0 (next-f64 rng)) 1.0)))

(test-case "the world finds the same hit as each sphere in turn"
  ;; world-hit has its own copy of the intersection arithmetic, which must
  ;; find exactly the hit that sphere-hit on each sphere in turn would.
  (define rng (make-rng 1))
  (define m (dielectric 1.5))
  (define spheres
    (for/list ([_ 23])
      (sphere (vec3 (coord rng 3.0) (coord rng 3.0) (coord rng 3.0))
              (fl+ 0.1 (flabs (coord rng 1.0)))
              m)))
  (define rays
    (for/list ([_ 2000])
      (ray (vec3 (coord rng 5.0) (coord rng 5.0) (coord rng 5.0))
           (vec3 (coord rng 1.0) (coord rng 1.0) (coord rng 1.0)))))
  (define world (make-world spheres))
  (define mismatches
    (for/sum ([r (in-list rays)])
      (define want
        (for/fold ([want #f]) ([s (in-list spheres)])
          (or (sphere-hit s r 0.001 (if want (hit-distance want) max-distance)) want)))
      (if (equal? want (world-hit world r 0.001 max-distance)) 0 1)))
  (check-equal? mismatches 0))

(test-case "total internal reflection"
  (check-false (refract (vec3 1.0 -0.1 0.0) (vec3 0.0 1.0 0.0) 1.5)))

(test-case "refracts head on"
  (define down (vec3 0.0 -1.0 0.0))
  (define r (refract down (vec3 0.0 1.0 0.0) (fl/ 1.0 1.5)))
  (check-true (and r (close? down r))))

(test-case "metal's fuzz is clamped"
  (check-equal? (metal-fuzz (metal white 2.0)) 1.0)
  (check-equal? (metal-fuzz (metal white -1.0)) 0.0))

(test-case "set-pixel! clamps"
  (define img (make-image 3 1))
  (set-pixel! img 1 0 (vec3 2.0 0.5 -1.0))
  ;; f64::min in Rust ignores NaN, so NaN becomes 255.
  (set-pixel! img 2 0 (vec3 +nan.0 0.0 0.0))
  (check-equal? (pixel img 0 0) '(0 0 0))
  (check-equal? (pixel img 1 0) '(255 127 0))
  (check-equal? (pixel img 2 0) '(255 0 0))
  (check-exn exn:fail? (λ () (pixel img 3 0))))

(test-case "PPM header"
  (define ppm (image->ppm (make-image 3 2)))
  (check-equal? (subbytes ppm 0 11) #"P6\n3 2\n255\n")
  (check-equal? (bytes-length ppm) (+ 11 (* 3 2 3))))

(test-case "checksums"
  (check-equal? (crc32 #"123456789") #xCBF43926)
  (check-equal? (crc32 #"1234" #"56789") #xCBF43926)
  (check-equal? (adler32 #"Wikipedia") #x11E60398))

(define (u32-at bs pos)
  (integer-bytes->integer bs #f #t pos (+ pos 4)))

;; Splits a PNG into its chunks, as (type . data) pairs, checking each CRC.
(define (png-chunks png)
  (let loop ([pos 8])
    (if (< pos (bytes-length png))
        (let* ([len (u32-at png pos)]
               [type (subbytes png (+ pos 4) (+ pos 8))]
               [data (subbytes png (+ pos 8) (+ pos 8 len))])
          (check-equal? (u32-at png (+ pos 8 len)) (crc32 type data)
                        (format "~a CRC" type))
          (cons (cons (bytes->string/latin-1 type) data) (loop (+ pos 12 len))))
        '())))

;; Decodes a zlib stream with file/gunzip, checking its header and checksum.
(define (zlib-decode z)
  (check-equal? (bitwise-and (bytes-ref z 0) #x0F) 8 "deflate")
  (check-equal? (remainder (+ (* 256 (bytes-ref z 0)) (bytes-ref z 1)) 31) 0
                "header check bits")
  (define in (open-input-bytes z))
  (read-bytes 2 in)
  (define out (open-output-bytes))
  (inflate in out)
  (define data (get-output-bytes out))
  (check-equal? (integer-bytes->integer (read-bytes 4 in) #f #t) (adler32 data))
  data)

(test-case "PNG"
  (define width 200)
  (define height 120)
  (define img (make-image width height))
  (for* ([y (in-range height)] [x (in-range width)])
    (set-pixel! img x y (vec3 (fl/ (exact->inexact x) (exact->inexact width))
                              (fl/ (exact->inexact y) (exact->inexact height))
                              (fl/ (exact->inexact (modulo (+ x y) 7)) 7.0))))
  (define png (image->png img))
  (define chunks (png-chunks png))
  (check-equal? (subbytes png 0 8) (bytes #x89 80 78 71 13 10 26 10))
  ;; IEND's CRC is the same in every PNG.
  (check-equal? (subbytes png (- (bytes-length png) 12))
                (bytes 0 0 0 0 73 69 78 68 #xAE #x42 #x60 #x82))
  (check-equal? (map car chunks) '("IHDR" "IDAT" "IEND"))
  (define header (cdr (car chunks)))
  (define raw (zlib-decode (cdr (cadr chunks))))
  (define row-bytes (+ 1 (* 3 width)))
  (check-equal? (u32-at header 0) width)
  (check-equal? (u32-at header 4) height)
  (check-equal? (subbytes header 8) (bytes 8 2 0 0 0) "8-bit RGB")
  (check-equal? (bytes-length raw) (* row-bytes height))
  (define bad
    (for*/list ([y (in-range height)]
                [x (in-range width)]
                #:unless (let ([i (+ (* y row-bytes) 1 (* 3 x))])
                           (and (zero? (bytes-ref raw (* y row-bytes)))
                                (equal? (pixel img x y)
                                        (bytes->list (subbytes raw i (+ i 3)))))))
      (list x y)))
  (check-equal? bad '() "pixels that don't match"))

(test-case "building a scene checks its arguments"
  ;; The rendering code is compiled without checks, so values must be checked
  ;; on the way in.
  (define m (dielectric 1.5))
  (check-exn exn:fail:contract? (λ () (sphere (vec3 0.0 0.0 0.0) 'big m)))
  (check-exn exn:fail:contract? (λ () (sphere (vector 0 0 0) 1.0 m)))
  (check-exn exn:fail:contract? (λ () (sphere (vec3 0.0 0.0 0.0) 1.0 white)))
  (check-exn exn:fail:contract? (λ () (lambertian 0.5)))
  (check-exn exn:fail:contract? (λ () (make-world (list m))))
  (check-exn exn:fail:contract? (λ () (render/threads 0 1 1 1 #f #f))))
