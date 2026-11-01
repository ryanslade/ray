using System.Buffers.Binary;
using System.IO.Compression;
using System.Text;

namespace Raytracer;

/// <summary>An 8-bit RGB image. Row 0 is the top.</summary>
public sealed class Image(int width, int height)
{
    private readonly byte[] _pixels = new byte[width * height * 3];

    public int Width { get; } = width;

    public int Height { get; } = height;

    /// <summary>Stores a colour, clamping each channel to [0, 1].</summary>
    public void Set(int x, int y, Color c) => SetPixel(_pixels.AsSpan(Index(x, y), 3), c);

    public (byte R, byte G, byte B) Get(int x, int y)
    {
        int i = Index(x, y);
        return (_pixels[i], _pixels[i + 1], _pixels[i + 2]);
    }

    /// <summary>
    /// A row's RGB bytes, so that rows can be filled in independently (e.g.
    /// from different threads).
    /// </summary>
    internal Span<byte> Row(int y) => _pixels.AsSpan(y * Width * 3, Width * 3);

    /// <summary>Writes a colour to an RGB pixel, clamping each channel to [0, 1].</summary>
    internal static void SetPixel(Span<byte> pixel, Color c) =>
        (pixel[0], pixel[1], pixel[2]) = (ToByte(c.R), ToByte(c.G), ToByte(c.B));

    private static byte ToByte(double v) => (byte)Math.Clamp(255.99 * v, 0.0, 255.0);

    /// <summary>Binary (P6) PPM encoding.</summary>
    public byte[] ToPpm() => [.. Encoding.ASCII.GetBytes($"P6\n{Width} {Height}\n255\n"), .. _pixels];

    /// <summary>PNG encoding: 8-bit RGB, compressed with zlib, with no filtering.</summary>
    public byte[] ToPng()
    {
        // 8 bits per channel, RGB, deflate, no filtering, no interlacing.
        byte[] header = [.. BigEndian(Width), .. BigEndian(Height), 8, 2, 0, 0, 0];
        using var compressed = new MemoryStream();
        using (var zlib = new ZLibStream(compressed, CompressionLevel.Optimal))
        {
            for (int y = 0; y < Height; y++)
            {
                // Each scanline starts with its filter type, 0 for none.
                zlib.WriteByte(0);
                zlib.Write(Row(y));
            }
        }

        using var png = new MemoryStream();
        png.Write([0x89, (byte)'P', (byte)'N', (byte)'G', (byte)'\r', (byte)'\n', 0x1a, (byte)'\n']);
        WriteChunk(png, "IHDR", header);
        WriteChunk(png, "IDAT", compressed.ToArray());
        WriteChunk(png, "IEND", []);
        return png.ToArray();
    }

    public void SavePng(string path) => File.WriteAllBytes(path, ToPng());

    private int Index(int x, int y) =>
        (uint)x < (uint)Width && (uint)y < (uint)Height
            ? (y * Width + x) * 3
            : throw new ArgumentOutOfRangeException(nameof(x), $"Pixel ({x}, {y}) is out of bounds.");

    private static byte[] BigEndian(int n)
    {
        var bytes = new byte[4];
        BinaryPrimitives.WriteInt32BigEndian(bytes, n);
        return bytes;
    }

    private static void WriteChunk(Stream stream, string type, byte[] data)
    {
        byte[] typed = [.. Encoding.ASCII.GetBytes(type), .. data];
        stream.Write(BigEndian(data.Length));
        stream.Write(typed);
        stream.Write(BigEndian((int)Crc32(typed)));
    }

    /// <summary>
    /// PNG's CRC-32. The class library's is in a separate package,
    /// System.IO.Hashing.
    /// </summary>
    private static uint Crc32(byte[] bytes)
    {
        uint crc = 0xffffffff;
        foreach (byte b in bytes)
        {
            crc ^= b;
            for (int i = 0; i < 8; i++)
            {
                crc = (crc & 1) == 1 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
            }
        }
        return ~crc;
    }
}
