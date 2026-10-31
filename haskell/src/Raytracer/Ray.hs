module Raytracer.Ray (Ray (..), at) where

import Raytracer.Vec3

data Ray = Ray {origin, direction :: !Vec3}
  deriving (Eq, Show)

at :: Ray -> Double -> Vec3
at ray t = ray.origin + t *^ ray.direction
