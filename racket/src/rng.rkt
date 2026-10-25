#lang racket/base

;; A small, fast pseudo-random number generator (SplitMix64), the same as the
;; other versions use, so that scenes and renders are identical.

;; Compiled without the checks on primitive operations, such as that flonum
;; operations get flonums and that indices are in bounds; see the README.
(#%declare #:unsafe)

(require racket/contract/base racket/fixnum racket/flonum racket/performance-hint)

(provide (contract-out [make-rng (-> exact-integer? any)]) next-u64 next-f64)

;; Racket CS fixnums have 61 bits, and larger integers are bignums on the heap.
;; So the 64-bit state is kept as two 32-bit halves. Not safe to share between
;; threads.
(struct rng ([hi #:mutable] [lo #:mutable]) #:authentic)

(define mask32 #xFFFFFFFF)

(define (make-rng seed)
  (rng (bitwise-and (arithmetic-shift seed -32) mask32) (bitwise-and seed mask32)))

;; The helpers below are inlined into next!, so the values they return are
;; just bound to variables rather than returned from calls.

;; z * c mod 2^64, where z is (hi, lo) and c is (ch, cl), as two values.
;;
;; fx*/wraparound multiplies modulo 2^61, so it gives the low 32 bits of a
;; product exactly. Only lo * cl is needed in full, for the bits it carries
;; into the high half, so lo is split into 16-bit halves first:
;; lo * cl = l0 + l1 * 2^16.
(define-inline (mul hi lo ch cl)
  (let* ([l0 (fx* (fxand lo #xFFFF) cl)]
         [l1 (fx* (fxrshift lo 16) cl)]
         [low (fx+ l0 (fxlshift (fxand l1 #xFFFF) 16))]
         [carry (fx+ (fxrshift low 32) (fxrshift l1 16))])
    (values (fxand (fx+/wraparound (fx+/wraparound carry (fx*/wraparound hi cl))
                                   (fx*/wraparound lo ch))
                   mask32)
            (fxand low mask32))))

;; z ^ (z >> n), for 0 < n < 32.
(define-inline (xor-shift hi lo n)
  (values (fxxor hi (fxrshift hi n))
          (fxxor lo (fxand (fxior (fxrshift lo n) (fxlshift hi (fx- 32 n))) mask32))))

;; Advances the state and returns the next output's halves.
(define-inline (next! r)
  ;; Adds #x9E3779B97F4A7C15.
  (let* ([sum (fx+ (rng-lo r) #x7F4A7C15)]
         [hi (fxand (fx+ (fx+ (rng-hi r) #x9E3779B9) (fxrshift sum 32)) mask32)]
         [lo (fxand sum mask32)])
    (set-rng-hi! r hi)
    (set-rng-lo! r lo)
    (let*-values ([(zh zl) (xor-shift hi lo 30)]
                  [(zh zl) (mul zh zl #xBF58476D #x1CE4E5B9)]
                  [(zh zl) (xor-shift zh zl 27)]
                  [(zh zl) (mul zh zl #x94D049BB #x133111EB)])
      (xor-shift zh zl 31))))

(define (next-u64 r)
  (define-values (hi lo) (next! r))
  (bitwise-ior (arithmetic-shift hi 32) lo))

;; The next output's top 53 bits, which fill a flonum's mantissa exactly.
(define (next-53! r)
  (define-values (hi lo) (next! r))
  (fx+ (fxlshift hi 21) (fxrshift lo 11)))

;; A uniformly distributed flonum in [0, 1).
;;
;; A flonum is boxed when a procedure returns it, but stays unboxed while it
;; is only bound to local variables and passed to flonum operations. So this
;; is inlined into its callers, and only the fixnum comes from a call.
(define-inline (next-f64 r)
  (fl* (fx->fl (next-53! r)) #i1/9007199254740992))
