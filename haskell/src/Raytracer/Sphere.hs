module Raytracer.Sphere
  ( Sphere (..),
    intersect,
    hitAt,
    hit,
  )
where

import Raytracer.Material (Hit (..), Material)
import Raytracer.Ray
import Raytracer.Vec3

data Sphere = Sphere
  { center :: !Vec3,
    radius :: !Double,
    material :: !Material
  }
  deriving (Eq, Show)

-- | The nearest @t@ in @(tMin, tMax)@ at which the ray meets the sphere.
intersect :: Sphere -> Ray -> Double -> Double -> Maybe Double
intersect s ray tMin tMax
  | discriminant < 0 = Nothing
  | inRange near = Just near
  | inRange far = Just far
  | otherwise = Nothing
  where
    oc = ray.origin - s.center
    a = dot ray.direction ray.direction
    b = dot oc ray.direction
    c = dot oc oc - s.radius * s.radius
    discriminant = b * b - a * c
    near = (-b - sqrt discriminant) / a
    far = (-b + sqrt discriminant) / a
    inRange t = t < tMax && t > tMin
{-# INLINE intersect #-}

-- | The hit record for a @t@ returned by 'intersect'.
hitAt :: Sphere -> Ray -> Double -> Hit
hitAt s ray t =
  Hit {t, point, normal = (point - s.center) ^/ s.radius, material = s.material}
  where
    point = at ray t

hit :: Sphere -> Ray -> Double -> Double -> Maybe Hit
hit s ray tMin tMax = hitAt s ray <$> intersect s ray tMin tMax
