# Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with 50
# samples per pixel. Usage: janet bench.janet [iterations] [threads]

(import ./raytracer/render)
(import ./test/scene)

(defn main [_ &opt iterations threads]
  (def iterations (if iterations (scan-number iterations) 20))
  (def threads (if threads (scan-number threads) (render/cpu-count)))
  (def [width height] [100 100])
  (def cam (scene/camera width height))
  (def w (scene/world))
  (defn run [] (render/render-with-threads threads width height 50 cam w))

  (run)
  (def start (os/clock :monotonic))
  (repeat iterations (run))
  (def elapsed (- (os/clock :monotonic) start))
  (printf "%d iterations on %d threads: %.2f ms/op"
          iterations threads (/ (* elapsed 1000) iterations)))
