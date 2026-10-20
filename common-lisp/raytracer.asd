;;; Needs SBCL: threads, atomics and float traps use its extensions.

(defsystem "raytracer"
  :description "A simple ray tracer, based on Ray Tracing in One Weekend."
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "rng")
               (:file "vec3")
               (:file "ray")
               (:file "material")
               (:file "sphere")
               (:file "world")
               (:file "camera")
               (:file "image")
               (:file "render")
               (:file "main"))
  :in-order-to ((test-op (test-op "raytracer/tests"))))

(defsystem "raytracer/tests"
  :depends-on ("raytracer")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "check")
               (:file "scene")
               (:file "unit")
               (:file "render"))
  :perform (test-op (o c) (symbol-call :raytracer-tests :run)))

(defsystem "raytracer/bench"
  :depends-on ("raytracer/tests")
  :pathname "bench"
  :components ((:file "bench")))
