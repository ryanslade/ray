defmodule Raytracer.CLI do
  @moduledoc "Renders the example scene: `raytracer [output.ppm]`."

  alias Raytracer.{Camera, Image, Material, Render, Rng, Sphere, Vec3, World}

  @width 800
  @height 450
  @samples 100

  def main(args) do
    output = List.first(args, "out.ppm")
    IO.puts(:stderr, "Generating world")
    world = random_world(Rng.new(1))
    look_from = {3.0, 2.0, 3.0}
    look_at = {0.0, 0.0, -1.0}

    camera =
      Camera.new(
        look_from: look_from,
        look_at: look_at,
        v_up: {0.0, 1.0, 0.0},
        vfov: 90.0,
        aspect: @width / @height,
        aperture: 0.01,
        focus_dist: Vec3.length(Vec3.sub(look_from, look_at))
      )

    IO.puts(:stderr, "Rendering on #{System.schedulers_online()} schedulers")
    img = Render.render(@width, @height, @samples, camera, world)

    case Image.save_ppm(img, output) do
      :ok ->
        IO.puts(:stderr, "Wrote #{output}")

      {:error, reason} ->
        IO.puts(:stderr, "Writing #{output}: #{:file.format_error(reason)}")
        System.halt(1)
    end
  end

  def random_world(rng) do
    ground = Sphere.new({0.0, -1000.0, -1.0}, 1000.0, Material.lambertian({0.5, 0.5, 0.5}))

    # Reduced rather than mapped, to pass the generator from each sphere to
    # the next.
    {small_spheres, _rng} =
      for a <- -11..10, b <- -11..10, reduce: {[], rng} do
        {spheres, rng} ->
          case small_sphere(rng, a, b) do
            {nil, rng} -> {spheres, rng}
            {sphere, rng} -> {[sphere | spheres], rng}
          end
      end

    large_spheres = [
      Sphere.new({4.0, 1.0, 0.0}, 1.0, Material.metal({0.8, 0.6, 0.2}, 0.1)),
      Sphere.new({0.0, 1.0, 0.0}, 1.0, Material.dielectric(1.5)),
      Sphere.new({-4.0, 1.0, 0.0}, 1.0, Material.metal({0.8, 0.8, 0.8}, 0.2))
    ]

    World.new([ground | Enum.reverse(small_spheres)] ++ large_spheres)
  end

  # A small sphere in the grid square at (a, b), or nil if it would be too
  # close to the metal sphere.
  defp small_sphere(rng, a, b) do
    {dx, rng} = Rng.next_f64(rng)
    {dz, rng} = Rng.next_f64(rng)
    center = {a + 0.9 * dx, 0.2, b + 0.9 * dz}

    if Vec3.length(Vec3.sub(center, {4.0, 0.2, 0.0})) > 0.9 do
      {r, rng} = channel(rng)
      {g, rng} = channel(rng)
      {b, rng} = channel(rng)
      {Sphere.new(center, 0.2, Material.lambertian({r, g, b})), rng}
    else
      {nil, rng}
    end
  end

  defp channel(rng) do
    {x, rng} = Rng.next_f64(rng)
    {y, rng} = Rng.next_f64(rng)
    {x * y, rng}
  end
end
