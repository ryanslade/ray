// Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with
// 50 samples per pixel. Usage: Raytracer.Bench [iterations] [threads]

using System.Diagnostics;
using Raytracer;
using Raytracer.Tests;

int iterations = args.Length > 0 ? int.Parse(args[0]) : 20;
int threads = args.Length > 1 ? int.Parse(args[1]) : Environment.ProcessorCount;

Camera camera = Scene.Camera(100, 100);
World world = Scene.World();
Image Run() => Renderer.Render(100, 100, 50, camera, world, threads);

// Warms up, so that the JIT has compiled the optimised code.
Run();
var stopwatch = Stopwatch.StartNew();
for (int i = 0; i < iterations; i++)
{
    Run();
}
Console.WriteLine($"{iterations} iterations on {threads} threads: {stopwatch.Elapsed.TotalMilliseconds / iterations:F2} ms/op");
