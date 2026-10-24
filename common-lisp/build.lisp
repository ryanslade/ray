;;;; Loads ASDF and raytracer.asd, failing on any compiler warning, including
;;;; style warnings. Load it before using the systems.

(require :asdf)

(setf asdf:*compile-file-warnings-behaviour* :error
      asdf:*compile-file-failure-behaviour* :error)

;;; Optimisation notes, such as where a double is boxed, aren't warnings.
;;; Remove this to see them.
(declaim (sb-ext:muffle-conditions sb-ext:compiler-note))

;;; Reports an unhandled error, such as a failed compilation, without a
;;; backtrace.
(setf sb-ext:*invoke-debugger-hook*
      (lambda (condition hook)
        (declare (ignore hook))
        (format *error-output* "~&~A~%" condition)
        (sb-ext:exit :code 1 :abort t)))

(asdf:load-asd (merge-pathnames "raytracer.asd" *load-truename*))

(defun save-executable (path)
  "Saves an executable that renders the example scene to its argument, or to
out.png."
  (ensure-directories-exist path)
  (sb-ext:save-lisp-and-die
   path
   :executable t
   ;; Leaves the command line to the program rather than parsing SBCL's
   ;; runtime options from it.
   :save-runtime-options t
   :toplevel (lambda ()
               (apply (find-symbol "MAIN" "RAYTRACER")
                      (rest sb-ext:*posix-argv*))
               (sb-ext:exit))))
