#lang racket/base

;; 8-bit RGB images. Row 0 is the top.

(require file/gzip racket/fixnum racket/flonum "vec3.rkt")

(provide make-image image-width image-height image-pixels write-color!
         set-pixel! pixel image->ppm save-ppm image->png save-png crc32 adler32)

(struct image (width height pixels) #:authentic)

(define (make-image width height)
  (image width height (make-bytes (* width height 3) 0)))

;; Stores a colour at byte offset i of pixels, clamping each channel to [0, 1].
(define (write-color! pixels i c)
  (define (to-byte c)
    ;; Written so that NaN becomes 255, as in the Rust version.
    (define b (fl* 255.99 (if (fl< c 1.0) c 1.0)))
    (if (fl> b 0.0) (fl->fx b) 0))
  (bytes-set! pixels i (to-byte (vx c)))
  (bytes-set! pixels (+ i 1) (to-byte (vy c)))
  (bytes-set! pixels (+ i 2) (to-byte (vz c))))

(define (pixel-index img x y)
  (unless (and (< -1 x (image-width img)) (< -1 y (image-height img)))
    (error 'pixel-index "pixel (~a, ~a) is out of bounds" x y))
  (* 3 (+ (* y (image-width img)) x)))

;; Stores a colour, clamping each channel to [0, 1].
(define (set-pixel! img x y c)
  (write-color! (image-pixels img) (pixel-index img x y) c))

;; The pixel at (x, y) as a list (r g b), each in [0, 255].
(define (pixel img x y)
  (define i (pixel-index img x y))
  (bytes->list (subbytes (image-pixels img) i (+ i 3))))

;; Binary (P6) PPM encoding.
(define (image->ppm img)
  (bytes-append (string->bytes/utf-8
                 (format "P6\n~a ~a\n255\n" (image-width img) (image-height img)))
                (image-pixels img)))

(define (save-ppm img path)
  (call-with-output-file path #:exists 'truncate/replace
    (λ (out) (write-bytes (image->ppm img) out))))

;; n as four big-endian bytes.
(define (u32-be n)
  (integer->integer-bytes n 4 #f #t))

(define crc-table
  (for/vector #:length 256 ([n (in-range 256)])
    (for/fold ([c n]) ([k (in-range 8)])
      (if (odd? c)
          (fxxor #xEDB88320 (fxrshift c 1))
          (fxrshift c 1)))))

;; The CRC-32 of the concatenation of the byte strings.
(define (crc32 . byte-strings)
  (fxxor #xFFFFFFFF
         (for*/fold ([c #xFFFFFFFF]) ([bs (in-list byte-strings)]
                                      [b (in-bytes bs)])
           (fxxor (vector-ref crc-table (fxand (fxxor c b) #xFF)) (fxrshift c 8)))))

(define (adler32 bs)
  (define-values (a b)
    (for/fold ([a 1] [b 0]) ([byte (in-bytes bs)])
      (define a* (fxmodulo (fx+ a byte) 65521))
      (values a* (fxmodulo (fx+ b a*) 65521))))
  (fxior (fxlshift b 16) a))

;; A zlib stream holding data, compressed by file/gzip.
(define (zlib data)
  (define out (open-output-bytes))
  ;; Deflate with a 32K window, at the default compression level.
  (write-bytes (bytes #x78 #x9C) out)
  (deflate (open-input-bytes data) out)
  (write-bytes (u32-be (adler32 data)) out)
  (get-output-bytes out))

(define (png-chunk type data)
  (define type-bytes (string->bytes/latin-1 type))
  (bytes-append (u32-be (bytes-length data)) type-bytes data
                (u32-be (crc32 type-bytes data))))

;; PNG encoding.
(define (image->png img)
  (define width (image-width img))
  (define height (image-height img))
  (define row-bytes (* 3 width))
  ;; Each scanline starts with its filter type, 0 for none.
  (define raw (make-bytes (* (+ row-bytes 1) height) 0))
  (for ([y (in-range height)])
    (bytes-copy! raw (+ (* y (+ row-bytes 1)) 1)
                 (image-pixels img) (* y row-bytes) (* (+ y 1) row-bytes)))
  (bytes-append (bytes #x89 80 78 71 13 10 26 10)
                (png-chunk "IHDR"
                           (bytes-append (u32-be width) (u32-be height)
                                         ;; 8 bits per channel, RGB, deflate,
                                         ;; no filtering, no interlacing.
                                         (bytes 8 2 0 0 0)))
                (png-chunk "IDAT" (zlib raw))
                (png-chunk "IEND" #"")))

(define (save-png img path)
  (call-with-output-file path #:exists 'truncate/replace
    (λ (out) (write-bytes (image->png img) out))))
