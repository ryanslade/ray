defmodule Raytracer.World do
  alias Raytracer.Sphere

  # `entries` holds each sphere's centre and squared radius as plain floats
  # in a tuple, with the sphere, so that the closest-hit loop doesn't take
  # apart the sphere and its centre for every ray.
  @enforce_keys [:spheres, :entries]
  defstruct [:spheres, :entries]

  def new(spheres) do
    entries =
      for %Sphere{center: {x, y, z}, radius: r} = s <- spheres do
        {x, y, z, r * r, s}
      end

    %__MODULE__{spheres: spheres, entries: entries}
  end

  @doc """
  The closest hit in (`t_min`, `t_max`), shrinking `t_max` as nearer spheres
  are found, or nil.

  This finds the same hit as calling `Sphere.intersect/4` on each sphere in
  turn, with the same arithmetic, so renders are unchanged; but it works on
  plain floats, and only builds the hit record for the closest sphere.
  """
  # The guards tell the compiler that these are floats, as are the results of
  # arithmetic on them, so that it can keep them unboxed, in the closest-hit
  # loop too, instead of allocating every intermediate result.
  def hit(%__MODULE__{entries: entries}, {{ox, oy, oz}, {dx, dy, dz}} = ray, t_min, t_max)
      when is_float(ox) and is_float(oy) and is_float(oz) and
             is_float(dx) and is_float(dy) and is_float(dz) and
             is_float(t_min) and is_float(t_max) do
    a = dx * dx + dy * dy + dz * dz

    case closest(entries, ox, oy, oz, dx, dy, dz, a, t_min, t_max, nil) do
      nil -> nil
      {sphere, t} -> Sphere.hit_at(sphere, ray, t)
    end
  end

  defp closest([], _ox, _oy, _oz, _dx, _dy, _dz, _a, _t_min, _t_max, nil), do: nil
  defp closest([], _ox, _oy, _oz, _dx, _dy, _dz, _a, _t_min, t_max, sphere), do: {sphere, t_max}

  defp closest(
         [{cx, cy, cz, radius_squared, s} | rest],
         ox,
         oy,
         oz,
         dx,
         dy,
         dz,
         a,
         t_min,
         t_max,
         found
       )
       when is_float(cx) and is_float(cy) and is_float(cz) and is_float(radius_squared) do
    # oc is the vector from the sphere's centre to the ray's origin.
    ocx = ox - cx
    ocy = oy - cy
    ocz = oz - cz
    b = ocx * dx + ocy * dy + ocz * dz
    c = ocx * ocx + ocy * ocy + ocz * ocz - radius_squared
    discriminant = b * b - a * c

    # Most rays miss most spheres.
    if discriminant < 0.0 do
      closest(rest, ox, oy, oz, dx, dy, dz, a, t_min, t_max, found)
    else
      sqrt_d = :math.sqrt(discriminant)
      near = (-b - sqrt_d) / a

      if near < t_max and near > t_min do
        closest(rest, ox, oy, oz, dx, dy, dz, a, t_min, near, s)
      else
        far = (-b + sqrt_d) / a

        if far < t_max and far > t_min,
          do: closest(rest, ox, oy, oz, dx, dy, dz, a, t_min, far, s),
          else: closest(rest, ox, oy, oz, dx, dy, dz, a, t_min, t_max, found)
      end
    end
  end
end
