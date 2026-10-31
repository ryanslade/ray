namespace Raytracer.Tests;

public class RenderTests
{
    [Fact]
    public void TheImageIsTheSameWhateverTheNumberOfThreads()
    {
        Camera camera = Scene.Camera(40, 30);
        World world = Scene.World();
        byte[] Render(int threads) => Renderer.Render(40, 30, 8, camera, world, threads).ToPpm();
        byte[] expected = Render(1);
        foreach (int threads in new[] { 2, 4, 7 })
        {
            Assert.True(Render(threads).SequenceEqual(expected), $"{threads} threads");
        }
    }

    /// <summary>
    /// Renders the test scene and compares it with golden.ppm.
    /// </summary>
    /// <remarks>
    /// After an intentional change to the output, run with UPDATE_GOLDEN=1 to
    /// accept it. On a mismatch the rendered image is written to
    /// golden.actual.ppm for inspection.
    /// </remarks>
    [Fact]
    public void GoldenImage()
    {
        byte[] actual = Renderer.Render(200, 200, 100, Scene.Camera(200, 200), Scene.World()).ToPpm();
        string dir = SourceDirectory();
        string golden = Path.Join(dir, "golden.ppm");
        if (Environment.GetEnvironmentVariable("UPDATE_GOLDEN") is not null)
        {
            File.WriteAllBytes(golden, actual);
            return;
        }
        if (!actual.AsSpan().SequenceEqual(File.ReadAllBytes(golden)))
        {
            string output = Path.Join(dir, "golden.actual.ppm");
            File.WriteAllBytes(output, actual);
            Assert.Fail($"The rendered image doesn't match {golden}; wrote it to {output}");
        }
    }

    private static string SourceDirectory([System.Runtime.CompilerServices.CallerFilePath] string path = "") =>
        Path.GetDirectoryName(path)!;
}
