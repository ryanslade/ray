namespace Raytracer;

public static class Renderer
{
    private const int MaxDepth = 50;
    private static readonly Color SkyBlue = new(0.5, 0.7, 1.0);

    /// <summary>The colour seen along a ray, following up to 50 bounces.</summary>
    public static Color RayColor(World world, Ray ray, Rng rng)
    {
        // The product of the attenuations of every surface hit so far.
        Color attenuation = Color.White;
        for (int depth = 0; depth <= MaxDepth; depth++)
        {
            if (!world.TryHit(ray, 0.001, double.MaxValue, out Hit hit))
            {
                return attenuation * Sky(ray);
            }
            if (depth == MaxDepth || !hit.Material.Scatter(ray, hit, rng, out Color a, out Ray scattered))
            {
                break;
            }
            attenuation *= a;
            ray = scattered;
        }
        return Color.Black;
    }

    private static Color Sky(Ray ray)
    {
        double t = 0.5 * (ray.Direction.Unit().Y + 1.0);
        return (1.0 - t) * Color.White + t * SkyBlue;
    }

    /// <summary>
    /// Renders the world with <paramref name="samples"/> rays per pixel, in
    /// parallel on up to <paramref name="threads"/> threads (by default, one
    /// per core).
    /// </summary>
    /// <remarks>
    /// Each row uses its own random state seeded from the row index, so the
    /// image is identical regardless of the number of threads.
    /// </remarks>
    public static Image Render(int width, int height, int samples, Camera camera, World world, int? threads = null)
    {
        ArgumentNullException.ThrowIfNull(camera);
        ArgumentNullException.ThrowIfNull(world);
        var options = new ParallelOptions { MaxDegreeOfParallelism = threads ?? Environment.ProcessorCount };
        var img = new Image(width, height);
        // Rows vary a lot in cost (sky is cheap, spheres are expensive), and
        // Parallel.For balances them across the threads as it goes.
        Parallel.For(0, height, options, y => RenderRow(img.Row(y), y, width, height, samples, camera, world));
        return img;
    }

    private static void RenderRow(Span<byte> row, int y, int width, int height, int samples, Camera camera, World world)
    {
        var rng = new Rng((ulong)y + 1);
        for (int x = 0; x < width; x++)
        {
            Color c = Color.Black;
            for (int s = 0; s < samples; s++)
            {
                double u = (x + rng.NextDouble()) / width;
                double v = (height - 1 - y + rng.NextDouble()) / height;
                c += RayColor(world, camera.GetRay(u, v, rng), rng);
            }
            Image.SetPixel(row.Slice(x * 3, 3), c / samples);
        }
    }
}
