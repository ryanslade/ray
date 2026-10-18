(ns raytracer.unit-test
  (:require [clojure.test :refer [deftest is testing]]
            [raytracer.hit :as hit]
            [raytracer.image :as image]
            [raytracer.material :as material]
            [raytracer.ray :as ray]
            [raytracer.rng :as rng]
            [raytracer.sphere :as sphere]
            [raytracer.vec3 :as v]
            [raytracer.world :as world]))

(defn- close? [a b]
  (< (v/length (v/sub a b)) 1e-9))

(deftest vec3-arithmetic
  (let [a (v/vec3 1.0 2.0 3.0)
        b (v/vec3 4.0 5.0 6.0)]
    (is (close? (v/vec3 5.0 7.0 9.0) (v/add a b)))
    (is (close? (v/vec3 2.0 4.0 6.0) (v/scale 2.0 a)))
    (is (== 32.0 (v/dot a b)))
    (is (close? (v/vec3 -3.0 6.0 -3.0) (v/cross a b)))
    (is (< (abs (- (v/length (v/unit b)) 1.0)) 1e-9))))

(deftest rng-floats-in-unit-interval
  (let [r (rng/rng 1)]
    (is (every? #(and (>= % 0.0) (< % 1.0)) (repeatedly 10000 #(.nextF64 r))))))

(deftest rng-same-seed-same-sequence
  (let [a (rng/rng 42)
        b (rng/rng 42)]
    (is (= (repeatedly 100 #(.nextU64 a)) (repeatedly 100 #(.nextU64 b))))))

(deftest sphere-hit
  (let [m (material/dielectric 1.5)
        s (sphere/sphere (v/vec3 0.0 0.0 -1.0) 0.5 m)
        towards (ray/ray v/zero (v/vec3 0.0 0.0 -1.0))
        h (sphere/hit s towards 0.0 ##Inf)]
    (is (some? h))
    (is (== 0.5 (hit/t h)))
    (is (= (v/vec3 0.0 0.0 1.0) (hit/normal h)))
    (is (identical? m (hit/material h)))
    (testing "far side"
      (is (== 1.5 (hit/t (sphere/hit s towards 0.6 ##Inf)))))
    (is (nil? (sphere/hit s (ray/ray v/zero (v/vec3 0.0 1.0 0.0)) 0.0 ##Inf)))))

(deftest world-closest-hit
  (let [m (material/dielectric 1.5)
        w (world/world [(sphere/sphere (v/vec3 0.0 0.0 -5.0) 1.0 m)
                        (sphere/sphere (v/vec3 0.0 0.0 -2.0) 0.5 m)])
        h (world/hit w (ray/ray v/zero (v/vec3 0.0 0.0 -1.0)) 0.0 ##Inf)]
    (is (== 1.5 (hit/t h)))
    (is (nil? (world/hit w (ray/ray v/zero (v/vec3 0.0 1.0 0.0)) 0.0 ##Inf)))))

(deftest total-internal-reflection
  (is (nil? (#'material/refract (v/vec3 1.0 -0.1 0.0) (v/vec3 0.0 1.0 0.0) 1.5))))

(deftest refracts-head-on
  (let [down (v/vec3 0.0 -1.0 0.0)]
    (is (close? down (#'material/refract down (v/vec3 0.0 1.0 0.0) (/ 1.0 1.5))))))

(deftest metal-fuzz-is-clamped
  (is (== 1.0 (:fuzz (material/metal v/white 2.0))))
  (is (== 0.0 (:fuzz (material/metal v/white -1.0)))))

(deftest image-set-clamps
  (let [img (image/image 3 1)]
    (image/set-pixel! img 1 0 (v/vec3 2.0 0.5 -1.0))
    ;; f64::min in Rust ignores NaN, so NaN becomes 255.
    (image/set-pixel! img 2 0 (v/vec3 ##NaN 0.0 0.0))
    (is (= [0 0 0] (image/pixel img 0 0)))
    (is (= [255 127 0] (image/pixel img 1 0)))
    (is (= [255 0 0] (image/pixel img 2 0)))
    (is (thrown? IndexOutOfBoundsException (image/pixel img 3 0)))))

(deftest ppm-header
  (let [ppm (image/to-ppm (image/image 3 2))]
    (is (= "P6\n3 2\n255\n" (String. ppm 0 11 "US-ASCII")))
    (is (= (+ 11 (* 3 2 3)) (alength ppm)))))
