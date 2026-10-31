module Raytracer.Camera
  ( CameraSettings (..),
    Camera,
    mkCamera,
    getRay,
  )
where

import Raytracer.Ray
import Raytracer.Rng (Rand)
import Raytracer.Vec3

data CameraSettings = CameraSettings
  { lookFrom, lookAt, vUp :: !Vec3,
    -- | The vertical field of view, in degrees.
    vfov :: !Double,
    aspect, aperture, focusDist :: !Double
  }

data Camera = Camera
  { origin, lowerLeft, horizontal, vertical, u, v :: !Vec3,
    lensRadius :: !Double
  }

mkCamera :: CameraSettings -> Camera
mkCamera s =
  Camera
    { origin = s.lookFrom,
      lowerLeft =
        s.lookFrom
          - (halfWidth * s.focusDist) *^ u
          - (halfHeight * s.focusDist) *^ v
          - s.focusDist *^ w,
      horizontal = (2 * halfWidth * s.focusDist) *^ u,
      vertical = (2 * halfHeight * s.focusDist) *^ v,
      u,
      v,
      lensRadius = s.aperture / 2
    }
  where
    -- The same constant as Rust's to_radians.
    theta = s.vfov * (pi / 180)
    halfHeight = tan (theta / 2)
    halfWidth = s.aspect * halfHeight
    w = normalize (s.lookFrom - s.lookAt)
    u = normalize (cross s.vUp w)
    v = cross w u

-- | A ray through the viewport at normalised coordinates @(s, t)@, with its
-- origin jittered across the lens.
getRay :: Camera -> Double -> Double -> Rand Ray
getRay c s t = do
  Vec3 rx ry _ <- (c.lensRadius *^) <$> randomInUnitDisk
  let offset = rx *^ c.u + ry *^ c.v
  pure
    Ray
      { origin = c.origin + offset,
        direction = c.lowerLeft + s *^ c.horizontal + t *^ c.vertical - c.origin - offset
      }
