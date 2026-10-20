(in-package #:raytracer-tests)

(deftest deterministic-across-threads
  (let* ((camera (scene-camera 40 30))
         (world (scene-world))
         (expected (render-with-threads 1 40 30 8 camera world)))
    (dolist (threads '(2 4 7))
      (check (equalp expected (render-with-threads threads 40 30 8 camera world))
             (format nil "~D threads" threads)))))

(defun read-bytes (path)
  (with-open-file (in path :element-type '(unsigned-byte 8))
    (let ((bytes (make-array (file-length in) :element-type '(unsigned-byte 8))))
      (read-sequence bytes in)
      bytes)))

(defun write-bytes (bytes path)
  (with-open-file (out path :direction :output :element-type '(unsigned-byte 8)
                            :if-exists :supersede)
    (write-sequence bytes out)))

;;; Renders the test scene and compares it with tests/golden.ppm.
;;;
;;; After an intentional change to the output, run with UPDATE_GOLDEN=1 to
;;; accept it. On a mismatch the rendered image is written to
;;; tests/golden.actual.ppm for inspection.
(deftest golden-image
  (let ((actual (to-ppm (render 200 200 100 (scene-camera 200 200) (scene-world))))
        (golden (asdf:system-relative-pathname "raytracer" "tests/golden.ppm")))
    (if (sb-ext:posix-getenv "UPDATE_GOLDEN")
        (write-bytes actual golden)
        (unless (equalp actual (read-bytes golden))
          (let ((out (asdf:system-relative-pathname "raytracer"
                                                    "tests/golden.actual.ppm")))
            (write-bytes actual out)
            (check nil (format nil "the rendered image doesn't match ~A; wrote it to ~A"
                               golden out)))))))
