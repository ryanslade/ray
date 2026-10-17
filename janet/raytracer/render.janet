(import ./camera)
(import ./image)
(import ./material)
(import ./vec3)
(import ./world)

(def- max-depth 50)
(def- black [0 0 0])
(def- white [1 1 1])
(def- sky-blue [0.5 0.7 1])

(defn- sky [[_ direction]]
  (def t (* 0.5 (+ ((vec3/unit direction) 1) 1)))
  (vec3/add (vec3/scale (- 1 t) white) (vec3/scale t sky-blue)))

(defn- trace
  "attenuation is the product of the attenuations of every surface hit so far."
  [w r rng attenuation depth]
  (if-let [hit (world/hit w r 0.001 math/inf)]
    (if (= depth max-depth)
      black
      (if-let [[a scattered] (material/scatter (hit :material) r hit rng)]
        (trace w scattered rng (vec3/mul attenuation a) (+ depth 1))
        black))
    (vec3/mul attenuation (sky r))))

(defn ray-color
  "The colour seen along a ray, following up to 50 bounces."
  [w r rng]
  (trace w r rng white 0))

(defn- render-row
  "Renders row y into a new buffer. Each row uses its own random state seeded
  from the row index, so the image doesn't depend on which thread renders it."
  [y width height samples cam w]
  (def rng (math/rng (+ y 1)))
  (def row (buffer/new (* 3 width)))
  (for x 0 width
    (var c black)
    (repeat samples
      (def u (/ (+ x (math/rng-uniform rng)) width))
      (def v (/ (+ (- height 1 y) (math/rng-uniform rng)) height))
      (set c (vec3/add c (ray-color w (camera/get-ray cam u v rng) rng))))
    (image/push-pixel row (vec3/div c samples)))
  row)

(defn render-with-threads
  "Renders the world with samples rays per pixel, on threads threads."
  [threads width height samples cam w]
  (assert (pos? threads) "threads must be positive")
  (def img (image/new width height))
  (when (and (pos? width) (pos? height))
    # Rows vary a lot in cost (sky is cheap, spheres are expensive), so
    # threads take rows one at a time rather than a fixed block each.
    (def rows (ev/thread-chan (+ height threads)))
    (for y 0 height (ev/give rows y))
    (repeat threads (ev/give rows :done))
    # Finished rows arrive as [y row]. Each thread is also supervised by this
    # channel, so it gets [:ok ...] when one exits and [:error ...] if one
    # fails.
    (def results (ev/thread-chan (+ height threads)))
    (defn worker []
      (var y (ev/take rows))
      (while (not= y :done)
        (ev/give results [y (render-row y width height samples cam w)])
        (set y (ev/take rows))))
    (repeat threads (ev/thread worker nil :n results))
    (var remaining height)
    (while (pos? remaining)
      (match (ev/take results)
        [:error err] (error err)
        [:ok] nil
        [y row] (do (image/set-row img y row) (-- remaining)))))
  img)

(defn cpu-count []
  (or (os/cpu-count)
      # os/cpu-count isn't implemented on macOS.
      (when (= (os/which) :macos)
        (with [proc (os/spawn ["sysctl" "-n" "hw.ncpu"] :p {:out :pipe})]
          (scan-number (string/trim (ev/read (proc :out) :all)))))
      1))

(defn render
  "Renders the world with samples rays per pixel, in parallel across all
  available cores."
  [width height samples cam w]
  (render-with-threads (cpu-count) width height samples cam w))
