(defpackage #:raytracer
  (:use #:cl)
  (:export
   ;; Vectors and colours
   #:vec3 #:vx #:vy #:vz #:v+ #:v- #:v* #:v/ #:vscale #:vneg #:dot #:cross
   #:vlength #:unit #:+zero+ #:+black+ #:+white+
   ;; Random numbers
   #:make-rng #:next-u64 #:next-f64
   ;; Rays and hits
   #:ray #:ray-origin #:ray-direction #:ray-at
   #:hit #:hit-distance #:hit-point #:hit-normal #:hit-material
   ;; Materials
   #:lambertian #:metal #:dielectric #:metal-fuzz
   ;; The scene
   #:sphere #:sphere-hit #:make-world #:world-hit #:make-camera
   ;; Images
   #:make-image #:image-width #:image-height #:set-pixel #:pixel #:to-ppm
   #:save-ppm
   ;; Rendering
   #:render #:render-with-threads #:ray-color #:cpu-count
   #:use-large-nursery #:main))
