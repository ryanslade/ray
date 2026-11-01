-- | 8-bit RGB images. Row 0 is the top.
module Raytracer.Image
  ( Image (width, height),
    generate,
    fromRows,
    encode,
    pixelAt,
    toPpm,
    toPng,
    writePng,
  )
where

import Data.Bits (complement, shiftL, shiftR, testBit, xor, (.|.))
import Data.ByteString qualified as B
import Data.ByteString.Builder qualified as BB
import Data.ByteString.Lazy qualified as BL
import Data.Word (Word16, Word32, Word8)
import Raytracer.Vec3

data Image = Image {width, height :: !Int, pixels :: !B.ByteString}
  deriving (Eq)

-- | An image with the colour of each pixel given by a function of its
-- coordinates.
generate :: Int -> Int -> (Int -> Int -> Color) -> Image
generate w h f =
  fromRows w h [B.concat [encode (f px py) | px <- [0 .. w - 1]] | py <- [0 .. h - 1]]

-- | An image from its rows, each three bytes per pixel.
fromRows :: Int -> Int -> [B.ByteString] -> Image
fromRows w h rows
  | B.length pixels /= 3 * w * h = error "Image.fromRows: wrong number of bytes"
  | otherwise = Image {width = w, height = h, pixels}
  where
    pixels = B.concat rows

-- | A colour as three bytes, clamping each channel to [0, 1].
encode :: Color -> B.ByteString
encode (Vec3 r g b) = B.pack [toByte r, toByte g, toByte b]
  where
    toByte c = fromIntegral (max 0 (truncate (255.99 * min c 1) :: Int))

pixelAt :: Image -> Int -> Int -> (Word8, Word8, Word8)
pixelAt img px py
  | px < 0 || px >= img.width || py < 0 || py >= img.height =
      error ("Image.pixelAt: " <> show (px, py) <> " is out of bounds")
  | otherwise = (byte 0, byte 1, byte 2)
  where
    byte i = B.index img.pixels (3 * (py * img.width + px) + i)

-- | Binary (P6) PPM encoding.
toPpm :: Image -> BL.ByteString
toPpm img =
  BB.toLazyByteString $
    BB.string7 ("P6\n" <> show img.width <> " " <> show img.height <> "\n255\n")
      <> BB.byteString img.pixels

-- | PNG encoding. The pixel data is stored uncompressed, so the file is
-- about the same size as the PPM.
toPng :: Image -> BL.ByteString
toPng img =
  BB.toLazyByteString $
    BB.word64BE 0x89504e470d0a1a0a
      <> chunk "IHDR" (BB.word32BE (fromIntegral img.width) <> BB.word32BE (fromIntegral img.height) <> header)
      <> chunk "IDAT" (zlibStored raw)
      <> chunk "IEND" mempty
  where
    -- 8 bits per channel, RGB, deflate, no filtering, no interlacing.
    header = foldMap BB.word8 [8, 2, 0, 0, 0]
    -- Each scanline starts with its filter type, 0 for none.
    raw = B.concat [B.cons 0 row | row <- chunksOf (3 * img.width) img.pixels]

writePng :: FilePath -> Image -> IO ()
writePng path = BL.writeFile path . toPng

chunk :: String -> BB.Builder -> BB.Builder
chunk kind body = BB.word32BE (fromIntegral (B.length typed - 4)) <> BB.byteString typed <> BB.word32BE (crc32 typed)
  where
    typed = BL.toStrict (BB.toLazyByteString (BB.string7 kind <> body))

-- | A zlib stream holding the data in uncompressed (stored) deflate blocks,
-- which can be at most 65535 bytes each. The boot packages have no
-- compressor, and this keeps the encoder small at the cost of file size.
zlibStored :: B.ByteString -> BB.Builder
zlibStored bytes = BB.word16BE 0x7801 <> foldMap block (zip [1 ..] blocks) <> BB.word32BE adler32
  where
    blocks = if B.null bytes then [B.empty] else chunksOf 65535 bytes
    block (i, b) =
      let len = fromIntegral (B.length b) :: Word16
       in BB.word8 (if i == length blocks then 1 else 0) <> BB.word16LE len <> BB.word16LE (complement len) <> BB.byteString b
    adler32 = let (a, b) = B.foldl' step (1, 0) bytes in b `shiftL` 16 .|. a
    step (!a, !b) w = let a' = (a + fromIntegral w) `mod` 65521 in (a', (b + a') `mod` 65521)

crc32 :: B.ByteString -> Word32
crc32 = complement . B.foldl' (\c b -> iterate shift (c `xor` fromIntegral b) !! 8) 0xffffffff
  where
    shift c = if testBit c 0 then 0xedb88320 `xor` (c `shiftR` 1) else c `shiftR` 1

chunksOf :: Int -> B.ByteString -> [B.ByteString]
chunksOf n bytes
  | B.null bytes = []
  | otherwise = let (h, rest) = B.splitAt n bytes in h : chunksOf n rest
