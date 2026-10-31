-- | Renders the example scene: @raytracer [output.png]@.
module Main (main) where

import Control.Concurrent (getNumCapabilities)
import Control.Exception (IOException, try)
import Control.Monad.State.Strict (evalState)
import Data.Maybe (catMaybes, fromMaybe, listToMaybe)
import Raytracer
import Raytracer.World qualified as World
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

width, height, samples :: Int
width = 800
height = 450
samples = 100

randomWorld :: Rand World
randomWorld = do
  small <- sequence [smallSphere a b | a <- [-11 .. 10], b <- [-11 .. 10]]
  pure . World.fromList $
    [Sphere (Vec3 0 (-1000) (-1)) 1000 (Lambertian (Vec3 0.5 0.5 0.5))]
      ++ catMaybes small
      ++ [ Sphere (Vec3 4 1 0) 1 (metal (Vec3 0.8 0.6 0.2) 0.1),
           Sphere (Vec3 0 1 0) 1 (Dielectric 1.5),
           Sphere (Vec3 (-4) 1 0) 1 (metal (Vec3 0.8 0.8 0.8) 0.2)
         ]

-- | A small sphere in the grid square at @(a, b)@, unless it would be too
-- close to the metal sphere.
smallSphere :: Double -> Double -> Rand (Maybe Sphere)
smallSphere a b = do
  dx <- uniform
  dz <- uniform
  let center = Vec3 (a + 0.9 * dx) 0.2 (b + 0.9 * dz)
  if norm (center - Vec3 4 0.2 0) <= 0.9
    then pure Nothing
    else do
      albedo <- Vec3 <$> channel <*> channel <*> channel
      pure (Just (Sphere center 0.2 (Lambertian albedo)))
  where
    channel = (*) <$> uniform <*> uniform

main :: IO ()
main = do
  output <- fromMaybe "out.png" . listToMaybe <$> getArgs
  hPutStrLn stderr "Generating world"
  let world = evalState randomWorld (mkRng 1)
      lookFrom = Vec3 3 2 3
      lookAt = Vec3 0 0 (-1)
      camera =
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
  cores <- getNumCapabilities
  hPutStrLn stderr ("Rendering on " <> show cores <> " cores")
  result <- try (writePng output (render width height samples camera world))
  case result of
    Left (e :: IOException) -> do
      hPutStrLn stderr ("Writing " <> output <> ": " <> show e)
      exitFailure
    Right () -> hPutStrLn stderr ("Wrote " <> output)
