-- | A small, fast pseudo-random number generator (SplitMix64), the same as
-- the other versions use, so that scenes and renders are identical.
module Raytracer.Rng
  ( Rng,
    mkRng,
    nextWord64,
    nextDouble,
    Rand,
    uniform,
  )
where

import Control.Monad.State.Strict (State, state)
import Data.Bits (shiftR, xor)
import Data.Word (Word64)

newtype Rng = Rng Word64

mkRng :: Word64 -> Rng
mkRng = Rng

nextWord64 :: Rng -> (Word64, Rng)
nextWord64 (Rng s) = (mix s', Rng s')
  where
    -- Word64 arithmetic wraps.
    !s' = s + 0x9e3779b97f4a7c15
    mix z0 =
      let z1 = (z0 `xor` (z0 `shiftR` 30)) * 0xbf58476d1ce4e5b9
          z2 = (z1 `xor` (z1 `shiftR` 27)) * 0x94d049bb133111eb
       in z2 `xor` (z2 `shiftR` 31)

-- | A uniformly distributed number in [0, 1).
nextDouble :: Rng -> (Double, Rng)
nextDouble g = (fromIntegral (w `shiftR` 11) * 0x1p-53, g')
  where
    -- The top 53 bits fill a Double's mantissa exactly.
    (w, g') = nextWord64 g

-- | Computations that draw random numbers.
type Rand = State Rng

uniform :: Rand Double
uniform = state nextDouble
