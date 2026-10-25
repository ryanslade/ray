#lang racket/base

(require racket/file racket/runtime-path rackunit "../src/raytracer.rkt" "scene.rkt")

(define-runtime-path golden "golden.ppm")
(define-runtime-path golden-actual "golden.actual.ppm")

(test-case "the image doesn't depend on the number of threads"
  (define camera (scene-camera 40 30))
  (define world (scene-world))
  (define expected (image->ppm (render/threads 1 40 30 8 camera world)))
  (for ([threads '(2 4 7)])
    (check-equal? (image->ppm (render/threads threads 40 30 8 camera world)) expected
                  (format "~a threads" threads))))

;; Renders the test scene and compares it with test/golden.ppm.
;;
;; After an intentional change to the output, run with UPDATE_GOLDEN=1 to
;; accept it. On a mismatch the rendered image is written to
;; test/golden.actual.ppm for inspection.
(test-case "the test scene matches the golden image"
  (define actual (image->ppm (render 200 200 100 (scene-camera 200 200) (scene-world))))
  (cond
    [(getenv "UPDATE_GOLDEN")
     (call-with-output-file golden #:exists 'truncate/replace
       (λ (out) (write-bytes actual out)))]
    [(not (equal? actual (file->bytes golden)))
     (call-with-output-file golden-actual #:exists 'truncate/replace
       (λ (out) (write-bytes actual out)))
     (fail (format "the rendered image doesn't match ~a; wrote it to ~a"
                   golden golden-actual))]))
