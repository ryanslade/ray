// Renders the example scene: raytracer [output.png]

using Raytracer;

const int Width = 800;
const int Height = 450;
const int Samples = 100;

string output = args.Length > 0 ? args[0] : "out.png";
Console.Error.WriteLine("Generating world");
World world = RandomWorld(new Rng(1));
var lookFrom = new Vec3(3.0, 2.0, 3.0);
var lookAt = new Vec3(0.0, 0.0, -1.0);
var camera = new Camera(
    lookFrom,
    lookAt,
    vUp: new Vec3(0.0, 1.0, 0.0),
    vfov: 90.0,
    aspect: (double)Width / Height,
    aperture: 0.01,
    focusDist: (lookFrom - lookAt).Length());
Console.Error.WriteLine($"Rendering on {Environment.ProcessorCount} threads");
Image img = Renderer.Render(Width, Height, Samples, camera, world);
try
{
    img.SavePng(output);
}
catch (IOException e)
{
    Console.Error.WriteLine($"Writing {output}: {e.Message}");
    return 1;
}
Console.Error.WriteLine($"Wrote {output}");
return 0;

static World RandomWorld(Rng rng)
{
    var spheres = new List<Sphere>
    {
        new(new Vec3(0.0, -1000.0, -1.0), 1000.0, new Lambertian(new Color(0.5, 0.5, 0.5))),
    };
    for (int a = -11; a < 11; a++)
    {
        for (int b = -11; b < 11; b++)
        {
            var center = new Vec3(a + 0.9 * rng.NextDouble(), 0.2, b + 0.9 * rng.NextDouble());
            if ((center - new Vec3(4.0, 0.2, 0.0)).Length() > 0.9)
            {
                var albedo = new Color(
                    rng.NextDouble() * rng.NextDouble(),
                    rng.NextDouble() * rng.NextDouble(),
                    rng.NextDouble() * rng.NextDouble());
                spheres.Add(new Sphere(center, 0.2, new Lambertian(albedo)));
            }
        }
    }
    spheres.Add(new Sphere(new Vec3(4.0, 1.0, 0.0), 1.0, new Metal(new Color(0.8, 0.6, 0.2), 0.1)));
    spheres.Add(new Sphere(new Vec3(0.0, 1.0, 0.0), 1.0, new Dielectric(1.5)));
    spheres.Add(new Sphere(new Vec3(-4.0, 1.0, 0.0), 1.0, new Metal(new Color(0.8, 0.8, 0.8), 0.2)));
    return new World(spheres);
}
