#lang s-exp "lang.rkt"

;; Vectors of three flonums, also used for colours (as r, g and b).

(require "rng.rkt")

(provide vec3 vec3? vx vy vz define-xyz v+ v- v* v/ vscale vneg vset! dot cross vlength
         unit zero black white random-in-unit-sphere random-in-unit-disk)

;; A vector is an flvector, which holds its elements unboxed, so a vector is a
;; single allocation, where a structure would also allocate each of its
;; flonums. Calling flvector would box its arguments, though, so vectors are
;; made empty and then filled in.

(define (vec3? v)
  (and (flvector? v) (= (flvector-length v) 3)))

;; Inlined, so that the components aren't boxed to be returned.
(define-inline (vx v) (flvector-ref v 0))
(define-inline (vy v) (flvector-ref v 1))
(define-inline (vz v) (flvector-ref v 2))

;; Defines x, y and z as v's components. Separate definitions, since flonums
;; bound with define-values are boxed.
(define-syntax-rule (define-xyz (x y z) v)
  (begin (define t v) (define x (vx t)) (define y (vy t)) (define z (vz t))))

;; As procedures, the operations would allocate every vector they return, even
;; one that is only an argument to another operation, as in
;; (v- (v+ a (vscale s b)) c). So they are macros that expand such nested
;; expressions into a single vector, each component computed from the
;; operands' components with the same arithmetic in the same order, so only
;; the result is allocated. Operands that aren't vector operations are still
;; evaluated once each, in their original order. Used as values rather than
;; called, the operations are ordinary procedures.

(begin-for-syntax
  ;; A vector operation, bound as its own macro. kinds says whether each
  ;; operand is a vector or a scalar, and component makes the result's
  ;; component on an axis from the operands' components on that axis (a
  ;; scalar's components are all itself).
  (struct vector-op (kinds component proc)
    #:property prop:procedure
    (λ (op stx)
      (if (identifier? stx)
          (vector-op-proc op)
          #`(let ([v (make-flvector 3)]) (vset! v #,stx) v))))

  ;; Three expressions computing the components of the vector expression
  ;; form. bind! binds an operand to a variable, which it returns.
  (define (components form bind!)
    (define op (syntax-case form ()
                 [(head . _) (identifier? #'head) (syntax-local-value #'head (λ () #f))]
                 [_ #f]))
    (define operands (if (vector-op? op) (cdr (syntax->list form)) '()))
    (cond
      [(not (vector-op? op))
       (define v (bind! form))
       (for/list ([axis 3]) #`(flvector-ref #,v #,axis))]
      [(not (= (length operands) (length (vector-op-kinds op))))
       (raise-syntax-error #f "wrong number of operands" form)]
      [else
       (define cs
         (for/list ([kind (in-list (vector-op-kinds op))] [e (in-list operands)])
           (if (eq? kind 'vector)
               (components e bind!)
               (let ([s (if (real? (syntax-e e))
                            (datum->syntax e (exact->inexact (syntax-e e)))
                            (bind! e))])
                 (list s s s)))))
       (for/list ([axis 3])
         (apply (vector-op-component op) axis (map (λ (c) (list-ref c axis)) cs)))])))

;; Stores the vector expression e in the vector dest without allocating.
;; Each component of e only depends on its operands' components on the same
;; axis, so dest can be one of them.
(define-syntax (vset! stx)
  (syntax-case stx ()
    [(_ dest e)
     (let* ([bindings '()]
            [cs (components #'e (λ (e)
                                  (define var (car (generate-temporaries '(v))))
                                  (set! bindings (cons #`[#,var #,e] bindings))
                                  var))])
       ;; components binds the operands as it goes, so this is a let*.
       #`(let* ([d dest] #,@(reverse bindings))
           #,@(for/list ([c (in-list cs)] [axis (in-naturals)])
                #`(flvector-set! d #,axis #,c))))]))

;; Defines name as a vector operation, whose component on each axis is the
;; flo expression body of the operands' components, and as a procedure.
(define-syntax-rule (define-vector-op (name [operand kind] ...) body)
  (begin
    (define-syntax name
      (vector-op '(kind ...)
                 (λ (axis operand ...)
                   (with-syntax ([operand operand] ...) #'(flo body)))
                 #'proc))
    (define (proc operand ...) (name operand ...))))

(define-vector-op (v+ [a vector] [b vector]) (+ a b))
(define-vector-op (v- [a vector] [b vector]) (- a b))
;; Component-wise multiplication.
(define-vector-op (v* [a vector] [b vector]) (* a b))
(define-vector-op (v/ [v vector] [s scalar]) (/ v s))
;; v multiplied by the scalar s.
(define-vector-op (vscale [s scalar] [v vector]) (* s v))
(define-vector-op (vneg [v vector]) (- v))

(define-syntax vec3
  (vector-op '(scalar scalar scalar) (λ (axis . xyz) (list-ref xyz axis)) #'vec3/proc))
(define (vec3/proc x y z) (vec3 x y z))

(define-inline (dot a b)
  (flo (+ (* (vx a) (vx b)) (* (vy a) (vy b)) (* (vz a) (vz b)))))
(define-inline (vlength v) (flsqrt (dot v v)))
(define-inline (unit v) (v/ v (vlength v)))

(define (cross a b)
  (vec3 (flo (- (* (vy a) (vz b)) (* (vz a) (vy b))))
        (flo (- (* (vz a) (vx b)) (* (vx a) (vz b))))
        (flo (- (* (vx a) (vy b)) (* (vy a) (vx b))))))

(define zero (vec3 0 0 0))
(define black zero)
(define white (vec3 1 1 1))

;; Defines name as rejection sampling: picking a point in the cube or square
;; with coordinates (c ...) until one lands inside the unit sphere or disk,
;; which it returns as v.
(define-syntax-rule (define-random-in-unit (name rng) (c ...) v)
  (define (name rng)
    (let* ([c (flo (- (* 2 (next-f64 rng)) 1))] ...)
      (if (flo (< (+ (* c c) ...) 1)) v (name rng)))))

(define-random-in-unit (random-in-unit-sphere rng) (x y z) (vec3 x y z))
(define-random-in-unit (random-in-unit-disk rng) (x y) (vec3 x y 0))
