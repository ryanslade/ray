defmodule Raytracer.Sphere do
  alias Raytracer.{Ray, Vec3}

  @enforce_keys [:center, :radius, :material]
  defstruct [:center, :radius, :material]

  def new(center, radius, material) do
    %__MODULE__{center: center, radius: radius, material: material}
  end

  @doc """
  The nearest t in (`t_min`, `t_max`) at which the ray meets the sphere, or nil
  if there is none.
  """
  def intersect(%__MODULE__{center: center, radius: radius}, {origin, direction}, t_min, t_max) do
    oc = Vec3.sub(origin, center)
    a = Vec3.dot(direction, direction)
    b = Vec3.dot(oc, direction)
    c = Vec3.dot(oc, oc) - radius * radius
    discriminant = b * b - a * c

    if discriminant >= 0.0 do
      sqrt_d = :math.sqrt(discriminant)
      near = (-b - sqrt_d) / a
      far = (-b + sqrt_d) / a

      cond do
        near < t_max and near > t_min -> near
        far < t_max and far > t_min -> far
        true -> nil
      end
    end
  end

  @doc "The hit record for a t returned by `intersect/4`."
  def hit_at(%__MODULE__{center: center, radius: radius, material: material}, ray, t) do
    point = Ray.at(ray, t)
    {t, point, Vec3.div(Vec3.sub(point, center), radius), material}
  end

  @doc """
  The hit record for the nearest point in (`t_min`, `t_max`) at which the ray
  meets the sphere, or nil.
  """
  def hit(sphere, ray, t_min, t_max) do
    case intersect(sphere, ray, t_min, t_max) do
      nil -> nil
      t -> hit_at(sphere, ray, t)
    end
  end
end
