defmodule Raytracer.Material do
  @moduledoc "Materials, as tagged tuples."

  alias Raytracer.{Ray, Rng, Vec3}

  @type t ::
          {:lambertian, albedo :: Vec3.t()}
          | {:metal, albedo :: Vec3.t(), fuzz :: float}
          | {:dielectric, ref_index :: float}

  def lambertian(albedo), do: {:lambertian, albedo}

  @doc "`fuzz` is clamped to [0, 1]: 0 is a perfect mirror."
  def metal(albedo, fuzz), do: {:metal, albedo, fuzz |> min(1.0) |> max(0.0)}

  def dielectric(ref_index), do: {:dielectric, ref_index}

  @doc """
  The attenuation and scattered ray, or nil if the ray is absorbed, with the
  generator's new state.
  """
  @spec scatter(t, Ray.t(), Raytracer.Hit.t(), Rng.t()) ::
          {{Vec3.t(), Ray.t()} | nil, Rng.t()}
  def scatter({:lambertian, albedo}, _ray_in, {_t, point, normal, _}, rng) do
    {r, rng} = Vec3.random_in_unit_sphere(rng)
    target = point |> Vec3.add(normal) |> Vec3.add(r)
    {{albedo, Ray.new(point, Vec3.sub(target, point))}, rng}
  end

  def scatter({:metal, albedo, fuzz}, {_, direction}, {_t, point, normal, _}, rng) do
    reflected = reflect(Vec3.unit(direction), normal)
    {r, rng} = Vec3.random_in_unit_sphere(rng)
    direction = Vec3.add(reflected, Vec3.scale(fuzz, r))

    if Vec3.dot(direction, normal) > 0.0,
      do: {{albedo, Ray.new(point, direction)}, rng},
      else: {nil, rng}
  end

  def scatter({:dielectric, ref_index}, {_, d}, {_t, point, normal, _}, rng) do
    d_dot_n = Vec3.dot(d, normal)

    {outward_normal, ni_over_nt, cosine} =
      if d_dot_n > 0.0,
        do: {Vec3.neg(normal), ref_index, ref_index * d_dot_n / Vec3.length(d)},
        else: {normal, 1.0 / ref_index, -d_dot_n / Vec3.length(d)}

    # Only draws a random number when the ray can refract.
    {direction, rng} =
      case refract(d, outward_normal, ni_over_nt) do
        nil ->
          {reflect(d, normal), rng}

        refracted ->
          {p, rng} = Rng.next_f64(rng)

          if p >= schlick(cosine, ref_index),
            do: {refracted, rng},
            else: {reflect(d, normal), rng}
      end

    {{Vec3.white(), Ray.new(point, direction)}, rng}
  end

  defp reflect(v, n), do: Vec3.sub(v, Vec3.scale(2.0 * Vec3.dot(v, n), n))

  @doc false
  # The refracted ray's direction, or nil on total internal reflection.
  def refract(v, n, ni_over_nt) do
    uv = Vec3.unit(v)
    dt = Vec3.dot(uv, n)
    discriminant = 1.0 - ni_over_nt * ni_over_nt * (1.0 - dt * dt)

    if discriminant > 0.0 do
      Vec3.sub(
        Vec3.scale(ni_over_nt, Vec3.sub(uv, Vec3.scale(dt, n))),
        Vec3.scale(:math.sqrt(discriminant), n)
      )
    end
  end

  # Schlick's approximation for reflectance at a given angle.
  defp schlick(cosine, ref_index) do
    r0 = (1.0 - ref_index) / (1.0 + ref_index)
    r0 = r0 * r0
    # Multiplied out rather than using :math.pow, to match the other versions'
    # golden image.
    x = 1.0 - cosine
    x2 = x * x
    r0 + (1.0 - r0) * x2 * x2 * x
  end
end
