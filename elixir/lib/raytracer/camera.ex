defmodule Raytracer.Camera do
  alias Raytracer.{Ray, Vec3}

  @enforce_keys [:origin, :lower_left, :horizontal, :vertical, :u, :v, :lens_radius]
  defstruct @enforce_keys

  @doc """
  A camera at `:look_from` facing `:look_at`. `:vfov` is the vertical field of
  view in degrees.
  """
  def new(opts) do
    look_from = Keyword.fetch!(opts, :look_from)
    focus_dist = Keyword.fetch!(opts, :focus_dist)
    # The same constant as Rust's to_radians.
    theta = Keyword.fetch!(opts, :vfov) * (:math.pi() / 180.0)
    half_height = :math.tan(theta / 2.0)
    half_width = Keyword.fetch!(opts, :aspect) * half_height
    w = Vec3.unit(Vec3.sub(look_from, Keyword.fetch!(opts, :look_at)))
    u = Vec3.unit(Vec3.cross(Keyword.fetch!(opts, :v_up), w))
    v = Vec3.cross(w, u)

    %__MODULE__{
      origin: look_from,
      lower_left:
        look_from
        |> Vec3.sub(Vec3.scale(half_width * focus_dist, u))
        |> Vec3.sub(Vec3.scale(half_height * focus_dist, v))
        |> Vec3.sub(Vec3.scale(focus_dist, w)),
      horizontal: Vec3.scale(2.0 * half_width * focus_dist, u),
      vertical: Vec3.scale(2.0 * half_height * focus_dist, v),
      u: u,
      v: v,
      lens_radius: Keyword.fetch!(opts, :aperture) / 2.0
    }
  end

  @doc """
  A ray through the viewport at normalised coordinates (`s`, `t`), with its
  origin jittered across the lens, and the generator's new state.
  """
  def get_ray(%__MODULE__{} = c, s, t, rng) do
    {disk, rng} = Vec3.random_in_unit_disk(rng)
    {rx, ry, _} = Vec3.scale(c.lens_radius, disk)
    offset = Vec3.add(Vec3.scale(rx, c.u), Vec3.scale(ry, c.v))

    direction =
      c.lower_left
      |> Vec3.add(Vec3.scale(s, c.horizontal))
      |> Vec3.add(Vec3.scale(t, c.vertical))
      |> Vec3.sub(c.origin)
      |> Vec3.sub(offset)

    {Ray.new(Vec3.add(c.origin, offset), direction), rng}
  end
end
