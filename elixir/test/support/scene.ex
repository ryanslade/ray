defmodule Raytracer.Scene do
  @moduledoc "The scene used by the tests and benchmark, matching the other versions."

  alias Raytracer.{Camera, Material, Sphere, Vec3, World}

  def world do
    World.new([
      Sphere.new({0.0, -100.5, -1.0}, 100.0, Material.lambertian({0.5, 0.5, 0.5})),
      Sphere.new({0.0, 0.0, -1.0}, 1.0, Material.metal({0.8, 0.8, 0.8}, 0.2)),
      Sphere.new({1.5, 0.0, -1.0}, 1.0, Material.dielectric(1.5))
    ])
  end

  def camera(width, height) do
    look_from = {1.0, 1.0, 1.0}
    look_at = {0.0, 0.0, -1.0}

    Camera.new(
      look_from: look_from,
      look_at: look_at,
      v_up: {0.0, 1.0, 0.0},
      vfov: 90.0,
      aspect: width / height,
      aperture: 0.01,
      focus_dist: Vec3.length(Vec3.sub(look_from, look_at))
    )
  end
end
