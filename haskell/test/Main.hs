{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Exception (ErrorCall, evaluate, try)
import Control.Monad (replicateM, unless)
import Control.Monad.State.Strict (evalState)
import Data.Bits (shiftL, (.|.))
import Data.ByteString qualified as B
import Data.ByteString.Lazy qualified as BL
import Data.Maybe (isNothing)
import Data.Word (Word16, Word32)
import Raytracer
import Raytracer.Sphere qualified as Sphere
import Raytracer.World qualified as World
import Scene qualified
import System.Environment (lookupEnv)
import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.QuickCheck (testProperty)

main :: IO ()
main =
  defaultMain $
    testGroup
      "raytracer"
      [ testCase "vector arithmetic" vectorArithmetic,
        testProperty "random numbers are in [0, 1)" $ \seed ->
          all (\f -> f >= 0 && f < 1) (evalState (replicateM 100 uniform) (mkRng seed)),
        testCase "the generator matches SplitMix64" splitMix64,
        testCase "a ray hits a sphere" sphereHit,
        testCase "the world finds the closest hit" closestHit,
        testCase "the world matches testing sphere by sphere" sphereBySphere,
        testCase "total internal reflection" $
          assertBool "refracted" (isNothing (refract (Vec3 1 (-0.1) 0) (Vec3 0 1 0) 1.5)),
        testCase "refracts head on" refractsHeadOn,
        testCase "metal fuzz is clamped" $ do
          metal white 2 @?= Metal white 1
          metal white (-1) @?= Metal white 0,
        testCase "encoding a pixel clamps each channel" clamps,
        testCase "PPM header" ppmHeader,
        testCase "PNG" png,
        testCase "golden image" golden
      ]

close :: Vec3 -> Vec3 -> Bool
close a b = norm (a - b) < 1e-9

vectorArithmetic :: Assertion
vectorArithmetic = do
  let a = Vec3 1 2 3
      b = Vec3 4 5 6
  assertBool "add" (close (a + b) (Vec3 5 7 9))
  assertBool "scale" (close (2 *^ a) (Vec3 2 4 6))
  dot a b @?= 32
  assertBool "cross" (close (cross a b) (Vec3 (-3) 6 (-3)))
  assertBool "normalize" (abs (norm (normalize b) - 1) < 1e-9)

splitMix64 :: Assertion
splitMix64 = do
  -- The first outputs for seed 0 from the reference implementation.
  let (a, g) = nextWord64 (mkRng 0)
      (b, _) = nextWord64 g
  a @?= 0xe220a8397b1dcdaf
  b @?= 0x6e789e6aa1b965f4

infinity :: Double
infinity = 1 / 0

sphereHit :: Assertion
sphereHit = do
  let s = Sphere (Vec3 0 0 (-1)) 0.5 (Dielectric 1.5)
      towards = Ray (Vec3 0 0 0) (Vec3 0 0 (-1))
  case Sphere.hit s towards 0 infinity of
    Just h -> do
      h.t @?= 0.5
      h.normal @?= Vec3 0 0 1
    Nothing -> assertFailure "expected a hit"
  ((.t) <$> Sphere.hit s towards 0.6 infinity) @?= Just 1.5
  assertBool "hit going away" (isNothing (Sphere.hit s (Ray (Vec3 0 0 0) (Vec3 0 1 0)) 0 infinity))

closestHit :: Assertion
closestHit = do
  let m = Dielectric 1.5
      w = World.fromList [Sphere (Vec3 0 0 (-5)) 1 m, Sphere (Vec3 0 0 (-2)) 0.5 m]
  ((.t) <$> World.hit w (Ray (Vec3 0 0 0) (Vec3 0 0 (-1))) 0 infinity) @?= Just 1.5

-- | The world finds exactly the hit that testing each sphere in turn would.
sphereBySphere :: Assertion
sphereBySphere = do
  let coord scale = (\c -> scale * (2 * c - 1)) <$> uniform
      vec scale = Vec3 <$> coord scale <*> coord scale <*> coord scale
      (spheres, rays) = flip evalState (mkRng 1) $ do
        ss <- replicateM 23 $ do
          center <- vec 3
          r <- coord 1
          pure (Sphere center (0.1 + abs r) (Dielectric 1.5))
        rs <- replicateM 2000 (Ray <$> vec 5 <*> vec 1)
        pure (ss, rs)
      world = World.fromList spheres
      closest ray = fst (foldl' (step ray) (Nothing, maxDouble) spheres)
      step ray (found, tMax) s = case Sphere.hit s ray 0.001 tMax of
        Just h -> (Just h, h.t)
        Nothing -> (found, tMax)
      summary h = (h.t, h.point, h.normal)
  mapM_
    (\ray -> (summary <$> World.hit world ray 0.001 maxDouble) @?= (summary <$> closest ray))
    rays
  where
    maxDouble = 1.7976931348623157e308

refractsHeadOn :: Assertion
refractsHeadOn = do
  let down = Vec3 0 (-1) 0
  case refract down (Vec3 0 1 0) (1 / 1.5) of
    Just r -> assertBool "direction" (close r down)
    Nothing -> assertFailure "should refract"

clamps :: Assertion
clamps = do
  let img = generate 3 1 (\x _ -> if x == 1 then Vec3 2 0.5 (-1) else black)
  pixelAt img 0 0 @?= (0, 0, 0)
  pixelAt img 1 0 @?= (255, 127, 0)
  result <- try (evaluate (pixelAt img 3 0))
  case result of
    Left (_ :: ErrorCall) -> pure ()
    Right _ -> assertFailure "expected an out of bounds error"

ppmHeader :: Assertion
ppmHeader = do
  let ppm = BL.toStrict (toPpm (generate 3 2 (\_ _ -> black)))
  B.take 11 ppm @?= "P6\n3 2\n255\n"
  B.length ppm @?= 11 + 3 * 2 * 3

-- | Splits a PNG into its chunks, as (type, data) pairs.
pngChunks :: B.ByteString -> [(B.ByteString, B.ByteString)]
pngChunks bytes
  | B.null bytes = []
  | otherwise =
      let len = fromIntegral (be32 bytes)
       in (B.take 4 (B.drop 4 bytes), B.take len (B.drop 8 bytes))
            : pngChunks (B.drop (12 + len) bytes)

be32 :: B.ByteString -> Word32
be32 = B.foldl' (\acc b -> acc `shiftL` 8 .|. fromIntegral b) 0 . B.take 4

-- | Decodes a zlib stream made of stored deflate blocks, the only kind
-- 'toPng' writes.
inflateStored :: B.ByteString -> B.ByteString
inflateStored = B.concat . blocks . B.drop 2
  where
    blocks z =
      let header = B.index z 0
          le16 i = fromIntegral (B.index z i) .|. fromIntegral (B.index z (i + 1)) `shiftL` 8 :: Word16
          len = le16 1
          block = B.take (fromIntegral len) (B.drop 5 z)
       in if le16 3 /= maxBound - len
            then error "bad NLEN"
            else block : if odd header then [] else blocks (B.drop (5 + fromIntegral len) z)

png :: Assertion
png = do
  -- Big enough for the pixel data to need more than one stored block.
  let (w, h) = (200, 120)
      img = generate w h $ \x y ->
        Vec3 (fromIntegral x / fromIntegral w) (fromIntegral y / fromIntegral h) (fromIntegral ((x + y) `mod` 7) / 7)
      bytes = BL.toStrict (toPng img)
  B.take 8 bytes @?= "\x89PNG\r\n\x1a\n"
  -- IEND's CRC is the same in every PNG, which checks the CRC code.
  B.drop (B.length bytes - 12) bytes @?= "\0\0\0\0IEND\xae\x42\x60\x82"
  case pngChunks (B.drop 8 bytes) of
    [("IHDR", header), ("IDAT", idat), ("IEND", "")] -> do
      be32 header @?= fromIntegral w
      be32 (B.drop 4 header) @?= fromIntegral h
      B.drop 8 header @?= B.pack [8, 2, 0, 0, 0]
      let raw = inflateStored idat
          rowBytes = 1 + 3 * w
      B.length raw @?= rowBytes * h
      sequence_
        [ do
            B.index row 0 @?= 0
            (B.index row (1 + 3 * x), B.index row (2 + 3 * x), B.index row (3 + 3 * x)) @?= pixelAt img x y
        | y <- [0 .. h - 1],
          let row = B.take rowBytes (B.drop (y * rowBytes) raw),
          x <- [0 .. w - 1]
        ]
    chunks -> assertFailure ("unexpected chunks " <> show (map fst chunks))

-- | Renders the test scene and compares it with test/golden.ppm.
--
-- After an intentional change to the output, run with UPDATE_GOLDEN=1 to
-- accept it. On a mismatch the rendered image is written to
-- test/golden.actual.ppm for inspection.
golden :: Assertion
golden = do
  let actual = toPpm (render 200 200 100 (Scene.camera 200 200) Scene.world)
      path = "test/golden.ppm"
  update <- lookupEnv "UPDATE_GOLDEN"
  case update of
    Just _ -> BL.writeFile path actual
    Nothing -> do
      expected <- BL.readFile path
      unless (actual == expected) $ do
        let out = "test/golden.actual.ppm"
        BL.writeFile out actual
        assertFailure ("the rendered image doesn't match " <> path <> "; wrote it to " <> out)
