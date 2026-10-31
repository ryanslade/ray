module Raytracer.Material
  ( Material (..),
    metal,
    Hit (..),
    scatter,
    refract,
  )
where

import Raytracer.Ray
import Raytracer.Rng (Rand, uniform)
import Raytracer.Vec3

data Material
  = Lambertian !Color
  | -- | Albedo and fuzz.
    Metal !Color !Double
  | -- | Refractive index.
    Dielectric !Double
  deriving (Eq, Show)

-- | A metal whose fuzz is clamped to [0, 1]: 0 is a perfect mirror.
metal :: Color -> Double -> Material
metal albedo fuzz = Metal albedo (max 0 (min 1 fuzz))

-- | Where a ray meets a surface.
data Hit = Hit
  { t :: !Double,
    point, normal :: !Vec3,
    material :: !Material
  }
  deriving (Show)

-- | The attenuation and the scattered ray, or 'Nothing' if the ray is
-- absorbed.
scatter :: Ray -> Hit -> Rand (Maybe (Color, Ray))
scatter rayIn hit = case hit.material of
  Lambertian albedo -> do
    r <- randomInUnitSphere
    let target = hit.point + hit.normal + r
    pure (Just (albedo, Ray hit.point (target - hit.point)))
  Metal albedo fuzz -> do
    r <- randomInUnitSphere
    let direction = reflect (normalize rayIn.direction) hit.normal + fuzz *^ r
    pure $
      if dot direction hit.normal > 0
        then Just (albedo, Ray hit.point direction)
        else Nothing
  Dielectric refIndex -> do
    let d = rayIn.direction
        dDotN = dot d hit.normal
        (outwardNormal, niOverNt, cosine)
          | dDotN > 0 = (negate hit.normal, refIndex, refIndex * dDotN / norm d)
          | otherwise = (hit.normal, 1 / refIndex, negate dDotN / norm d)
    -- Only draws a random number when the ray can refract.
    direction <- case refract d outwardNormal niOverNt of
      Just refracted -> do
        p <- uniform
        pure (if p >= schlick cosine refIndex then refracted else reflect d hit.normal)
      Nothing -> pure (reflect d hit.normal)
    pure (Just (white, Ray hit.point direction))

reflect :: Vec3 -> Vec3 -> Vec3
reflect v n = v - (2 * dot v n) *^ n

-- | The refracted direction, or 'Nothing' on total internal reflection.
refract :: Vec3 -> Vec3 -> Double -> Maybe Vec3
refract v n niOverNt
  | discriminant > 0 = Just (niOverNt *^ (uv - dt *^ n) - sqrt discriminant *^ n)
  | otherwise = Nothing
  where
    uv = normalize v
    dt = dot uv n
    discriminant = 1 - niOverNt * niOverNt * (1 - dt * dt)

-- | Schlick's approximation for reflectance at a given angle.
schlick :: Double -> Double -> Double
schlick cosine refIndex = r0 + (1 - r0) * x2 * x2 * x
  where
    r = (1 - refIndex) / (1 + refIndex)
    r0 = r * r
    -- Multiplied out rather than using (**), whose result can vary by
    -- platform, to match the other versions' golden image.
    x = 1 - cosine
    x2 = x * x
