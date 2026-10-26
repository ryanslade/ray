(ns raytracer.rng
  "A small, fast pseudo-random number generator (SplitMix64), the same as the
  other versions use, so that scenes and renders are identical.")

(set! *warn-on-reflection* true)
(set! *unchecked-math* :warn-on-boxed)

;; The constants don't fit in a signed long, so they are read as BigInts and
;; truncated to the same 64 bits.
(def ^:private ^:const gamma (unchecked-long 0x9e3779b97f4a7c15N))
(def ^:private ^:const mix1 (unchecked-long 0xbf58476d1ce4e5b9N))
(def ^:private ^:const mix2 (unchecked-long 0x94d049bb133111ebN))
(def ^:private ^:const scale (/ 1.0 (bit-shift-left 1 53)))

(defn rng
  "A generator seeded with `seed`: its state, in a one-element array. Not safe
  to share between threads."
  ^longs [^long seed]
  (long-array 1 seed))

(defn next-u64 ^long [^longs state]
  (let [z (aset state 0 (unchecked-add (aget state 0) gamma))
        z (unchecked-multiply (bit-xor z (unsigned-bit-shift-right z 30)) mix1)
        z (unchecked-multiply (bit-xor z (unsigned-bit-shift-right z 27)) mix2)]
    (bit-xor z (unsigned-bit-shift-right z 31))))

(defn next-f64
  "A uniformly distributed double in [0, 1)."
  ^double [state]
  ;; The top 53 bits fill a double's mantissa exactly.
  (* (double (unsigned-bit-shift-right (next-u64 state) 11)) scale))
