module Raytracer.World (Sphere (..), intersect, hitAt, World, fromList, hit) where

import Raytracer.Material (Hit (..), Material)
import Raytracer.Vec3

data Sphere = Sphere {center :: !Vec3, radius :: !Double, material :: !Material}
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
    discriminant = b * b - a * (dot oc oc - s.radius * s.radius)
    near = (-b - sqrt discriminant) / a
    far = (-b + sqrt discriminant) / a
    inRange t = t < tMax && t > tMin
{-# INLINE intersect #-}

-- | The hit record for a @t@ returned by 'intersect'.
hitAt :: Sphere -> Ray -> Double -> Hit
hitAt s ray t = Hit {t, point, normal = (point - s.center) ^/ s.radius, material = s.material}
  where
    point = at ray t

newtype World = World [Sphere]

fromList :: [Sphere] -> World
fromList = World

-- | The closest hit in @(tMin, tMax)@, shrinking @tMax@ as nearer spheres
-- are found. Only the hit record for the closest sphere is ever needed, so
-- this just tracks which one it is until the end.
hit :: World -> Ray -> Double -> Double -> Maybe Hit
hit (World spheres) ray tMin = go Nothing spheres
  where
    go closest [] tMax = (\s -> hitAt s ray tMax) <$> closest
    go closest (s : rest) tMax = case intersect s ray tMin tMax of
      Just t -> go (Just s) rest t
      Nothing -> go closest rest tMax
