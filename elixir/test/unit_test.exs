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
end
