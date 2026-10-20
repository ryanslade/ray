;;;; Just enough of a test framework to avoid needing one.

(in-package #:raytracer-tests)

(defvar *tests* '()
  "The names of the tests, most recently defined first.")

(defvar *failures* 0)

(defmacro deftest (name &body body)
  `(progn
     (defun ,name () ,@body)
     (pushnew ',name *tests*)))

(defmacro check (form &optional (description `',form))
  "Records a failure, with DESCRIPTION, if FORM returns false."
  `(unless ,form
     (incf *failures*)
     (format *error-output* "~&  failed: ~A~%" ,description)))

(defmacro signals (condition-type &body body)
  "True if BODY signals a condition of CONDITION-TYPE."
  `(handler-case (progn ,@body nil)
     (,condition-type () t)))

(defun run ()
  "Runs every test, reporting failures on *ERROR-OUTPUT*. True if they all
passed."
  (let ((failed 0))
    (dolist (test (reverse *tests*))
      (let ((*failures* 0))
        (format *error-output* "~&~(~A~)~%" test)
        (handler-case (funcall test)
          (error (e)
            (incf *failures*)
            (format *error-output* "~&  error: ~A~%" e)))
        (when (plusp *failures*)
          (incf failed))))
    (format *error-output* "~&~D of ~D tests passed~%"
            (- (length *tests*) failed) (length *tests*))
    (zerop failed)))
