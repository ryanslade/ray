-- | The scene used by the tests and benchmark, matching the other versions.
module Scene (world, camera) where

import Raytracer
import Raytracer.World qualified as World

world :: World
world =
  World.fromList
    [ Sphere (Vec3 0 (-100.5) (-1)) 100 (Lambertian (Vec3 0.5 0.5 0.5)),
      Sphere (Vec3 0 0 (-1)) 1 (metal (Vec3 0.8 0.8 0.8) 0.2),
      Sphere (Vec3 1.5 0 (-1)) 1 (Dielectric 1.5)
    ]

camera :: Int -> Int -> Camera
camera width height =
  mkCamera
    CameraSettings
      { lookFrom,
        lookAt,
        vUp = Vec3 0 1 0,
        vfov = 90,
        aspect = fromIntegral width / fromIntegral height,
        aperture = 0.01,
        focusDist = norm (lookFrom - lookAt)
      }
  where
    lookFrom = Vec3 1 1 1
    lookAt = Vec3 0 0 (-1)
