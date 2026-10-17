(import ../raytracer/image)
(import ../raytracer/render)
(import ./scene)

# The image doesn't depend on the number of threads.
(let [[width height] [40 30]
      cam (scene/camera width height)
      w (scene/world)
      render (fn [threads] (render/render-with-threads threads width height 8 cam w))
      expected (render 1)]
  (each threads [2 4 7]
    (assert (deep= (render threads) expected) (string threads " threads"))))

# Renders the test scene and compares it with test/golden.ppm.
#
# After an intentional change to the output, run with UPDATE_GOLDEN=1 to accept
# it. On a mismatch the rendered image is written to test/golden.actual.ppm for
# inspection.
(let [[width height] [100 100]
      img (render/render width height 50 (scene/camera width height) (scene/world))
      actual (image/to-ppm img)
      # Next to this file, wherever it's run from.
      sibling |(string/replace "render.janet" $ (dyn :current-file))
      golden (sibling "golden.ppm")]
  (if (os/getenv "UPDATE_GOLDEN")
    (spit golden actual)
    (unless (deep= actual (slurp golden))
      (def out (sibling "golden.actual.ppm"))
      (spit out actual)
      (errorf "rendered image doesn't match %s; wrote it to %s" golden out))))
