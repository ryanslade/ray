namespace Raytracer

open System
open System.Buffers.Binary
open System.IO
open System.IO.Compression
open System.Text

/// An 8-bit RGB image. Row 0 is the top.
type Image =
    private
        {
            Width: int
            Height: int
            Pixels: byte array
        }

    member img.Size = img.Width, img.Height

module Image =
    let create width height =
        if width < 0 || height < 0 then
            invalidArg "width" "an image can't have a negative size"

        {
            Width = width
            Height = height
            Pixels = Array.zeroCreate (width * height * 3)
        }

    let private index img x y =
        if x < 0 || x >= img.Width || y < 0 || y >= img.Height then
            raise (ArgumentOutOfRangeException("x", $"pixel ({x}, {y}) is out of bounds"))

        3 * (y * img.Width + x)

    /// A row's RGB bytes, so that rows can be filled in independently (e.g.
    /// from different threads).
    let internal row img y =
        img.Pixels.AsMemory(3 * y * img.Width, 3 * img.Width)

    /// Writes a colour to an RGB pixel, clamping each channel to [0, 1].
    let internal writePixel (pixel: Span<byte>) (c: Color) =
        let toByte v = byte (max 0 (int (255.99 * min v 1.0)))

        pixel[0] <- toByte c.R
        pixel[1] <- toByte c.G
        pixel[2] <- toByte c.B

    /// Stores a colour, clamping each channel to [0, 1].
    let set img x y c =
        writePixel (img.Pixels.AsSpan(index img x y, 3)) c

    let get img x y =
        let i = index img x y
        img.Pixels[i], img.Pixels[i + 1], img.Pixels[i + 2]

    /// Binary (P6) PPM encoding.
    let toPpm img =
        Array.append (Encoding.ASCII.GetBytes $"P6\n{img.Width} {img.Height}\n255\n") img.Pixels

    let private crc32 (bytes: byte array) =
        let step crc (b: byte) =
            let mutable c = crc ^^^ uint32 b

            for _ in 1..8 do
                c <- if c &&& 1u = 1u then 0xedb88320u ^^^ (c >>> 1) else c >>> 1

            c

        ~~~(Array.fold step 0xffffffffu bytes)

    let private chunk (out: Stream) (kind: string) (data: byte array) =
        let typed = Array.append (Encoding.ASCII.GetBytes kind) data
        let word = Array.zeroCreate<byte> 4
        BinaryPrimitives.WriteInt32BigEndian(word, data.Length)
        out.Write word
        out.Write typed
        BinaryPrimitives.WriteUInt32BigEndian(word, crc32 typed)
        out.Write word

    /// PNG encoding: 8-bit RGB, compressed with zlib, with no filtering.
    let toPng img =
        let header = Array.zeroCreate<byte> 13
        BinaryPrimitives.WriteInt32BigEndian(header, img.Width)
        BinaryPrimitives.WriteInt32BigEndian(header.AsSpan 4, img.Height)
        // 8 bits per channel, RGB, deflate, no filtering, no interlacing.
        header[8] <- 8uy
        header[9] <- 2uy

        use compressed = new MemoryStream()

        do
            use zlib = new ZLibStream(compressed, CompressionLevel.Optimal)

            for y in 0 .. img.Height - 1 do
                // Each scanline starts with its filter type, 0 for none.
                zlib.WriteByte 0uy
                zlib.Write((row img y).Span)

        use png = new MemoryStream()
        png.Write([| 0x89uy; 'P'B; 'N'B; 'G'B; '\r'B; '\n'B; 0x1auy; '\n'B |])
        chunk png "IHDR" header
        chunk png "IDAT" (compressed.ToArray())
        chunk png "IEND" [||]
        png.ToArray()

    let savePng path img = File.WriteAllBytes(path, toPng img)
