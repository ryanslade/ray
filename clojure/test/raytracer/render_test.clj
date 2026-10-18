(ns raytracer.render-test
  (:require [clojure.java.io :as io]
            [clojure.test :refer [deftest is]]
            [raytracer.image :as image]
            [raytracer.render :as render]
            [raytracer.scene :as scene])
  (:import (java.nio.file Files)
           (java.util Arrays)))

(deftest deterministic-across-threads
  (let [[width height] [40 30]
        cam (scene/camera width height)
        w (scene/world)
        render #(render/render-with-threads % width height 8 cam w)
        expected (render 1)]
    (doseq [threads [2 4 7]]
      (is (= expected (render threads)) (str threads " threads")))))

;; Renders the test scene and compares it with test/golden.ppm.
;;
;; After an intentional change to the output, run with UPDATE_GOLDEN=1 to
;; accept it. On a mismatch the rendered image is written to
;; test/golden.actual.ppm for inspection.
(deftest golden-image
  (let [[width height] [200 200]
        img (render/render width height 100 (scene/camera width height) (scene/world))
        actual (image/to-ppm img)
        golden (io/file "test/golden.ppm")]
    (if (System/getenv "UPDATE_GOLDEN")
      (Files/write (.toPath golden) actual (make-array java.nio.file.OpenOption 0))
      (let [expected (Files/readAllBytes (.toPath golden))]
        (when-not (Arrays/equals actual expected)
          (let [out (io/file "test/golden.actual.ppm")]
            (Files/write (.toPath out) actual (make-array java.nio.file.OpenOption 0))
            (is false (str "rendered image doesn't match " golden
                           "; wrote it to " out))))))))
