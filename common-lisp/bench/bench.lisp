;;;; Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with
;;;; 50 samples per pixel.

(defpackage #:raytracer-bench
  (:use #:cl)
  (:import-from #:raytracer #:cpu-count #:render-with-threads #:use-large-nursery)
  (:import-from #:raytracer-tests #:scene-camera #:scene-world)
  (:export #:main))

(in-package #:raytracer-bench)

(defun main (&optional (iterations 20) (threads (cpu-count)))
  (use-large-nursery)
  (let ((camera (scene-camera 100 100))
        (world (scene-world)))
    (flet ((run () (render-with-threads threads 100 100 50 camera world)))
      (run)
      (let ((start (get-internal-real-time)))
        (loop repeat iterations do (run))
        (format *error-output* "~D iterations on ~D threads: ~,2F ms/op~%"
                iterations threads
                (/ (- (get-internal-real-time) start)
                   (/ internal-time-units-per-second 1000)
                   iterations 1d0))))))
