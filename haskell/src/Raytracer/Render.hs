module Raytracer.Render (rayColor, render) where

import Control.Monad (foldM)
import Control.Monad.State.Strict (evalState)
import Control.Parallel.Strategies (parMap, rseq)
import Data.ByteString qualified as B
import Raytracer.Camera (Camera, getRay)
import Raytracer.Image (Image, encode, fromRows)
import Raytracer.Material (scatter)
import Raytracer.Ray
import Raytracer.Rng (Rand, mkRng, uniform)
import Raytracer.Vec3
import Raytracer.World (World)
import Raytracer.World qualified as World

maxDepth :: Int
maxDepth = 50

-- | The largest finite Double, which Rust calls f64::MAX.
maxDouble :: Double
maxDouble = 1.7976931348623157e308

-- | The colour seen along a ray, following up to 50 bounces.
rayColor :: World -> Ray -> Rand Color
rayColor world = go 0 white
  where
    -- The attenuation is the product of the attenuations of every surface
    -- hit so far.
    go depth attenuation ray = case World.hit world ray 0.001 maxDouble of
      Nothing -> pure (attenuation * sky ray)
      Just hit
        | depth == maxDepth -> pure black
        | otherwise ->
            scatter ray hit >>= \case
              Just (a, scattered) -> go (depth + 1) (attenuation * a) scattered
              Nothing -> pure black

sky :: Ray -> Color
sky ray = (1 - t) *^ white + t *^ Vec3 0.5 0.7 1
  where
    t = 0.5 * ((normalize ray.direction).y + 1)

-- | Renders the world with the given number of rays per pixel.
--
-- Rows are rendered in parallel, on as many cores as the runtime has
-- (@+RTS -N@). Each row uses its own random state seeded from the row
-- index, so like any pure function the result doesn't depend on that.
render :: Int -> Int -> Int -> Camera -> World -> Image
render width height samples camera world =
  fromRows width height (parMap rseq row [0 .. height - 1])
  where
    row y = B.concat (evalState (mapM pixel [0 .. width - 1]) (mkRng (fromIntegral y + 1)))
      where
        pixel x = do
          c <- foldM (\ !c _ -> (c +) <$> sample x) black [1 .. samples]
          pure (encode (c ^/ fromIntegral samples))
        sample x = do
          du <- uniform
          dv <- uniform
          let u = (fromIntegral x + du) / fromIntegral width
              v = (fromIntegral (height - 1 - y) + dv) / fromIntegral height
          getRay camera u v >>= rayColor world
