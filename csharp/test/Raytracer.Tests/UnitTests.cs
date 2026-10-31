using System.Buffers.Binary;
using System.IO.Compression;

namespace Raytracer.Tests;

public class UnitTests
{
    private static void AssertClose(Vec3 expected, Vec3 actual) =>
        Assert.True((expected - actual).Length() < 1e-9, $"{expected} != {actual}");

    [Fact]
    public void VectorArithmetic()
    {
        var a = new Vec3(1.0, 2.0, 3.0);
        var b = new Vec3(4.0, 5.0, 6.0);
        AssertClose(new Vec3(5.0, 7.0, 9.0), a + b);
        AssertClose(new Vec3(2.0, 4.0, 6.0), 2.0 * a);
        Assert.Equal(32.0, a.Dot(b));
        AssertClose(new Vec3(-3.0, 6.0, -3.0), a.Cross(b));
        Assert.Equal(1.0, b.Unit().Length(), 1e-9);
    }

    [Fact]
    public void RandomNumbersAreInTheUnitInterval()
    {
        var rng = new Rng(1);
        for (int i = 0; i < 10_000; i++)
        {
            Assert.InRange(rng.NextDouble(), 0.0, Math.BitDecrement(1.0));
        }
    }

    [Fact]
    public void TheSameSeedGivesTheSameSequence()
    {
        var a = new Rng(42);
        var b = new Rng(42);
        for (int i = 0; i < 100; i++)
        {
            Assert.Equal(a.NextUInt64(), b.NextUInt64());
        }
    }

    [Fact]
    public void TheGeneratorMatchesSplitMix64()
    {
        // The first outputs for seed 0 from the reference implementation.
        var rng = new Rng(0);
        Assert.Equal(0xe220a8397b1dcdafUL, rng.NextUInt64());
        Assert.Equal(0x6e789e6aa1b965f4UL, rng.NextUInt64());
    }

    [Fact]
    public void ARayHitsASphere()
    {
        var s = new Sphere(new Vec3(0.0, 0.0, -1.0), 0.5, new Dielectric(1.5));
        var towards = new Ray(Vec3.Zero, new Vec3(0.0, 0.0, -1.0));

        Assert.True(s.TryHit(towards, 0.0, double.PositiveInfinity, out Hit hit));
        Assert.Equal(0.5, hit.T);
        Assert.Equal(new Vec3(0.0, 0.0, 1.0), hit.Normal);

        Assert.True(s.TryHit(towards, 0.6, double.PositiveInfinity, out Hit far));
        Assert.Equal(1.5, far.T);

        var away = new Ray(Vec3.Zero, new Vec3(0.0, 1.0, 0.0));
        Assert.False(s.TryHit(away, 0.0, double.PositiveInfinity, out _));
    }

    [Fact]
    public void TheWorldFindsTheClosestHit()
    {
        var m = new Dielectric(1.5);
        var world = new World([new Sphere(new Vec3(0.0, 0.0, -5.0), 1.0, m), new Sphere(new Vec3(0.0, 0.0, -2.0), 0.5, m)]);
        var ray = new Ray(Vec3.Zero, new Vec3(0.0, 0.0, -1.0));
        Assert.True(world.TryHit(ray, 0.0, double.PositiveInfinity, out Hit hit));
        Assert.Equal(1.5, hit.T);
    }

    [Fact]
    public void TotalInternalReflection() =>
        Assert.Null(Material.Refract(new Vec3(1.0, -0.1, 0.0), new Vec3(0.0, 1.0, 0.0), 1.5));

    [Fact]
    public void RefractsHeadOn()
    {
        var down = new Vec3(0.0, -1.0, 0.0);
        Vec3? refracted = Material.Refract(down, new Vec3(0.0, 1.0, 0.0), 1.0 / 1.5);
        Assert.NotNull(refracted);
        AssertClose(down, refracted.Value);
    }

    [Fact]
    public void MetalFuzzIsClamped()
    {
        Assert.Equal(1.0, new Metal(Color.White, 2.0).Fuzz);
        Assert.Equal(0.0, new Metal(Color.White, -1.0).Fuzz);
    }

    [Fact]
    public void SettingAPixelClampsEachChannel()
    {
        var img = new Image(2, 1);
        img.Set(1, 0, new Color(2.0, 0.5, -1.0));
        Assert.Equal(((byte)0, (byte)0, (byte)0), img.Get(0, 0));
        Assert.Equal(((byte)255, (byte)127, (byte)0), img.Get(1, 0));
        Assert.Throws<ArgumentOutOfRangeException>(() => img.Get(2, 0));
    }

    [Fact]
    public void PpmHeader()
    {
        byte[] ppm = new Image(3, 2).ToPpm();
        Assert.Equal("P6\n3 2\n255\n"u8.ToArray(), ppm[..11]);
        Assert.Equal(11 + 3 * 2 * 3, ppm.Length);
    }

    [Fact]
    public void Png()
    {
        const int width = 20;
        const int height = 12;
        var img = new Image(width, height);
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                img.Set(x, y, new Color((double)x / width, (double)y / height, (x + y) % 7 / 7.0));
            }
        }

        byte[] png = img.ToPng();
        Assert.Equal([0x89, (byte)'P', (byte)'N', (byte)'G', (byte)'\r', (byte)'\n', 0x1a, (byte)'\n'], png[..8]);
        // IEND's CRC is the same in every PNG, which checks the CRC code.
        Assert.Equal([0, 0, 0, 0, (byte)'I', (byte)'E', (byte)'N', (byte)'D', 0xae, 0x42, 0x60, 0x82], png[^12..]);

        List<(string Type, byte[] Data)> chunks = PngChunks(png);
        Assert.Equal(["IHDR", "IDAT", "IEND"], chunks.Select(c => c.Type));
        byte[] header = chunks[0].Data;
        Assert.Equal(width, BinaryPrimitives.ReadInt32BigEndian(header));
        Assert.Equal(height, BinaryPrimitives.ReadInt32BigEndian(header.AsSpan(4)));
        Assert.Equal([8, 2, 0, 0, 0], header[8..]);

        using var zlib = new ZLibStream(new MemoryStream(chunks[1].Data), CompressionMode.Decompress);
        using var raw = new MemoryStream();
        zlib.CopyTo(raw);
        const int rowBytes = 1 + 3 * width;
        Assert.Equal(rowBytes * height, raw.Length);
        byte[] rows = raw.ToArray();
        for (int y = 0; y < height; y++)
        {
            Assert.Equal(0, rows[y * rowBytes]);
            for (int x = 0; x < width; x++)
            {
                int i = y * rowBytes + 1 + 3 * x;
                Assert.Equal(img.Get(x, y), (rows[i], rows[i + 1], rows[i + 2]));
            }
        }
    }

    /// <summary>Splits a PNG into its chunks.</summary>
    private static List<(string Type, byte[] Data)> PngChunks(byte[] png)
    {
        var chunks = new List<(string, byte[])>();
        for (int pos = 8; pos < png.Length;)
        {
            int length = BinaryPrimitives.ReadInt32BigEndian(png.AsSpan(pos));
            chunks.Add((System.Text.Encoding.ASCII.GetString(png, pos + 4, 4), png[(pos + 8)..(pos + 8 + length)]));
            pos += 12 + length;
        }
        return chunks;
    }
}
