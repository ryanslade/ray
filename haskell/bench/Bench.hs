-- Without full laziness, which would float the render out of the loop, so
-- that it would only be done once.
{-# OPTIONS_GHC -fno-full-laziness #-}

-- | Mirrors BenchmarkRender in the Go version: the test scene at 100x100
-- with 50 samples per pixel. Usage: bench [iterations] [threads]
module Main (main) where

import Control.Concurrent (getNumCapabilities, setNumCapabilities)
import Control.Exception (evaluate)
import Control.Monad (forM_, void)
import GHC.Clock (getMonotonicTime)
import Raytracer (render)
import Scene qualified
import System.Environment (getArgs)
import Text.Printf (printf)

main :: IO ()
main = do
  args <- map read <$> getArgs
  cores <- getNumCapabilities
  let (iterations, threads) = case args of
        [] -> (20, cores)
        [i] -> (i, cores)
        i : t : _ -> (i, t)
  setNumCapabilities threads
  let camera = Scene.camera 100 100
      run (_ :: Int) = void (evaluate (render 100 100 50 camera Scene.world))
  run 0
  start <- getMonotonicTime
  forM_ [1 .. iterations] run
  end <- getMonotonicTime
  printf
    "%d iterations on %d threads: %.2f ms/op\n"
    iterations
    threads
    ((end - start) * 1000 / fromIntegral iterations)
