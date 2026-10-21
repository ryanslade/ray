defmodule Raytracer.Render do
  alias Raytracer.{Camera, Image, Material, Rng, Vec3, World}

  @max_depth 50
  @sky_blue {0.5, 0.7, 1.0}
  # The largest finite float, which Rust calls f64::MAX.
  @max_float 1.7976931348623157e308

  @doc "The colour seen along a ray, following up to 50 bounces."
  def ray_color(world, ray, rng), do: bounce(world, ray, Vec3.white(), 0, rng)

  # `attenuation` is the product of the attenuations of every surface hit so
  # far.
  defp bounce(world, ray, attenuation, depth, rng) do
    case World.hit(world, ray, 0.001, @max_float) do
      nil ->
        {Vec3.mul(attenuation, sky(ray)), rng}

      _ when depth == @max_depth ->
        {Vec3.black(), rng}

      {_t, _point, _normal, material} = hit ->
        case Material.scatter(material, ray, hit, rng) do
          {nil, rng} ->
            {Vec3.black(), rng}

          {{a, scattered}, rng} ->
            bounce(world, scattered, Vec3.mul(attenuation, a), depth + 1, rng)
        end
    end
  end

  defp sky({_origin, direction}) do
    {_, y, _} = Vec3.unit(direction)
    t = 0.5 * (y + 1.0)
    Vec3.add(Vec3.scale(1.0 - t, Vec3.white()), Vec3.scale(t, @sky_blue))
  end

  @doc """
  Renders the world with `samples` rays per pixel.

  Rows are rendered in parallel, by up to `:concurrency` processes at once
  (by default one per scheduler, so one per core). Each row uses its own random
  state seeded from the row index, so the image is identical regardless of
  the concurrency.
  """
  def render(width, height, samples, %Camera{} = camera, %World{} = world, opts \\ []) do
    concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())

    pixels =
      0..(height - 1)//1
      |> Task.async_stream(&render_row(&1, width, height, samples, camera, world),
        max_concurrency: concurrency,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, row} -> row end)

    %Image{width: width, height: height, pixels: IO.iodata_to_binary(pixels)}
  end

  defp render_row(y, width, height, samples, camera, world) do
    {row, _rng} =
      Enum.map_reduce(0..(width - 1)//1, Rng.new(y + 1), fn x, rng ->
        {color, rng} = sample(x, y, width, height, samples, camera, world, Vec3.black(), rng)
        {Image.encode(Vec3.div(color, :erlang.float(samples))), rng}
      end)

    row
  end

  # Adds up `n` samples of the pixel at (x, y).
  defp sample(_x, _y, _width, _height, 0, _camera, _world, sum, rng), do: {sum, rng}

  defp sample(x, y, width, height, n, camera, world, sum, rng) do
    {du, rng} = Rng.next_f64(rng)
    {dv, rng} = Rng.next_f64(rng)
    u = (x + du) / width
    v = (height - 1 - y + dv) / height
    {ray, rng} = Camera.get_ray(camera, u, v, rng)
    {color, rng} = ray_color(world, ray, rng)
    sample(x, y, width, height, n - 1, camera, world, Vec3.add(sum, color), rng)
  end
end
