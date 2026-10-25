#lang racket/base

;; Vectors of three flonums, also used for colours (as r, g and b).

;; Compiled without the checks on primitive operations, such as that flonum
;; operations get flonums and that indices are in bounds; see the README.
(#%declare #:unsafe)

(require (for-syntax racket/base) racket/flonum racket/performance-hint "rng.rkt")

(provide vec3 vec3? vx vy vz v+ v- v* v/ vscale vneg dot cross vlength unit
         zero black white random-in-unit-sphere random-in-unit-disk)

;; A vector is an flvector, which holds its elements unboxed, so a vector is a
;; single allocation, where a structure would also allocate each of its
;; flonums. Calling flvector would box its arguments, though, so vectors are
;; made empty and then filled in.
;;
;; The arithmetic is written with two arguments to each operation, in the
;; same order as the other versions, so that the results round the same way.

(define (vec3? v)
  (and (flvector? v) (= (flvector-length v) 3)))

(define-syntax-rule (make-vec3 x y z)
  (let ([v (make-flvector 3)])
    (flvector-set! v 0 x)
    (flvector-set! v 1 y)
    (flvector-set! v 2 z)
    v))

;; Inlined, so that the components aren't boxed to be returned.
(define-inline (vx v) (flvector-ref v 0))
(define-inline (vy v) (flvector-ref v 1))
(define-inline (vz v) (flvector-ref v 2))

;; As procedures, the operations would allocate every vector they return, even
;; one that is only an argument to another operation, as in
;; (v- (v+ a (vscale s b)) c). So the operations are macros that expand such
;; nested expressions into a single vector, each component computed from the
;; operands' components with the same arithmetic in the same order, so only
;; the result is allocated. Operands that aren't vector operations are still
;; evaluated once each, in their original order. Used as values rather than
;; called, the operations are ordinary procedures.

(begin-for-syntax
  ;; The name of the vector operation that form applies, or #f.
  (define (fusible-op form)
    (syntax-case form ()
      [(head . _)
       (identifier? #'head)
       (for/first ([op (in-list (list #'vec3 #'v+ #'v- #'v* #'v/ #'vscale #'vneg))]
                   #:when (free-identifier=? #'head op))
         (syntax-e op))]
      [_ #f]))

  ;; Three expressions computing the components of the vector expression
  ;; form. bind! binds an operand to a variable, which it returns.
  (define (components form bind!)
    (define (scalar e) (if (flonum? (syntax-e e)) e (bind! e)))
    (define (each op as bs)
      (map (λ (a b) (quasisyntax/loc form (#,op #,a #,b))) as bs))
    (syntax-case form ()
      [(_ x y z)
       (eq? (fusible-op form) 'vec3)
       (let* ([x (scalar #'x)] [y (scalar #'y)] [z (scalar #'z)])
         (list x y z))]
      [(_ a b)
       (memq (fusible-op form) '(v+ v- v*))
       (let* ([as (components #'a bind!)]
              [bs (components #'b bind!)])
         (each (case (fusible-op form) [(v+) #'fl+] [(v-) #'fl-] [(v*) #'fl*]) as bs))]
      [(_ v s)
       (eq? (fusible-op form) 'v/)
       (let* ([vs (components #'v bind!)]
              [s (scalar #'s)])
         (each #'fl/ vs (list s s s)))]
      [(_ s v)
       (eq? (fusible-op form) 'vscale)
       (let* ([s (scalar #'s)]
              [vs (components #'v bind!)])
         (each #'fl* (list s s s) vs))]
      [(_ v)
       (eq? (fusible-op form) 'vneg)
       (map (λ (c) #`(fl- #,c)) (components #'v bind!))]
      [_
       (let ([v (bind! form)])
         (list #`(flvector-ref #,v 0) #`(flvector-ref #,v 1) #`(flvector-ref #,v 2)))]))

  ;; An expression that binds the operands of the vector expressions forms
  ;; and passes their components to finish, which makes the result.
  (define (fuse forms finish)
    (define bindings '())
    (define (bind! e)
      (define var (car (generate-temporaries '(v))))
      (set! bindings (cons #`[#,var #,e] bindings))
      var)
    ;; Components binds the operands as it goes, so this is a let*.
    (define result (apply finish (for/list ([form (in-list forms)])
                                   (components form bind!))))
    #`(let* #,(reverse bindings) #,result)))

;; Defines name as a vector operation that fuses with the vector operations
;; in its operands, and proc as the same operation as a procedure.
(define-syntax-rule (define-fused name proc (arg ...))
  (begin
    (define-syntax (name stx)
      (syntax-case stx ()
        [id (identifier? #'id) #'proc]
        [(_ arg ...) (fuse (list stx) (λ (cs) #`(make-vec3 #,@cs)))]))
    (define (proc arg ...) (name arg ...))))

(define-fused vec3 vec3/proc (x y z))
(define-fused v+ v+/proc (a b))
(define-fused v- v-/proc (a b))
;; Component-wise multiplication.
(define-fused v* v*/proc (a b))
(define-fused v/ v//proc (v s))
;; v multiplied by the scalar s.
(define-fused vscale vscale/proc (s v))
(define-fused vneg vneg/proc (v))

(define-syntax (dot stx)
  (syntax-case stx ()
    [id (identifier? #'id) #'dot/proc]
    [(_ a b)
     (fuse (list #'a #'b)
           (λ (as bs)
             (with-syntax ([(ax ay az) as] [(bx by bz) bs])
               #'(fl+ (fl+ (fl* ax bx) (fl* ay by)) (fl* az bz)))))]))
(define (dot/proc a b) (dot a b))

(define-syntax (vlength stx)
  (syntax-case stx ()
    [id (identifier? #'id) #'vlength/proc]
    [(_ v) #'(let ([t v]) (flsqrt (dot t t)))]))
(define (vlength/proc v) (vlength v))

(define-syntax (unit stx)
  (syntax-case stx ()
    [id (identifier? #'id) #'unit/proc]
    [(_ v) #'(let ([t v]) (v/ t (vlength t)))]))
(define (unit/proc v) (unit v))

(define (cross a b)
  (vec3 (fl- (fl* (vy a) (vz b)) (fl* (vz a) (vy b)))
        (fl- (fl* (vz a) (vx b)) (fl* (vx a) (vz b)))
        (fl- (fl* (vx a) (vy b)) (fl* (vy a) (vx b)))))

(define zero (vec3 0.0 0.0 0.0))
(define black zero)
(define white (vec3 1.0 1.0 1.0))

(define-inline (random-coord rng)
  (fl- (fl* 2.0 (next-f64 rng)) 1.0))

;; Rejection sampling: picks points in the enclosing cube until one lands
;; inside.
(define (random-in-unit-sphere rng)
  (let* ([x (random-coord rng)]
         [y (random-coord rng)]
         [z (random-coord rng)])
    (if (fl< (fl+ (fl+ (fl* x x) (fl* y y)) (fl* z z)) 1.0)
        (vec3 x y z)
        (random-in-unit-sphere rng))))

(define (random-in-unit-disk rng)
  (let* ([x (random-coord rng)]
         [y (random-coord rng)])
    (if (fl< (fl+ (fl* x x) (fl* y y)) 1.0)
        (vec3 x y 0.0)
        (random-in-unit-disk rng))))
