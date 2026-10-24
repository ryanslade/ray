defmodule Raytracer.UnitTest do
  use ExUnit.Case, async: true

  alias Raytracer.{Image, Material, Rng, Sphere, Vec3, World}

  defp close?(a, b), do: Vec3.length(Vec3.sub(a, b)) < 1.0e-9

  # Erlang floats are never NaN or infinite, so where the other versions pass
  # infinity as t_max, these pass the largest finite float.
  @max_float 1.7976931348623157e308

  test "vector arithmetic" do
    a = {1.0, 2.0, 3.0}
    b = {4.0, 5.0, 6.0}
    assert close?({5.0, 7.0, 9.0}, Vec3.add(a, b))
    assert close?({2.0, 4.0, 6.0}, Vec3.scale(2.0, a))
    assert Vec3.dot(a, b) == 32.0
    assert close?({-3.0, 6.0, -3.0}, Vec3.cross(a, b))
    assert abs(Vec3.length(Vec3.unit(b)) - 1.0) < 1.0e-9
  end

  test "random floats are in [0, 1)" do
    {floats, _} = Enum.map_reduce(1..10_000, Rng.new(1), fn _, rng -> Rng.next_f64(rng) end)
    assert Enum.all?(floats, &(&1 >= 0.0 and &1 < 1.0))
  end

  test "the same seed gives the same sequence" do
    sequence = fn ->
      Enum.map_reduce(1..100, Rng.new(42), fn _, rng -> Rng.next_u64(rng) end) |> elem(0)
    end

    assert sequence.() == sequence.()
  end

  test "the generator matches SplitMix64" do
    # The first outputs for seed 0 from the reference implementation.
    {a, rng} = Rng.next_u64(Rng.new(0))
    {b, _} = Rng.next_u64(rng)
    assert a == 0xE220A8397B1DCDAF
    assert b == 0x6E789E6AA1B965F4
  end

  test "a ray hits a sphere" do
    m = Material.dielectric(1.5)
    s = Sphere.new({0.0, 0.0, -1.0}, 0.5, m)
    towards = {{0.0, 0.0, 0.0}, {0.0, 0.0, -1.0}}

    assert {0.5, _point, {+0.0, +0.0, 1.0}, ^m} = Sphere.hit(s, towards, 0.0, @max_float)
    assert {1.5, _, _, _} = Sphere.hit(s, towards, 0.6, @max_float), "far side"
    assert Sphere.hit(s, {{0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}}, 0.0, @max_float) == nil
  end

  test "the world finds the closest hit" do
    m = Material.dielectric(1.5)

    w =
      World.new([
        Sphere.new({0.0, 0.0, -5.0}, 1.0, m),
        Sphere.new({0.0, 0.0, -2.0}, 0.5, m)
      ])

    assert {1.5, _, _, _} = World.hit(w, {{0.0, 0.0, 0.0}, {0.0, 0.0, -1.0}}, 0.0, @max_float)
    assert World.hit(w, {{0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}}, 0.0, @max_float) == nil
  end

  # World.hit has its own copy of the intersection arithmetic, which must find
  # exactly the hit that Sphere.hit on each sphere in turn would.
  test "the world matches testing sphere by sphere" do
    {coords, _} =
      Enum.map_reduce(1..(23 * 4 + 2000 * 6), Rng.new(1), fn _, rng ->
        {x, rng} = Rng.next_f64(rng)
        {2.0 * x - 1.0, rng}
      end)

    {sphere_coords, ray_coords} = Enum.split(coords, 23 * 4)
    m = Material.dielectric(1.5)

    spheres =
      for [x, y, z, r] <- Enum.chunk_every(sphere_coords, 4) do
        Sphere.new({3.0 * x, 3.0 * y, 3.0 * z}, 0.1 + abs(r), m)
      end

    world = World.new(spheres)

    for [ox, oy, oz, dx, dy, dz] <- Enum.chunk_every(ray_coords, 6) do
      ray = {{5.0 * ox, 5.0 * oy, 5.0 * oz}, {dx, dy, dz}}

      want =
        Enum.reduce(spheres, {nil, @max_float}, fn s, {hit, t_max} ->
          case Sphere.hit(s, ray, 0.001, t_max) do
            nil -> {hit, t_max}
            {t, _, _, _} = closer -> {closer, t}
          end
        end)
        |> elem(0)

      assert World.hit(world, ray, 0.001, @max_float) == want
    end
  end

  test "total internal reflection" do
    assert Material.refract({1.0, -0.1, 0.0}, {0.0, 1.0, 0.0}, 1.5) == nil
  end

  test "refracts head on" do
    down = {0.0, -1.0, 0.0}
    assert close?(down, Material.refract(down, {0.0, 1.0, 0.0}, 1.0 / 1.5))
  end

  test "metal fuzz is clamped" do
    assert {:metal, _, 1.0} = Material.metal(Vec3.white(), 2.0)
    assert {:metal, _, +0.0} = Material.metal(Vec3.white(), -1.0)
  end

  test "setting a pixel clamps each channel" do
    img = Image.new(3, 1) |> Image.set_pixel(1, 0, {2.0, 0.5, -1.0})
    assert Image.pixel(img, 0, 0) == {0, 0, 0}
    assert Image.pixel(img, 1, 0) == {255, 127, 0}
    assert_raise ArgumentError, fn -> Image.pixel(img, 3, 0) end
  end

  test "PPM header" do
    ppm = Image.to_ppm(Image.new(3, 2))
    assert binary_part(ppm, 0, 11) == "P6\n3 2\n255\n"
    assert byte_size(ppm) == 11 + 3 * 2 * 3
  end

  # Splits a PNG into its chunks, as {type, data} pairs, checking their CRCs.
  defp png_chunks(<<>>), do: []

  defp png_chunks(
         <<len::32, type::binary-size(4), data::binary-size(len), crc::32, rest::binary>>
       ) do
    assert crc == :erlang.crc32(type <> data), "#{type} CRC"
    [{type, data} | png_chunks(rest)]
  end

  test "PNG" do
    {width, height} = {20, 12}

    img =
      for y <- 0..(height - 1), x <- 0..(width - 1), reduce: Image.new(width, height) do
        img -> Image.set_pixel(img, x, y, {x / width, y / height, rem(x + y, 7) / 7})
      end

    assert <<0x89, "PNG\r\n", 0x1A, "\n", rest::binary>> = Image.to_png(img)
    assert [{"IHDR", header}, {"IDAT", data}, {"IEND", ""}] = png_chunks(rest)
    assert header == <<width::32, height::32, 8, 2, 0, 0, 0>>

    raw = :zlib.uncompress(data)
    row_bytes = 1 + 3 * width
    assert byte_size(raw) == row_bytes * height

    for y <- 0..(height - 1) do
      assert <<0, row::binary>> = binary_part(raw, y * row_bytes, row_bytes)

      for x <- 0..(width - 1) do
        <<r, g, b>> = binary_part(row, 3 * x, 3)
        assert {r, g, b} == Image.pixel(img, x, y), "pixel (#{x}, #{y})"
      end
    end
  end
end
