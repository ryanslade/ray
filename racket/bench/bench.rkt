#lang racket/base

;; Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with
;; 50 samples per pixel.

(require racket/future "../src/raytracer.rkt" "../test/scene.rkt")

(define (main iterations threads)
  (define camera (scene-camera 100 100))
  (define world (scene-world))
  (define (run) (render/threads threads 100 100 50 camera world))
  (run)
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range iterations)]) (run))
  (eprintf "~a iterations on ~a threads: ~a ms/op\n" iterations threads
           (real->decimal-string
            (/ (- (current-inexact-milliseconds) start) iterations) 2)))

(module+ main
  (require racket/cmdline)
  (command-line
   #:args ([iterations "20"] [threads (number->string (processor-count))])
   (main (string->number iterations) (string->number threads))))
