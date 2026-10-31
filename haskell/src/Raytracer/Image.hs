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

import Data.Bits (complement, shiftL, shiftR, xor, (.&.), (.|.))
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
    BB.byteString (B.pack [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
      <> chunk "IHDR" header
      <> chunk "IDAT" (zlibStored raw)
      <> chunk "IEND" B.empty
  where
    -- 8 bits per channel, RGB, deflate, no filtering, no interlacing.
    header =
      strict $
        BB.word32BE (fromIntegral img.width)
          <> BB.word32BE (fromIntegral img.height)
          <> BB.byteString (B.pack [8, 2, 0, 0, 0])
    -- Each scanline starts with its filter type, 0 for none.
    raw = B.concat [B.cons 0 row | row <- chunksOf (3 * img.width) img.pixels]

writePng :: FilePath -> Image -> IO ()
writePng path = BL.writeFile path . toPng

chunk :: String -> B.ByteString -> BB.Builder
chunk kind body =
  BB.word32BE (fromIntegral (B.length body))
    <> BB.byteString typed
    <> BB.word32BE (crc32 typed)
  where
    typed = strict (BB.string7 kind <> BB.byteString body)

-- | A zlib stream holding the data in uncompressed (stored) deflate blocks,
-- which can be at most 65535 bytes each. The boot packages have no
-- compressor, and this keeps the encoder small at the cost of file size.
zlibStored :: B.ByteString -> B.ByteString
zlibStored bytes =
  strict $
    BB.word8 0x78
      <> BB.word8 0x01
      <> blocks (chunksOf 65535 bytes)
      <> BB.word32BE (adler32 bytes)
  where
    blocks [] = block True B.empty
    blocks [final] = block True final
    blocks (b : rest) = block False b <> blocks rest
    block final b =
      let len = fromIntegral (B.length b) :: Word16
       in BB.word8 (if final then 1 else 0)
            <> BB.word16LE len
            <> BB.word16LE (complement len)
            <> BB.byteString b

crc32 :: B.ByteString -> Word32
crc32 = complement . B.foldl' step 0xffffffff
  where
    step c b = bits (8 :: Int) (c `xor` fromIntegral b)
    bits 0 c = c
    bits n c
      | c .&. 1 == 1 = bits (n - 1) (0xedb88320 `xor` (c `shiftR` 1))
      | otherwise = bits (n - 1) (c `shiftR` 1)

adler32 :: B.ByteString -> Word32
adler32 bytes = (b `shiftL` 16) .|. a
  where
    (a, b) = B.foldl' step (1, 0) bytes
    step (!s1, !s2) w =
      let s1' = (s1 + fromIntegral w) `mod` 65521
       in (s1', (s2 + s1') `mod` 65521)

chunksOf :: Int -> B.ByteString -> [B.ByteString]
chunksOf n bytes
  | B.null bytes = []
  | otherwise = let (h, rest) = B.splitAt n bytes in h : chunksOf n rest

strict :: BB.Builder -> B.ByteString
strict = BL.toStrict . BB.toLazyByteString
