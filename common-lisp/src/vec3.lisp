;;;; Vectors of three doubles, also used for colours (as r, g and b).

(in-package #:raytracer)

;;; Typed slots are stored unboxed, and the operations below are inlined, so
;;; the only cost of a vector is allocating it.
(declaim (inline vec3))
(defstruct (vec3 (:constructor vec3 (x y z)) (:conc-name v) (:copier nil))
  (x 0d0 :type double-float :read-only t)
  (y 0d0 :type double-float :read-only t)
  (z 0d0 :type double-float :read-only t))

(sb-ext:define-load-time-global +zero+ (vec3 0d0 0d0 0d0))
(sb-ext:define-load-time-global +black+ +zero+)
(sb-ext:define-load-time-global +white+ (vec3 1d0 1d0 1d0))
(declaim (type vec3 +zero+ +black+ +white+))

(declaim (inline fsqrt v+ v- v* v/ vscale vneg dot cross vlength unit
                 random-in-unit-sphere random-in-unit-disk))

(defun fsqrt (x)
  "The square root of a double, NaN if it is negative. SQRT would return a
complex number instead, so it can't be compiled to a single instruction unless
X is known to be non-negative."
  (declare (double-float x))
  (sb-kernel:%sqrt x))

;;; The arithmetic is written with two arguments to each operation, in the
;;; same order as the other versions, so that the results round the same way.

(defun v+ (a b)
  (vec3 (+ (vx a) (vx b)) (+ (vy a) (vy b)) (+ (vz a) (vz b))))

(defun v- (a b)
  (vec3 (- (vx a) (vx b)) (- (vy a) (vy b)) (- (vz a) (vz b))))

(defun v* (a b)
  "Component-wise multiplication."
  (vec3 (* (vx a) (vx b)) (* (vy a) (vy b)) (* (vz a) (vz b))))

(defun v/ (v s)
  (declare (double-float s))
  (vec3 (/ (vx v) s) (/ (vy v) s) (/ (vz v) s)))

(defun vscale (s v)
  "V multiplied by the scalar S."
  (declare (double-float s))
  (vec3 (* s (vx v)) (* s (vy v)) (* s (vz v))))

(defun vneg (v)
  (vec3 (- (vx v)) (- (vy v)) (- (vz v))))

(defun dot (a b)
  (+ (+ (* (vx a) (vx b)) (* (vy a) (vy b))) (* (vz a) (vz b))))

(defun cross (a b)
  (vec3 (- (* (vy a) (vz b)) (* (vz a) (vy b)))
        (- (* (vz a) (vx b)) (* (vx a) (vz b)))
        (- (* (vx a) (vy b)) (* (vy a) (vx b)))))

(defun vlength (v)
  (fsqrt (dot v v)))

(defun unit (v)
  (v/ v (vlength v)))

;;; SBCL allocates every vector a function returns, even when it is inlined
;;; and the vector is only an argument to another operation, as in
;;; (v- (v+ a (vscale s b)) c). These compiler macros rewrite such nested
;;; operations into a single VEC3 call, each component computed from the
;;; operands' components with the same arithmetic in the same order, so only
;;; the result is allocated. Operands that aren't vector operations are still
;;; evaluated once each, in their original order.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *fusible* '(v+ v- v* v/ vscale vneg))

  (defvar *bindings*)

  (defun fusible-p (form)
    (and (consp form) (member (first form) *fusible*)))

  (defun scalar-operand (form)
    "A form for the scalar FORM, binding it to a variable unless it is a
constant."
    (if (constantp form)
        form
        (let ((var (gensym "S")))
          (push (list var form) *bindings*)
          var)))

  (defun components (form)
    "Three forms computing the components of the vector FORM."
    (flet ((each (op a b)
             (mapcar (lambda (a b) (list op a b)) a b)))
      (case (and (fusible-p form) (first form))
        (v+ (each '+ (components (second form)) (components (third form))))
        (v- (each '- (components (second form)) (components (third form))))
        (v* (each '* (components (second form)) (components (third form))))
        (v/ (let* ((v (components (second form)))
                   (s (scalar-operand (third form))))
              (each '/ v (list s s s))))
        (vscale (let* ((s (scalar-operand (second form)))
                       (v (components (third form))))
                  (each '* (list s s s) v)))
        (vneg (mapcar (lambda (c) (list '- c)) (components (second form))))
        (t (let ((var (gensym "V")))
             (push (list var form) *bindings*)
             (list `(vx ,var) `(vy ,var) `(vz ,var))))))))

(macrolet ((fuse (name lambda-list)
             `(define-compiler-macro ,name (&whole form ,@lambda-list)
                (declare (ignore ,@lambda-list))
                ;; Declining leaves the call to be inlined as usual.
                (if (notany #'fusible-p (rest form))
                    form
                    (let* ((*bindings* '())
                           (components (components form)))
                      `(let* ,(reverse *bindings*)
                         (vec3 ,@components)))))))
  (fuse v+ (a b))
  (fuse v- (a b))
  (fuse v* (a b))
  (fuse v/ (v s))
  (fuse vscale (s v))
  (fuse vneg (v)))

(defun random-in-unit-sphere (rng)
  "Rejection sampling: pick points in the enclosing cube until one lands
inside."
  (loop
    (let ((x (- (* 2d0 (next-f64 rng)) 1d0))
          (y (- (* 2d0 (next-f64 rng)) 1d0))
          (z (- (* 2d0 (next-f64 rng)) 1d0)))
      (when (< (+ (+ (* x x) (* y y)) (* z z)) 1d0)
        (return (vec3 x y z))))))

(defun random-in-unit-disk (rng)
  (loop
    (let ((x (- (* 2d0 (next-f64 rng)) 1d0))
          (y (- (* 2d0 (next-f64 rng)) 1d0)))
      (when (< (+ (* x x) (* y y)) 1d0)
        (return (vec3 x y 0d0))))))
