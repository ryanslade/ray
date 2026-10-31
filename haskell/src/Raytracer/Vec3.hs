module Raytracer.Vec3
  ( Vec3 (..),
    Color,
    black,
    white,
    (*^),
    (^/),
    dot,
    cross,
    norm,
    normalize,
    randomInUnitSphere,
    randomInUnitDisk,
  )
where

import Raytracer.Rng (Rand, uniform)

data Vec3 = Vec3 {x, y, z :: !Double}
  deriving (Eq, Show)

-- | Component-wise, like the linear package's vectors: adding and
-- subtracting work as usual, and multiplying colours attenuates them.
instance Num Vec3 where
  Vec3 ax ay az + Vec3 bx by bz = Vec3 (ax + bx) (ay + by) (az + bz)
  Vec3 ax ay az - Vec3 bx by bz = Vec3 (ax - bx) (ay - by) (az - bz)
  Vec3 ax ay az * Vec3 bx by bz = Vec3 (ax * bx) (ay * by) (az * bz)
  negate (Vec3 vx vy vz) = Vec3 (negate vx) (negate vy) (negate vz)
  abs (Vec3 vx vy vz) = Vec3 (abs vx) (abs vy) (abs vz)
  signum (Vec3 vx vy vz) = Vec3 (signum vx) (signum vy) (signum vz)
  fromInteger n = let c = fromInteger n in Vec3 c c c

-- | Red, green and blue.
type Color = Vec3

black, white :: Color
black = Vec3 0 0 0
white = Vec3 1 1 1

infixl 7 *^, ^/

-- | Multiplication by a scalar.
(*^) :: Double -> Vec3 -> Vec3
s *^ Vec3 vx vy vz = Vec3 (s * vx) (s * vy) (s * vz)

(^/) :: Vec3 -> Double -> Vec3
Vec3 vx vy vz ^/ s = Vec3 (vx / s) (vy / s) (vz / s)

dot :: Vec3 -> Vec3 -> Double
dot (Vec3 ax ay az) (Vec3 bx by bz) = ax * bx + ay * by + az * bz

cross :: Vec3 -> Vec3 -> Vec3
cross (Vec3 ax ay az) (Vec3 bx by bz) =
  Vec3 (ay * bz - az * by) (az * bx - ax * bz) (ax * by - ay * bx)

norm :: Vec3 -> Double
norm v = sqrt (dot v v)

normalize :: Vec3 -> Vec3
normalize v = v ^/ norm v

-- | Rejection sampling: picks points in the enclosing cube until one lands
-- inside.
randomInUnitSphere :: Rand Vec3
randomInUnitSphere = do
  p <- Vec3 <$> coord <*> coord <*> coord
  if dot p p < 1 then pure p else randomInUnitSphere

randomInUnitDisk :: Rand Vec3
randomInUnitDisk = do
  p <- Vec3 <$> coord <*> coord <*> pure 0
  if dot p p < 1 then pure p else randomInUnitDisk

coord :: Rand Double
coord = do
  c <- uniform
  pure (2 * c - 1)
