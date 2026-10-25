#lang racket/base

;; The language the rendering modules are written in, with #lang s-exp:
;; racket/base with the flonum, fixnum and contract libraries and flo,
;; compiled without the checks on primitive operations, such as that flonum
;; operations get flonums and that indices are in bounds; see the README.

(require (for-syntax racket/base syntax/id-table) racket/contract/base racket/fixnum
         racket/flonum racket/performance-hint)

(provide (except-out (all-from-out racket/base) #%module-begin)
         (rename-out [unsafe-module-begin #%module-begin])
         (for-syntax (all-from-out racket/base))
         (all-from-out racket/contract/base racket/fixnum racket/flonum
                       racket/performance-hint)
         flo)

(define-syntax-rule (unsafe-module-begin form ...)
  (#%module-begin (#%declare #:unsafe) form ...))

;; (flo e) is e with its arithmetic done on flonums: +, -, *, /, min, max,
;; sqrt, tan and comparisons become fl+, fl- and so on, through if, and, or
;; and not, and integer literals become flonums. Operations take two operands
;; at a time from the left, as in the other versions, so that the results
;; round the same way: (+ a b c) is (fl+ (fl+ a b) c). (< a b c) holds if
;; each adjacent pair does.
(define-syntax (flo stx)
  (define (table pairs)
    (make-immutable-free-id-table
     (for/list ([pair (in-list (syntax->list pairs))])
       (syntax-case pair () [(from to) (cons #'from #'to)]))))
  (define unary (table #'([- fl-] [sqrt flsqrt] [tan fltan] [abs flabs])))
  (define folds (table #'([+ fl+] [- fl-] [* fl*] [/ fl/] [min flmin] [max flmax])))
  (define comparisons (table #'([< fl<] [> fl>] [<= fl<=] [>= fl>=] [= fl=])))
  (define logic (table #'([if if] [and and] [or or] [not not])))
  (define (op table f) (and (identifier? f) (free-id-table-ref table f #f)))
  (define (rewrite e)
    (syntax-case e ()
      [(f a) (op unary #'f) #`(#,(op unary #'f) #,(rewrite #'a))]
      [(f a b ...)
       (op folds #'f)
       (for/fold ([acc (rewrite #'a)]) ([b (in-list (syntax->list #'(b ...)))])
         #`(#,(op folds #'f) #,acc #,(rewrite b)))]
      [(f a ...)
       (op comparisons #'f)
       (with-syntax ([(t ...) (generate-temporaries #'(a ...))]
                     [(a* ...) (map rewrite (syntax->list #'(a ...)))])
         (with-syntax ([(t1 ... _) #'(t ...)] [(_ t2 ...) #'(t ...)])
           #`(let ([t a*] ...) (and (#,(op comparisons #'f) t1 t2) ...))))]
      [(f a ...) (op logic #'f) #`(f #,@(map rewrite (syntax->list #'(a ...))))]
      [n (exact-integer? (syntax-e #'n))
         (datum->syntax #'n (exact->inexact (syntax-e #'n)))]
      [_ e]))
  (syntax-case stx ()
    [(_ e) (rewrite #'e)]))
