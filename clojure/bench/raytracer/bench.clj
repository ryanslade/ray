(ns raytracer.bench
  "Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with
  50 samples per pixel. Usage: clojure -M:bench [iterations] [threads]"
  (:require [raytracer.render :as render]
            [raytracer.scene :as scene]))

(defn -main [& args]
  (let [[iterations threads] (map parse-long args)
        iterations (or iterations 20)
        threads (or threads (.availableProcessors (Runtime/getRuntime)))
        [width height] [100 100]
        cam (scene/camera width height)
        w (scene/world)
        run #(render/render-with-threads threads width height 50 cam w)]
    ;; The JIT compiles the hot code as it runs, so warm up for a few seconds
    ;; first.
    (let [warm-until (+ (System/nanoTime) 3e9)]
      (while (< (System/nanoTime) warm-until) (run)))
    (let [start (System/nanoTime)]
      (dotimes [_ iterations] (run))
      (printf "%d iterations on %d threads: %.2f ms/op%n" iterations threads
              (/ (- (System/nanoTime) start) 1e6 iterations)))
    (flush)
    (shutdown-agents)))
