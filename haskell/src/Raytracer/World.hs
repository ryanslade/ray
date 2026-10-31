module Raytracer.World (World, fromList, hit) where

import Raytracer.Material (Hit)
import Raytracer.Ray
import Raytracer.Sphere (Sphere, hitAt, intersect)

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
